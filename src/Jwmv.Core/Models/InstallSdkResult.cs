namespace Jwmv.Core.Models;

public sealed record InstallSdkResult
{
    public required InstalledSdkVersion InstalledVersion { get; init; }
    public bool AlreadyInstalled { get; init; }
    public bool DefaultWasUpdated { get; init; }
}
