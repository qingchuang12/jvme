# JWMV Installer Script
# Simple, ASCII-only, no complex parameters

$ErrorActionPreference = "Stop"
$InstallDir = "$env:LOCALAPPDATA\jwmv"
$PublishDir = "$PSScriptRoot\publish"

Write-Host "=== JWMV Installer ===" -ForegroundColor Cyan

# 1. Check .NET
Write-Host "[1/4] Checking .NET SDK..." -NoNewline
try {
    $ver = dotnet --version
    if ($ver -notlike "8.*") { throw "Need .NET 8" }
    Write-Host "OK ($ver)" -ForegroundColor Green
} catch {
    Write-Host "FAIL. Install .NET 8 SDK first." -ForegroundColor Red
    exit 1
}

# 2. Publish
Write-Host "[2/4] Building..." -NoNewline
dotnet publish src/Jwmv.Cli/Jwmv.Cli.csproj -c Release -r win-x64 --self-contained false -o $PublishDir --nologo -q
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL" -ForegroundColor Red
    exit 1
}
Write-Host "OK" -ForegroundColor Green

# 3. Copy Files
Write-Host "[3/4] Installing to $InstallDir..." -NoNewline
if (!(Test-Path $InstallDir)) { New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null }
Copy-Item -Path "$PublishDir\*" -Destination $InstallDir -Force
Write-Host "OK" -ForegroundColor Green

# 4. Update PATH
Write-Host "[4/4] Updating PATH..." -NoNewline
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$InstallDir", "User")
    Write-Host "Updated" -ForegroundColor Green
    Write-Host "`nNOTE: Close this window and open a NEW PowerShell to use 'jwmv'." -ForegroundColor Yellow
} else {
    Write-Host "Exists" -ForegroundColor Green
}

Write-Host "`nDone!" -ForegroundColor Green
