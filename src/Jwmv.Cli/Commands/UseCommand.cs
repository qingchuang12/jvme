using Jwmv.Core.Abstractions;
using Jwmv.Infrastructure.Windows;
using Spectre.Console;
using Spectre.Console.Cli;
using System.Runtime.InteropServices;

namespace Jwmv.Cli.Commands;

public sealed class UseCommand(ISdkVersionManager manager, IAppContext appContext, IAnsiConsole console) : AsyncCommand<UseCommand.Settings>
{
    public sealed class Settings : CommandSettings
    {
        [CommandArgument(0, "<candidate-or-version>")]
        public string CandidateOrVersion { get; init; } = string.Empty;

        [CommandArgument(1, "[version]")]
        public string? Version { get; init; }

        [CommandOption("--shell <SHELL>")]
        public string? Shell { get; init; }

        [CommandOption("--no-apply")]
        public bool NoApply { get; init; }
    }

    protected override async Task<int> ExecuteAsync(CommandContext context, Settings settings, CancellationToken cancellationToken)
    {
        var (candidateName, version) = CommandHelpers.ResolveCandidateAndVersion(settings.CandidateOrVersion, settings.Version);
        if (string.IsNullOrWhiteSpace(version))
        {
            CommandHelpers.WriteFailure(console, "A version is required.");
            return -1;
        }

        var shell = CommandHelpers.ParseShell(settings.Shell);
        
        // 如果是 PowerShell 且没有指定 --no-apply，则尝试直接应用
        if (shell == ShellKind.PowerShell && !settings.NoApply && IsRunningInPowerShell())
        {
            return await ApplyDirectlyAsync(candidateName, version, cancellationToken);
        }

        if (string.IsNullOrWhiteSpace(settings.Shell))
        {
            var exe = appContext.ExecutablePath;
            CommandHelpers.WriteHeader(console, $"use {candidateName} {version}");
            CommandHelpers.WriteWarning(console, "`use` cannot mutate the current shell by itself when you run the executable directly.");
            console.WriteLine("Use one of these PowerShell commands:");
            console.WriteLine($"Invoke-Expression ((& '{exe}' use '{candidateName}' '{version}' --shell powershell) -join [Environment]::NewLine)");
            console.WriteLine($"Or install shell integration once: & '{exe}' integrate");
            return 0;
        }

        var script = await manager.BuildUseShellScriptAsync(candidateName, version, shell, cancellationToken);
        Console.WriteLine(script);
        return 0;
    }

    private async Task<int> ApplyDirectlyAsync(string candidateName, string version, CancellationToken cancellationToken)
    {
        try
        {
            // 获取已安装的版本信息
            var normalizedCandidate = SdkIdentifier.NormalizeCandidateName(candidateName);
            var installed = await GetInstalledVersionAsync(normalizedCandidate, version, cancellationToken);
            
            if (installed == null)
            {
                CommandHelpers.WriteFailure(console, $"{normalizedCandidate} {version} is not installed.");
                return -1;
            }

            // 设置进程级环境变量（立即生效）
            SetProcessEnvironmentVariable(installed);
            
            // 广播环境变量变更（新终端可继承）
            EnvironmentBroadcast.Notify();

            console.MarkupLine($"[green]✓[/] Activated {installed.CandidateName} {installed.Alias} for this session.");
            console.MarkupLine($"[grey]  {installed.HomeEnvironmentVariable}={installed.HomeDirectory}[/]");
            console.MarkupLine($"[grey]  PATH updated with {installed.BinDirectory}[/]");
            
            return 0;
        }
        catch (Exception ex)
        {
            CommandHelpers.WriteFailure(console, $"Failed to switch version: {ex.Message}");
            return -1;
        }
    }

    private async Task<InstalledSdkVersion?> GetInstalledVersionAsync(string candidateName, string version, CancellationToken cancellationToken)
    {
        var installedVersions = await manager.ListInstalledAsync(candidateName, cancellationToken);
        
        // 精确匹配
        var exactMatch = installedVersions.FirstOrDefault(v => 
            string.Equals(v.Alias, version, StringComparison.OrdinalIgnoreCase) ||
            string.Equals(v.Version, version, StringComparison.OrdinalIgnoreCase));
        
        if (exactMatch != null)
            return exactMatch;

        // 模糊匹配（支持简写）
        var partialMatch = installedVersions.FirstOrDefault(v => 
            v.Alias.StartsWith(version, StringComparison.OrdinalIgnoreCase) ||
            v.Version.StartsWith(version, StringComparison.OrdinalIgnoreCase));
        
        return partialMatch;
    }

    private void SetProcessEnvironmentVariable(InstalledSdkVersion installed)
    {
        var candidate = installed.CandidateName;
        
        // 设置候选者特定的环境变量
        Environment.SetEnvironmentVariable(SdkEnvironmentService.GetActiveVariable(candidate, "VERSION"), installed.Alias, EnvironmentVariableTarget.Process);
        Environment.SetEnvironmentVariable(SdkEnvironmentService.GetActiveVariable(candidate, "HOME"), installed.HomeDirectory, EnvironmentVariableTarget.Process);
        Environment.SetEnvironmentVariable(SdkEnvironmentService.GetActiveVariable(candidate, "BIN"), installed.BinDirectory, EnvironmentVariableTarget.Process);
        Environment.SetEnvironmentVariable(SdkEnvironmentService.GetActiveVariable(candidate, "SOURCE"), "Session", EnvironmentVariableTarget.Process);
        Environment.SetEnvironmentVariable(installed.HomeEnvironmentVariable, installed.HomeDirectory, EnvironmentVariableTarget.Process);
        
        // 更新 PATH
        var currentPath = Environment.GetEnvironmentVariable("PATH", EnvironmentVariableTarget.Process) ?? "";
        var newPath = PathTools.PrependPathEntry(currentPath, installed.BinDirectory);
        Environment.SetEnvironmentVariable("PATH", newPath, EnvironmentVariableTarget.Process);
    }

    private static bool IsRunningInPowerShell()
    {
        var parentProcessName = GetParentProcessName();
        return !string.IsNullOrEmpty(parentProcessName) && 
               (parentProcessName.Equals("powershell", StringComparison.OrdinalIgnoreCase) ||
                parentProcessName.Equals("pwsh", StringComparison.OrdinalIgnoreCase) ||
                parentProcessName.Equals("pwsh.exe", StringComparison.OrdinalIgnoreCase) ||
                parentProcessName.Equals("powershell.exe", StringComparison.OrdinalIgnoreCase));
    }

    private static string? GetParentProcessName()
    {
        try
        {
            using var currentProcess = System.Diagnostics.Process.GetCurrentProcess();
            using var parentProcess = GetParentProcess(currentProcess);
            return parentProcess?.ProcessName;
        }
        catch
        {
            return null;
        }
    }

    private static System.Diagnostics.Process? GetParentProcess(System.Diagnostics.Process process)
    {
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            try
            {
                return System.Diagnostics.Process.GetProcessById(GetParentProcessIdWindows(process.Id));
            }
            catch
            {
                return null;
            }
        }
        return null;
    }

    private static int GetParentProcessIdWindows(int processId)
    {
        try
        {
            using var query = new System.Management.ManagementObjectSearcher(
                $"SELECT ParentProcessId FROM Win32_Process WHERE ProcessId = {processId}");
            using var results = query.Get();
            foreach (var item in results)
            {
                return Convert.ToInt32(item["ParentProcessId"]);
            }
        }
        catch
        {
            // Fallback: try reading from PEB (requires unsafe code, simplified here)
        }
        return 0;
    }
}
