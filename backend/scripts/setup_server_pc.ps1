param(
    [int]$Port = 8000,
    [string]$BindHost = "0.0.0.0",
    [string]$VenvPath = ".venv",
    [switch]$SkipFirewallRule
)

$ErrorActionPreference = "Stop"

Write-Host "== PHC API: setup on dedicated PC ==" -ForegroundColor Cyan

$backendRoot = Split-Path -Parent $PSScriptRoot
Set-Location $backendRoot

$pythonLauncher = Get-Command py -ErrorAction SilentlyContinue
if (-not $pythonLauncher) {
    throw "Python launcher 'py' not found. Install Python 3.11+ first."
}

$venvPython = Join-Path $VenvPath "Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    Write-Host "Creating virtual environment: $VenvPath" -ForegroundColor Yellow
    & py -m venv $VenvPath
}

Write-Host "Installing dependencies..." -ForegroundColor Yellow
& $venvPython -m pip install --upgrade pip
& $venvPython -m pip install -r "requirements.txt"

if (-not (Test-Path ".env") -and (Test-Path ".env.example")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Created .env from .env.example" -ForegroundColor Green
}

Write-Host "Ensuring admin account..." -ForegroundColor Yellow
& $venvPython "scripts\bootstrap_admin.py"

if (-not $SkipFirewallRule) {
    $ruleName = "PHC API $Port"
    Write-Host "Configuring Windows Firewall rule: $ruleName" -ForegroundColor Yellow
    & netsh advfirewall firewall delete rule name="$ruleName" | Out-Null
    & netsh advfirewall firewall add rule name="$ruleName" dir=in action=allow protocol=TCP localport=$Port | Out-Null
}

$ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } |
    Select-Object -ExpandProperty IPAddress

Write-Host ""
Write-Host "Setup complete." -ForegroundColor Green
if ($ips) {
    Write-Host "Use one of these LAN addresses in mobile app:" -ForegroundColor Cyan
    foreach ($ip in $ips) {
        Write-Host "  http://$ip`:$Port"
    }
}
Write-Host ""
Write-Host "Starting API server..." -ForegroundColor Cyan
& $venvPython -m uvicorn app.main:app --host $BindHost --port $Port
