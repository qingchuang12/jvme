# JWMV Windows 安装脚本
# 用法: .\install.ps1 [-Uninstall]

[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$Force
)

$InstallDir = "$env:LOCALAPPDATA\jwmv"
$ExeName = "jwmv.exe"
$PublishDir = "$PSScriptRoot\publish"

function Write-Status {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-Prerequisites {
    Write-Status "检查前置条件..." "Cyan"
    
    # 检查 dotnet 命令
    $dotnetPath = Get-Command dotnet -ErrorAction SilentlyContinue
    if (-not $dotnetPath) {
        Write-Status "错误: 未找到 'dotnet' 命令。" "Red"
        Write-Status "请先安装 .NET 8 SDK: https://dotnet.microsoft.com/download" "Yellow"
        return $false
    }

    # 检查 .NET 版本
    $versionOutput = dotnet --version
    if ($versionOutput -notmatch "^8\.") {
        Write-Status "警告: 检测到 .NET 版本 $versionOutput，建议安装 .NET 8 SDK。" "Yellow"
        if (-not $Force) {
            $continue = Read-Host "是否继续安装？(y/n)"
            if ($continue -ne 'y') { return $false }
        }
    } else {
        Write-Status "检测到 .NET 8 ($versionOutput)，符合要求。" "Green"
    }

    return $true
}

function Publish-App {
    Write-Status "正在编译发布 JWMV..." "Cyan"
    
    if (Test-Path $PublishDir) {
        Remove-Item -Recurse -Force $PublishDir
    }

    $args = @(
        "publish",
        "src/Jwmv.Cli/Jwmv.Cli.csproj",
        "-c", "Release",
        "-r", "win-x64",
        "--self-contained", "false",
        "-o", $PublishDir,
        "--nologo"
    )

    & dotnet $args

    if ($LASTEXITCODE -ne 0) {
        Write-Status "编译失败！请检查错误信息。" "Red"
        return $false
    }

    if (-not (Test-Path "$PublishDir\$ExeName")) {
        Write-Status "编译成功但未找到 $ExeName，发布可能不完整。" "Red"
        return $false
    }

    Write-Status "编译成功。" "Green"
    return $true
}

function Install-App {
    Write-Status "正在安装到 $InstallDir ..." "Cyan"

    try {
        if (Test-Path $InstallDir) {
            Write-Status "发现旧版本，正在清理..." "Gray"
            Remove-Item -Recurse -Force $InstallDir
        }
        New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
        
        Copy-Item -Path "$PublishDir\*" -Destination $InstallDir -Force
        
        Write-Status "文件复制完成。" "Green"
        return $true
    } catch {
        Write-Status "安装文件时出错: $_" "Red"
        return $false
    }
}

function Update-Path {
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    
    # 移除旧的 jwmv 路径（如果有）
    $paths = $currentPath -split ';' | Where-Object { 
        $_ -and $_ -ne $InstallDir -and $_ -ne "$InstallDir\" 
    }
    
    # 添加新路径
    $newPath = ($paths + $InstallDir) -join ';'
    
    try {
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Status "已更新用户 PATH 环境变量。" "Green"
        return $true
    } catch {
        Write-Status "更新 PATH 失败: $_" "Red"
        return $false
    }
}

function Uninstall-App {
    Write-Status "正在卸载 JWMV..." "Cyan"

    # 从 PATH 中移除
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $paths = $currentPath -split ';' | Where-Object { 
        $_ -and $_ -ne $InstallDir -and $_ -ne "$InstallDir\" 
    }
    $newPath = ($paths -join ';')
    
    try {
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Status "已从 PATH 中移除。" "Green"
    } catch {
        Write-Status "更新 PATH 失败: $_" "Yellow"
    }

    # 删除文件夹
    if (Test-Path $InstallDir) {
        try {
            Remove-Item -Recurse -Force $InstallDir
            Write-Status "已删除安装目录: $InstallDir" "Green"
        } catch {
            Write-Status "删除目录失败，请手动删除: $InstallDir" "Yellow"
            Write-Status "错误: $_" "Gray"
        }
    } else {
        Write-Status "安装目录不存在。" "Gray"
    }

    Write-Status "卸载完成。请重启终端。" "Cyan"
}

function Verify-Installation {
    Write-Status "`n验证安装..." "Cyan"
    
    # 注意：当前进程无法立即读取新的 PATH，需要提示用户重启终端
    if (Test-Path "$InstallDir\$ExeName") {
        Write-Status "✅ 可执行文件已存在: $InstallDir\$ExeName" "Green"
        Write-Status "`n⚠️  重要提示：" "Yellow"
        Write-Status "   由于环境变量已更新，请【关闭并重新打开】PowerShell 窗口。" "Yellow"
        Write-Status "   在新窗口中运行 'jwmv --version' 验证安装。" "Yellow"
        return $true
    } else {
        Write-Status "❌ 验证失败：未找到可执行文件。" "Red"
        return $false
    }
}

# ================= 主逻辑 =================

if ($Uninstall) {
    Uninstall-App
    exit
}

Write-Status "========================================" "DarkGray"
Write-Status "   JWMV (Java Version Manager) 安装程序" "DarkGray"
Write-Status "========================================" "DarkGray"

if (-not (Test-Prerequisites)) {
    exit 1
}

if (-not (Publish-App)) {
    exit 1
}

if (-not (Install-App)) {
    exit 1
}

if (-not (Update-Path)) {
    exit 1
}

Verify-Installation
