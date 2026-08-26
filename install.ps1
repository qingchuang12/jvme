# JWMV 本地安装脚本 (PowerShell)
# 用于在 Windows 上编译并安装 JWMV 工具

param(
    [switch]$Uninstall,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$PublishDir = "$PSScriptRoot\publish"
$InstallDir = "$env:LOCALAPPDATA\jwmv"
$ExeName = "jwmv.exe"
$LogPrefix = "[JWMV Installer]"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "INFO" { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    }
    Write-Host "$timestamp $LogPrefix [$Level] $Message" -ForegroundColor $color
}

function Test-Prerequisites {
    Write-Log "检查前置条件..."
    
    # 检查 .NET SDK
    try {
        $dotnetVersion = dotnet --version 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "dotnet 命令不可用"
        }
        
        # 检查是否为 .NET 8
        if ($dotnetVersion -notmatch "^8\.") {
            Write-Log "警告：检测到 .NET 版本 $dotnetVersion，推荐 .NET 8.x" "WARNING"
        } else {
            Write-Log "检测到 .NET SDK 版本：$dotnetVersion" "SUCCESS"
        }
    } catch {
        Write-Log "未找到 .NET SDK，请先安装 .NET 8 SDK" "ERROR"
        Write-Log "下载地址：https://dotnet.microsoft.com/download/dotnet/8.0" "WARNING"
        exit 1
    }
    
    # 检查源码目录
    if (!(Test-Path "$PSScriptRoot\src\Jwmv.Cli")) {
        Write-Log "未找到源码目录，请确保在 JWMV 项目根目录运行此脚本" "ERROR"
        exit 1
    }
}

function Install-Jwmv {
    Write-Log "开始安装 JWMV..."
    
    # 1. 发布项目
    Write-Log "正在编译发布 JWMV..." 
    dotnet publish `
        src/Jwmv.Cli/Jwmv.Cli.csproj `
        -c Release `
        -r win-x64 `
        --self-contained false `
        -o $PublishDir `
        --nologo `
        $(if ($Verbose) { "-v:d" } else { "-v:q" })
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log "编译失败！请检查上述错误信息。" "ERROR"
        exit 1
    }
    
    if (!(Test-Path "$PublishDir\$ExeName")) {
        Write-Log "编译成功但未找到 $ExeName，发布目录可能有问题" "ERROR"
        exit 1
    }
    
    Write-Log "编译成功" "SUCCESS"
    
    # 2. 创建安装目录
    Write-Log "正在安装到 $InstallDir ..."
    if (!(Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
        Write-Log "创建安装目录：$InstallDir"
    }
    
    # 3. 复制文件
    Copy-Item -Path "$PublishDir\*" -Destination $InstallDir -Force
    $fileCount = (Get-ChildItem $PublishDir).Count
    Write-Log "已复制 $fileCount 个文件到安装目录" "SUCCESS"
    
    # 4. 配置环境变量
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $needsUpdate = $userPath -notlike "*$InstallDir*"
    
    if ($needsUpdate) {
        Write-Log "正在添加环境变量..."
        $newPath = "$userPath;$InstallDir"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Log "已将 $InstallDir 添加到用户 PATH" "SUCCESS"
        
        Write-Log "⚠️  重要提示：" "WARNING"
        Write-Log "   环境变量修改仅对新启动的进程生效。" "WARNING"
        Write-Log "   请【关闭并重新打开】PowerShell 窗口后运行 'jwmv' 命令。" "WARNING"
        
        # 尝试在当前会话中立即生效（仅当前窗口）
        $env:Path += ";$InstallDir"
        Write-Log "已在当前会话中临时生效（无需重启终端即可测试）" "INFO"
    } else {
        Write-Log "环境变量已存在，跳过配置" "INFO"
    }
    
    # 5. 验证安装
    Write-Log "验证安装..."
    $jwmvPath = "$InstallDir\$ExeName"
    if (Test-Path $jwmvPath) {
        $versionInfo = & $jwmvPath --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "安装成功！版本：$versionInfo" "SUCCESS"
        } else {
            Write-Log "安装完成但版本检查失败，请手动运行 '$jwmvPath --version' 排查" "WARNING"
        }
    }
    
    Write-Log "🎉 安装完成！" "SUCCESS"
    Write-Log "下一步操作：" "INFO"
    Write-Log "  1. 重启 PowerShell 窗口（或当前窗口已临时生效）" "INFO"
    Write-Log "  2. 运行 'jwmv doctor' 检查环境" "INFO"
    Write-Log "  3. 运行 'jwmv list java' 查看可用 JDK 版本" "INFO"
    Write-Log "  4. 运行 'jwmv install java 21-tem' 安装 JDK 21" "INFO"
}

function Uninstall-Jwmv {
    Write-Log "开始卸载 JWMV..."
    
    # 1. 从 PATH 中移除
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -like "*$InstallDir*") {
        Write-Log "正在从 PATH 中移除安装目录..."
        $newPath = ($userPath -split ';' | Where-Object { $_ -ne $InstallDir -and $_ -ne "$InstallDir\" }) -join ';'
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Log "已从用户 PATH 中移除" "SUCCESS"
        
        # 同时更新当前会话
        $env:Path = $newPath
    } else {
        Write-Log "PATH 中未找到安装目录，跳过" "INFO"
    }
    
    # 2. 删除安装目录
    if (Test-Path $InstallDir) {
        Write-Log "正在删除安装目录：$InstallDir"
        Remove-Item -Path $InstallDir -Recurse -Force
        Write-Log "已删除安装目录" "SUCCESS"
    } else {
        Write-Log "安装目录不存在，跳过" "INFO"
    }
    
    # 3. 清理发布目录（可选）
    if (Test-Path $PublishDir) {
        Write-Log "清理发布目录..."
        Remove-Item -Path $PublishDir -Recurse -Force
    }
    
    Write-Log "👋 卸载完成！" "SUCCESS"
    Write-Log "如需重新安装，请再次运行此脚本（不带 -Uninstall 参数）" "INFO"
}

# 主逻辑
try {
    if ($Uninstall) {
        Uninstall-Jwmv
    } else {
        Test-Prerequisites
        Install-Jwmv
    }
} catch {
    Write-Log "发生错误：$($_.Exception.Message)" "ERROR"
    if ($Verbose) {
        Write-Log $_.ScriptStackTrace "ERROR"
    }
    exit 1
}
