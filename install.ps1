#!/usr/bin/env pwsh
# jwmv Local Build & Install Script
# Builds jwmv from local source code and installs it on this machine
# 
# Usage: .\install.ps1 [-Configuration <Debug|Release>] [-InstallDir <path>] [-NoPath] [-SkipBuild]
#
# Examples:
#   .\install.ps1                        # Build Release and install to default location
#   .\install.ps1 -Configuration Debug   # Build Debug configuration
#   .\install.ps1 -SkipBuild             # Skip build, just install existing binary
#   .\install.ps1 -InstallDir $HOME\.tools  # Custom installation directory

param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",
    [string]$InstallDir = "",
    [switch]$NoPath,
    [switch]$SkipBuild,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

function Show-Help {
    @'
jwmv Local Build & Install Script
==================================

Builds jwmv from local source code and installs it on this machine.

USAGE:
    .\install.ps1 [-Configuration <Debug|Release>] [-InstallDir <path>] [-NoPath] [-SkipBuild]

PARAMETERS:
    -Configuration   Build configuration (Debug or Release, default: Release)
    -InstallDir      Custom installation directory (default: $HOME\.jwmv\bin)
    -NoPath          Skip adding jwmv to PATH environment variable
    -SkipBuild       Skip build step, just install existing binary from bin folder
    -Help            Show this help message

EXAMPLES:
    .\install.ps1                           # Build Release and install to default location
    .\install.ps1 -Configuration Debug      # Build Debug configuration
    .\install.ps1 -SkipBuild                # Skip build, just install existing binary
    .\install.ps1 -InstallDir $HOME\.tools  # Custom installation directory

REQUIREMENTS:
    - .NET 8 SDK or later
    - PowerShell 5.1 or later

For more information, visit: https://github.com/stescobedo92/jwmv
'@
    exit 0
}

if ($Help) {
    Show-Help
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
Write-Host "jwmv Local Build & Install Script" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Check for .NET SDK
if (-not (Test-CommandExists "dotnet")) {
    Write-Error ".NET SDK is required but not found. Please install .NET 8 SDK from: https://dotnet.microsoft.com/download"
    exit 1
}

$dotnetVersion = dotnet --version
Write-Host ".NET SDK version: $dotnetVersion" -ForegroundColor Green

# Determine architecture
$arch = Get-Architecture
Write-Host "Architecture: $arch" -ForegroundColor Green
Write-Host ""

# Build
if (-not $SkipBuild) {
    Write-Host "Building jwmv from local source ($Configuration)..." -ForegroundColor Yellow
    
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $projectPath = Join-Path $scriptDir "src\Jwmv.Cli\Jwmv.Cli.csproj"
    
    if (-not (Test-Path $projectPath)) {
        Write-Error "Project file not found: $projectPath"
        exit 1
    }
    
    try {
        # Build and publish as single-file executable
        $publishDir = Join-Path $scriptDir "publish"
        Write-Host "Publishing to: $publishDir" -ForegroundColor Gray
        dotnet publish $projectPath -c $Configuration --no-restore
        
        if ($LASTEXITCODE -ne 0) {
            throw "Build failed with exit code $LASTEXITCODE"
        }
        
        Write-Host "Build completed successfully." -ForegroundColor Green
        
        # Update binary path to published location
        $binaryPath = Join-Path $publishDir "jwmv.exe"
    } catch {
        Write-Error "Failed to build jwmv: $_"
        exit 1
    }
} else {
    Write-Host "Skipping build step (-SkipBuild specified)." -ForegroundColor Yellow
}

# Find the built binary (already set during build step)
# If SkipBuild was used, determine the path
if ($SkipBuild) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $publishDir = Join-Path $scriptDir "publish"
    $binaryPath = Join-Path $publishDir "jwmv.exe"
    
    if (-not (Test-Path $binaryPath)) {
        Write-Error "Built binary not found at: $binaryPath"
        Write-Host "Please run without -SkipBuild flag first to build the project." -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "Binary found: $binaryPath" -ForegroundColor Green
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

$exePath = Join-Path $InstallDir "jwmv.exe"

# Check if already installed
if (Test-Path $exePath) {
    Write-Host "jwmv is already installed at: $exePath" -ForegroundColor Yellow
    $overwrite = Read-Host "Do you want to replace with the newly built version? (y/n)"
    if ($overwrite -ne 'y') {
        Write-Host "Installation cancelled." -ForegroundColor Red
        exit 0
    }
    Write-Host "Replacing..." -ForegroundColor Yellow
}

# Copy binary
Write-Host "Copying binary to installation directory..." -ForegroundColor Yellow
try {
    Copy-Item -Path $binaryPath -Destination $exePath -Force
    Write-Host "Copy complete." -ForegroundColor Green
} catch {
    Write-Error "Failed to copy jwmv: $_"
    exit 1
}

# Verify installation
if (-not (Test-Path $exePath)) {
    Write-Error "Installation failed: jwmv.exe not found at $exePath"
    exit 1
}

Write-Host ""
Write-Host "jwmv installed successfully!" -ForegroundColor Green
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
Write-Host "  jwmv list                    # List supported SDK candidates" -ForegroundColor White
Write-Host "  jwmv list java               # List available Java versions" -ForegroundColor White
Write-Host "  jwmv install 21-tem          # Install Java 21 (Temurin)" -ForegroundColor White
Write-Host "  jwmv use 21-tem              # Switch to Java 21" -ForegroundColor White
Write-Host "  java -version                # Verify installation" -ForegroundColor White
Write-Host ""
Write-Host "For more information, visit: https://github.com/stescobedo92/jwmv" -ForegroundColor Cyan
