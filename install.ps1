#!/usr/bin/env pwsh
# jwmv Local Install Script
# Installs jwmv (Java Version Manager for Windows) on this machine
# 
# Usage: .\install.ps1 [-Version <version>] [-InstallDir <path>] [-NoPath]
#
# Examples:
#   .\install.ps1                           # Install latest version to default location
#   .\install.ps1 -Version 1.0.0            # Install specific version
#   .\install.ps1 -InstallDir $HOME\.tools  # Custom installation directory

param(
    [string]$Version = "",
    [string]$InstallDir = "",
    [switch]$NoPath,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

function Show-Help {
    @'
jwmv Local Install Script
=========================

Installs jwmv (Java Version Manager for Windows) on this machine.

USAGE:
    .\install.ps1 [-Version <version>] [-InstallDir <path>] [-NoPath]

PARAMETERS:
    -Version     Specific version to install (default: latest from GitHub)
    -InstallDir  Custom installation directory (default: $HOME\.jwmv\bin)
    -NoPath      Skip adding jwmv to PATH environment variable
    -Help        Show this help message

EXAMPLES:
    .\install.ps1                           # Install latest version to default location
    .\install.ps1 -Version 1.0.0            # Install specific version
    .\install.ps1 -InstallDir $HOME\.tools  # Custom installation directory

INSTALLATION METHODS:
    This script downloads the pre-built binary from GitHub Releases.
    Alternative installation methods:
    
    1. winget (recommended):
       winget install stescobedo92.jwmv
    
    2. npm:
       npm install -g @stescobedo9205/jwmv
    
    3. .NET global tool:
       dotnet tool install -g jwmv

For more information, visit: https://github.com/stescobedo92/jwmv
'@
    exit 0
}

if ($Help) {
    Show-Help
}

function Get-LatestVersion {
    $releasesUrl = "https://api.github.com/repos/stescobedo92/jwmv/releases/latest"
    try {
        $response = Invoke-RestMethod -Uri $releasesUrl -Headers @{ "User-Agent" = "jwmv-installer" }
        return $response.tag_name.TrimStart('v')
    } catch {
        Write-Warning "Failed to fetch latest version from GitHub API. Using fallback version."
        return "1.0.0"
    }
}

function Get-Architecture {
    $arch = (Get-CimInstance Win32_Processor).AddressWidth
    if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") {
        return "win-arm64"
    } elseif ($arch -eq 64) {
        return "win-x64"
    } else {
        throw "Unsupported architecture: $arch"
    }
}

function Test-CommandExists($command) {
    $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
}

# Main installation logic
Write-Host "jwmv Local Install Script" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host ""

# Determine version
if ([string]::IsNullOrEmpty($Version)) {
    $Version = Get-LatestVersion
    Write-Host "Latest version: v$Version" -ForegroundColor Green
} else {
    Write-Host "Installing version: v$Version" -ForegroundColor Green
}

# Determine architecture and asset name
$arch = Get-Architecture
$assetName = "jwmv-$arch.zip"
Write-Host "Architecture: $arch" -ForegroundColor Green
Write-Host "Asset: $assetName" -ForegroundColor Green
Write-Host ""

# Determine installation directory
if ([string]::IsNullOrEmpty($InstallDir)) {
    $InstallDir = Join-Path $env:USERPROFILE ".jwmv\bin"
} else {
    $InstallDir = [System.IO.Path]::GetFullPath($InstallDir)
}

Write-Host "Installation directory: $InstallDir" -ForegroundColor Green
Write-Host ""

# Create installation directory
Write-Host "Creating installation directory..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# Download URL
$downloadUrl = "https://github.com/stescobedo92/jwmv/releases/download/v$Version/$assetName"
$zipPath = Join-Path $InstallDir $assetName
$exePath = Join-Path $InstallDir "jwmv.exe"

# Check if already installed
if (Test-Path $exePath) {
    Write-Host "jwmv is already installed at: $exePath" -ForegroundColor Yellow
    $overwrite = Read-Host "Do you want to reinstall? (y/n)"
    if ($overwrite -ne 'y') {
        Write-Host "Installation cancelled." -ForegroundColor Red
        exit 0
    }
    Write-Host "Reinstalling..." -ForegroundColor Yellow
}

# Download
Write-Host "Downloading jwmv v$Version from GitHub..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
    Write-Host "Download complete." -ForegroundColor Green
} catch {
    Write-Error "Failed to download jwmv: $_"
    Write-Host ""
    Write-Host "Manual download available at: https://github.com/stescobedo92/jwmv/releases" -ForegroundColor Cyan
    exit 1
}

# Extract
Write-Host "Extracting..." -ForegroundColor Yellow
try {
    Expand-Archive -Path $zipPath -DestinationPath $InstallDir -Force
    Remove-Item -Path $zipPath -Force
    Write-Host "Extraction complete." -ForegroundColor Green
} catch {
    Write-Error "Failed to extract jwmv: $_"
    exit 1
}

# Verify installation
if (-not (Test-Path $exePath)) {
    Write-Error "Installation failed: jwmv.exe not found at $exePath"
    exit 1
}

Write-Host ""
Write-Host "jwmv v$Version installed successfully!" -ForegroundColor Green
Write-Host "Binary location: $exePath" -ForegroundColor Cyan
Write-Host ""

# Add to PATH
if (-not $NoPath) {
    Write-Host "Adding jwmv to user PATH..." -ForegroundColor Yellow
    
    try {
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
        
        if (-not $currentPath.Contains($InstallDir)) {
            $newPath = "$InstallDir;$currentPath"
            [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
            
            # Refresh current session PATH
            $env:Path = "$InstallDir;$env:Path"
            
            Write-Host "PATH updated successfully." -ForegroundColor Green
            Write-Host ""
            Write-Host "You can now run 'jwmv --help' to get started." -ForegroundColor Cyan
        } else {
            Write-Host "jwmv is already in PATH." -ForegroundColor Green
        }
    } catch {
        Write-Warning "Failed to update PATH automatically. Please add '$InstallDir' to your PATH manually."
    }
} else {
    Write-Host "Skipping PATH update (NoPath specified)." -ForegroundColor Yellow
    Write-Host "Please add '$InstallDir' to your PATH manually." -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Quick Start:" -ForegroundColor Cyan
Write-Host "  jwmv candidates              # List supported SDK candidates" -ForegroundColor White
Write-Host "  jwmv install 21-tem          # Install Java 21 (Temurin)" -ForegroundColor White
Write-Host "  jwmv use 21-tem              # Switch to Java 21" -ForegroundColor White
Write-Host "  java -version                # Verify installation" -ForegroundColor White
Write-Host ""
Write-Host "For more information, visit: https://github.com/stescobedo92/jwmv" -ForegroundColor Cyan
