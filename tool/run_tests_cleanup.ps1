<#
.SYNOPSIS
  Stops every flutter process a tool/run_tests.ps1 run started (STAB1).

.DESCRIPTION
  run_tests.ps1 writes build/run_tests.lock when it starts: its own process
  id, the start time and the ids of every process already running. This
  stops the processes started since then whose names are flutter's (dart,
  dartvm, dartaotruntime, flutter_tester and the cmd that runs flutter.bat),
  writes them to build/run_tests_tree.txt, and removes the lock.

  run_tests.ps1 calls it in its finally block (a normal end, an error or
  Ctrl+C). A hidden watcher it starts calls it with -WaitFor <pid> when
  run_tests.ps1 itself is killed (as the memory guard once did, leaving the
  test processes running for days).
#>
param(
  [Parameter(Mandatory)] [string]$Lock,
  [int]$WaitFor = 0
)

if ($WaitFor -gt 0) {
  try { Wait-Process -Id $WaitFor -ErrorAction Stop } catch { }
}
if (-not (Test-Path $Lock)) { exit 0 }

$info = Get-Content $Lock -Raw | ConvertFrom-Json
$since = [datetime]::Parse($info.start)
$before = @{}
foreach ($id in $info.before) { $before[[int]$id] = $true }
$names = 'dart.exe', 'dartvm.exe', 'dartaotruntime.exe', 'flutter_tester.exe', 'cmd.exe'

$left = @(Get-CimInstance Win32_Process | Where-Object {
  $names -contains $_.Name -and
  -not $before.ContainsKey([int]$_.ProcessId) -and
  $_.CreationDate -ge $since -and
  $_.CommandLine -match 'flutter|dart'
})
$tree = Join-Path (Split-Path -Parent $Lock) 'run_tests_tree.txt'
$lines = @("run started $($info.start) by pid $($info.pid); stopped at $(Get-Date -Format s): $($left.Count) process(es)")
$lines += $left | ForEach-Object { "  $($_.ProcessId) $($_.Name) (parent $($_.ParentProcessId))" }
Set-Content -Path $tree -Value $lines
foreach ($p in $left) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
Remove-Item $Lock -ErrorAction SilentlyContinue
if ($left.Count -gt 0) { Write-Host "run_tests: stopped $($left.Count) leftover flutter process(es) (build/run_tests_tree.txt)." }
