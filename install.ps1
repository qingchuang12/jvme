# JWMV 本地安装脚本 (PowerShell)
# 用法: .\install.ps1
# 卸载: .\install.ps1 -Uninstall

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
        "ERROR" { "Red" }
        "WARN"  { "Yellow" }
        "SUCCESS" { "Green" }
        default { "Cyan" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-Prerequisites {
    Write-Log "检查前置条件..."
    
    # 检查 dotnet 命令
    try {
        $dotnetVersion = dotnet --version 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "dotnet 命令不可用"
        }
        
        if ($dotnetVersion -notmatch "^8\.") {
            Write-Log "警告：检测到 .NET 版本 $dotnetVersion，推荐 .NET 8.x" -Level WARN
        } else {
            Write-Log ".NET SDK 版本: $dotnetVersion" -Level SUCCESS
        }
    } catch {
        Write-Log "错误：未找到 .NET 8 SDK" -Level ERROR
        Write-Log "请从 https://dotnet.microsoft.com/download 安装 .NET 8 SDK" -Level ERROR
        exit 1
    }
    
    # 检查源码目录
    if (!(Test-Path "$PSScriptRoot\src\Jwmv.Cli")) {
        Write-Log "错误：未找到源码目录，请在项目根目录运行此脚本" -Level ERROR
        exit 1
    }
}

function Publish-Jwmv {
    Write-Log "正在编译发布 JWMV..."
    
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
        Write-Log "编译失败！" -Level ERROR
        exit 1
    }
    
    if (!(Test-Path "$PublishDir\$ExeName")) {
        Write-Log "编译成功但未找到可执行文件" -Level ERROR
        exit 1
    }
    
    Write-Log "编译完成" -Level SUCCESS
}

function Install-Jwmv {
    Write-Log "正在安装到 $InstallDir ..."
    
    # 创建安装目录
    if (!(Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    }
    
    # 复制文件
    Copy-Item -Path "$PublishDir\*" -Destination $InstallDir -Force
    
    Write-Log "文件已复制到 $InstallDir" -Level SUCCESS
}

function Add-ToPath {
    Write-Log "配置环境变量..."
    
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    
    # 检查是否已存在
    $paths = $userPath -split ';' | Where-Object { $_ -and $_.Trim() }
    $exists = $paths -contains $InstallDir
    
    if (!$exists) {
        $newPath = "$userPath;$InstallDir"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Log "已添加到用户 PATH" -Level SUCCESS
        Write-Log "注意：当前终端窗口无法立即识别 'jwmv' 命令" -Level WARN
        Write-Log "请关闭并重新打开一个新的 PowerShell 窗口" -Level WARN
    } else {
        Write-Log "PATH 中已存在该路径" -Level INFO
    }
}

function Remove-FromPath {
    Write-Log "从环境变量中移除..."
    
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $paths = $userPath -split ';' | Where-Object { 
        $_ -and $_.Trim() -and $_ -ne $InstallDir -and $_ -ne "$InstallDir\" 
    }
    $newPath = $paths -join ';'
    
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Log "已从用户 PATH 移除" -Level SUCCESS
}

function Uninstall-Jwmv {
    Write-Log "开始卸载 JWMV..." -Level WARN
    
    # 从 PATH 移除
    if ([Environment]::GetEnvironmentVariable("Path", "User") -like "*$InstallDir*") {
        Remove-FromPath
    }
    
    # 删除安装目录
    if (Test-Path $InstallDir) {
        Remove-Item -Path $InstallDir -Recurse -Force
        Write-Log "已删除安装目录" -Level SUCCESS
    }
    
    Write-Log "卸载完成" -Level SUCCESS
}

function Verify-Installation {
    Write-Log "验证安装..."
    
    # 注意：当前进程无法读取刚修改的 PATH，需要提示用户重启终端
    Write-Log "安装位置：$InstallDir" -Level INFO
    Write-Log "可执行文件：$InstallDir\$ExeName" -Level INFO
    
    if (Test-Path "$InstallDir\$ExeName") {
        Write-Log "✓ 可执行文件存在" -Level SUCCESS
    } else {
        Write-Log "✗ 可执行文件不存在" -Level ERROR
        exit 1
    }
    
    Write-Log ""
    Write-Log "========================================" -Level INFO
    Write-Log "安装成功！" -Level SUCCESS
    Write-Log "========================================" -Level INFO
    Write-Log ""
    Write-Log "下一步操作：" -Level INFO
    Write-Log "1. 关闭当前 PowerShell 窗口" -Level INFO
    Write-Log "2. 重新打开一个新的 PowerShell 窗口" -Level INFO
    Write-Log "3. 运行以下命令验证：" -Level INFO
    Write-Log "   jwmv --version" -Level INFO
    Write-Log "   jwmv doctor" -Level INFO
    Write-Log "   jwmv list java" -Level INFO
    Write-Log ""
}

# 主逻辑
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
    Write-Log "安装过程中发生错误：$_" -Level ERROR
    exit 1
}
