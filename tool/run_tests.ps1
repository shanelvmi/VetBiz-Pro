<#
.SYNOPSIS
  Runs the Flutter tests the way the gates should be run (STAB1).

.DESCRIPTION
  - Refuses to start while another `flutter test` or `flutter analyze` runs
    (two at once crash the Dart VM and report false failures).
  - A fixed concurrency, so runs are comparable.
  - A clear summary at the end: passed, skipped, failed, the time, and each
    failing test by file.
  - -Changed runs only the test files changed since the last commit.
  - -Record records ONE test file's fixtures with its record define (two
    files recording at once could lose an entry).
  - Prints the free memory at start; refuses a concurrency above the cores
    when under 6 GB are free.
  - Stops every flutter process it started (tool/run_tests_cleanup.ps1) on a
    normal end, an error or Ctrl+C, and, through a hidden watcher, when this
    script itself is killed: no orphan flutter_tester or dart processes.

.EXAMPLE
  powershell -File tool/run_tests.ps1
  powershell -File tool/run_tests.ps1 -Changed
  powershell -File tool/run_tests.ps1 -Record test/hub1_wide_unchanged_test.dart -Define PH5A_RECORD
#>
param(
  [switch]$Changed,
  [string]$Record,
  [string]$Define,
  [int]$Concurrency = [Environment]::ProcessorCount
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# 1. Never two flutter commands at once.
$lockDir = Join-Path $root 'build'
if (-not (Test-Path $lockDir)) { New-Item -ItemType Directory -Force $lockDir | Out-Null }
$lockPath = Join-Path $lockDir 'run_tests.lock'
$others = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
  $_.ProcessId -ne $PID -and $_.CommandLine -and
  $_.CommandLine -match 'flutter_tools' -and $_.CommandLine -match '\s(test|analyze)(\s|$)'
}
if ($others -or (Test-Path $lockPath)) {
  # One line, naming what is running (a run left hung for days shows its date:
  # stop it with Stop-Process -Id <pid> if it is not yours).
  $what = @($others | ForEach-Object { "pid $($_.ProcessId) since $($_.CreationDate.ToString('yyyy-MM-dd HH:mm'))" })
  if (Test-Path $lockPath) { $what += 'build/run_tests.lock' }
  Write-Host "run_tests: another flutter test or flutter analyze is running ($($what -join '; ')); wait for it to finish, then run again."
  exit 2
}

# Free memory first: a run at more processes than cores on a short-memory
# machine is what the memory guard stopped (and orphaned) once.
$cores = [Environment]::ProcessorCount
$freeGb = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB, 1)
Write-Host "run_tests: $freeGb GB free memory, $cores cores, concurrency $Concurrency."
if ($Concurrency -gt $cores -and $freeGb -lt 6) {
  Write-Host "run_tests: only $freeGb GB free (under 6 GB): refusing a concurrency above $cores cores; run with -Concurrency $cores or free some memory."
  exit 2
}

$knownDefines = 'PH5A_RECORD', 'PH6_RECORD', 'PH7A_RECORD', 'PH7B_RECORD', 'PH8A_RECORD', 'PH8B_RECORD', 'WRITE_SHAPES'
$flutterArgs = @('test', "--concurrency=$Concurrency")

if ($Record) {
  # 2. Recording: one file, one define.
  if ($Record -match '\s|,') { Write-Host 'run_tests: -Record takes ONE test file; record files one at a time.'; exit 2 }
  if (-not (Test-Path $Record)) { Write-Host "run_tests: no such test file: $Record"; exit 2 }
  if ($knownDefines -notcontains $Define) { Write-Host "run_tests: -Define must be one of: $($knownDefines -join ', ')"; exit 2 }
  $flutterArgs += @($Record, "--dart-define=$Define=true")
} elseif ($Changed) {
  # 3. Only the test files changed since the last commit (tracked or new).
  $files = @(git diff --name-only HEAD -- test) + @(git ls-files --others --exclude-standard -- test) |
    Where-Object { $_ -like '*_test.dart' -and (Test-Path $_) } | Sort-Object -Unique
  if (-not $files) { Write-Host 'run_tests: no changed test files.'; exit 0 }
  Write-Host "run_tests: $($files.Count) changed test file(s)."
  $flutterArgs += $files
}

$report = Join-Path $lockDir 'run_tests_report.json'
$start = Get-Date
# The lock records this run: its pid, its start and every process already
# running, so the cleanup stops only what this run started.
@{
  pid = $PID
  start = $start.ToString('o')
  before = @(Get-CimInstance Win32_Process | ForEach-Object { $_.ProcessId })
} | ConvertTo-Json -Compress | Set-Content -Path $lockPath
$cleanup = Join-Path $PSScriptRoot 'run_tests_cleanup.ps1'
# If this script is killed (no finally runs), a hidden watcher stops what
# it started once it is gone.
Start-Process powershell -WindowStyle Hidden -ArgumentList @(
  '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$cleanup`"", '-Lock', "`"$lockPath`"", '-WaitFor', $PID
) | Out-Null
try {
  & flutter @flutterArgs --file-reporter "json:$report" | Out-Host
  $code = $LASTEXITCODE
} finally {
  # A normal end, an error or Ctrl+C: stop anything left, remove the lock.
  & $cleanup -Lock $lockPath
}
$secs = [int]((Get-Date) - $start).TotalSeconds

# 4. The summary, from the JSON report.
$names = @{}; $suites = @{}; $testSuite = @{}
$passed = 0; $skipped = 0; $failed = @()
foreach ($line in Get-Content $report) {
  if (-not $line.Trim()) { continue }
  $e = $line | ConvertFrom-Json
  switch ($e.type) {
    'suite' { $suites[$e.suite.id] = ($e.suite.path -replace '.*[\\/]test[\\/]', '') }
    'testStart' { $names[$e.test.id] = $e.test.name; $testSuite[$e.test.id] = $e.test.suiteID }
    'testDone' {
      if ($e.hidden) { break }
      if ($e.skipped) { $skipped++ }
      elseif ($e.result -eq 'success') { $passed++ }
      else { $failed += "$($suites[$testSuite[$e.testID]]): $($names[$e.testID])" }
    }
  }
}
Write-Host ''
Write-Host "run_tests: $passed passed, $skipped skipped, $($failed.Count) failed in $secs s (concurrency $Concurrency)."
foreach ($f in $failed) { Write-Host "  FAILED $f" }
exit $code
