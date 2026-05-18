using System.Globalization;
using System.Security.Cryptography;
using Jwmv.Core.Abstractions;
using Jwmv.Core.Models;

namespace Jwmv.Infrastructure.Net;

public sealed class ChecksumVerifier : IChecksumVerifier
{
    public async Task<ChecksumVerificationResult> VerifyAsync(string filePath, string expectedChecksum, string checksumType, CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(expectedChecksum);
        ArgumentException.ThrowIfNullOrWhiteSpace(checksumType);

        var normalizedType = checksumType.Trim().ToLowerInvariant();
        await using var stream = File.OpenRead(filePath);
        var hash = normalizedType switch
        {
            "sha256" => await SHA256.HashDataAsync(stream, cancellationToken),
            "sha512" => await SHA512.HashDataAsync(stream, cancellationToken),
            _ => throw new NotSupportedException($"Checksum type '{checksumType}' is not supported.")
        };

        var actual = Convert.ToHexString(hash).ToLower(CultureInfo.InvariantCulture);
        var expected = ExtractChecksumValue(expectedChecksum).ToLower(CultureInfo.InvariantCulture);
        return new ChecksumVerificationResult
        {
            IsValid = string.Equals(actual, expected, StringComparison.OrdinalIgnoreCase),
            Expected = expected,
            Actual = actual
        };
    }

    private static string ExtractChecksumValue(string value) =>
        value.Trim().Split([' ', '\t', '\r', '\n'], StringSplitOptions.RemoveEmptyEntries)[0];
}
