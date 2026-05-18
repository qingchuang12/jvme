namespace Jwmv.Core.Models;

public sealed record ChecksumVerificationResult
{
    public required bool IsValid { get; init; }
    public required string Expected { get; init; }
    public required string Actual { get; init; }
}
