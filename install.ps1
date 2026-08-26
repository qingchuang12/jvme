# JWMV Local Install Script (PowerShell)
# Usage: .\install.ps1
# Uninstall: .\install.ps1 -Uninstall

[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$InstallDir = "$env:LOCALAPPDATA\jwmv"
$ExeName = "jwmv.exe"
$PublishDir = "$PSScriptRoot\publish"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "ERROR"   { "Red" }
        "WARN"    { "Yellow" }
        "SUCCESS" { "Green" }
        default   { "Cyan" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-Prerequisites {
    Write-Log "Checking prerequisites..."
    
    # Check dotnet command
    try {
        $dotnetVersion = dotnet --version 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "dotnet command not available"
        }
        
        if ($dotnetVersion -notmatch "^8\.") {
            Write-Log "Warning: Detected .NET version $dotnetVersion, recommended .NET 8.x" -Level WARN
        } else {
            Write-Log ".NET SDK version: $dotnetVersion" -Level SUCCESS
        }
    } catch {
        Write-Log "Error: .NET 8 SDK not found" -Level ERROR
        Write-Log "Please install .NET 8 SDK from https://dotnet.microsoft.com/download" -Level ERROR
        exit 1
    }
    
    # Check source directory
    if (!(Test-Path "$PSScriptRoot\src\Jwmv.Cli")) {
        Write-Log "Error: Source directory not found. Run this script from project root" -Level ERROR
        exit 1
    }
}

function Publish-Jwmv {
    Write-Log "Building and publishing JWMV..."
    
    $publishArgs = @(
        "publish",
        "src/Jwmv.Cli/Jwmv.Cli.csproj",
        "-c", "Release",
        "-r", "win-x64",
        "--self-contained", "false",
        "-o", $PublishDir,
        "--nologo"
    )
    
    & dotnet $publishArgs
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Build failed!" -Level ERROR
        exit 1
    }
    
    if (!(Test-Path "$PublishDir\$ExeName")) {
        Write-Log "Build succeeded but executable not found" -Level ERROR
        exit 1
    }
    
    Write-Log "Build completed" -Level SUCCESS
}

function Install-Jwmv {
    Write-Log "Installing to $InstallDir ..."
    
    # Create installation directory
    if (!(Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    }
    
    # Copy files
    Copy-Item -Path "$PublishDir\*" -Destination $InstallDir -Force
    
    Write-Log "Files copied to $InstallDir" -Level SUCCESS
}

function Add-ToPath {
    Write-Log "Configuring environment variables..."
    
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    
    # Check if already exists
    $paths = $userPath -split ';' | Where-Object { $_ -and $_.Trim() }
    $exists = $paths -contains $InstallDir
    
    if (!$exists) {
        $newPath = "$userPath;$InstallDir"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Log "Added to user PATH" -Level SUCCESS
        Write-Log "Note: Current terminal window cannot recognize 'jwmv' command immediately" -Level WARN
        Write-Log "Please close and reopen a new PowerShell window" -Level WARN
    } else {
        Write-Log "Path already exists in PATH" -Level INFO
    }
}

function Remove-FromPath {
    Write-Log "Removing from environment variables..."
    
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $paths = $userPath -split ';' | Where-Object { 
        $_ -and $_.Trim() -and $_ -ne $InstallDir -and $_ -ne "$InstallDir\" 
    }
    $newPath = $paths -join ';'
    
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Log "Removed from user PATH" -Level SUCCESS
}

function Uninstall-Jwmv {
    Write-Log "Starting JWMV uninstallation..." -Level WARN
    
    # Remove from PATH
    if ([Environment]::GetEnvironmentVariable("Path", "User") -like "*$InstallDir*") {
        Remove-FromPath
    }
    
    # Delete installation directory
    if (Test-Path $InstallDir) {
        Remove-Item -Path $InstallDir -Recurse -Force
        Write-Log "Installation directory deleted" -Level SUCCESS
    }
    
    Write-Log "Uninstallation completed" -Level SUCCESS
}

function Verify-Installation {
    Write-Log "Verifying installation..."
    
    Write-Log "Installation location: $InstallDir" -Level INFO
    Write-Log "Executable: $InstallDir\$ExeName" -Level INFO
    
    if (Test-Path "$InstallDir\$ExeName") {
        Write-Log "[OK] Executable exists" -Level SUCCESS
    } else {
        Write-Log "[FAIL] Executable not found" -Level ERROR
        exit 1
    }
    
    Write-Log ""
    Write-Log "========================================"
    Write-Log "Installation Successful!" -Level SUCCESS
    Write-Log "========================================"
    Write-Log ""
    Write-Log "Next steps:" -Level INFO
    Write-Log "1. Close current PowerShell window" -Level INFO
    Write-Log "2. Open a new PowerShell window" -Level INFO
    Write-Log "3. Run these commands to verify:" -Level INFO
    Write-Log "   jwmv --version" -Level INFO
    Write-Log "   jwmv doctor" -Level INFO
    Write-Log "   jwmv list java" -Level INFO
    Write-Log ""
}

# Main logic
try {
    if ($Uninstall) {
        Uninstall-Jwmv
        exit 0
    }
    
    Test-Prerequisites
    Publish-Jwmv
    Install-Jwmv
    Add-ToPath
    Verify-Installation
    
} catch {
    Write-Log "Error during installation: $_" -Level ERROR
    exit 1
}
