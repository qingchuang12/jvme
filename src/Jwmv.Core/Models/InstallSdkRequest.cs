namespace Jwmv.Core.Models;

public sealed record InstallSdkRequest
{
    public required string CandidateName { get; init; }
    public required string Version { get; init; }
    public bool SetAsDefault { get; init; }
    public bool ForceCatalogRefresh { get; init; }
}
