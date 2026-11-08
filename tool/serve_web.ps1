# FIN1: build the web app with a visible build stamp and serve it on the
# local network, so a phone on the same Wi-Fi can open it.
# Run from the repo root:  powershell -ExecutionPolicy Bypass -File tool\serve_web.ps1
# The stamp shows after the version in the sign-in footer and in Settings.

$ErrorActionPreference = 'Stop'

if (-not (Test-Path 'pubspec.yaml')) {
    Write-Error 'Run this from the repo root (the folder with pubspec.yaml).'
}

$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'

flutter build web --release "--dart-define=BUILD_STAMP=$stamp"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# The address a phone on the same Wi-Fi uses (the first IPv4 of the Wi-Fi adapter).
$ip = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi*' -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike '169.254.*' } |
    Select-Object -First 1 -ExpandProperty IPAddress
if (-not $ip) { $ip = '<no Wi-Fi IPv4 found>' }

if (-not (dart pub global list | Select-String -Quiet '^dhttpd ')) {
    Write-Host 'dhttpd is not installed. Run once: dart pub global activate dhttpd'
    exit 1
}

Write-Host ''
Write-Host "Build stamp: $stamp"
Write-Host "Open on the phone: http://${ip}:8080"
Write-Host 'Press Ctrl+C to stop.'
Write-Host ''

dart pub global run dhttpd --host 0.0.0.0 --port 8080 --path build/web
