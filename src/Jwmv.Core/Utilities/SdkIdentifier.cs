using System.Globalization;
using System.Text.RegularExpressions;

namespace Jwmv.Core.Utilities;

public static partial class SdkIdentifier
{
    public static string NormalizeCandidateName(string value)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(value);
        return value.Trim().ToLowerInvariant();
    }

    public static bool Matches(string alias, string identifier)
    {
        if (string.Equals(alias, identifier, StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        var normalizedAlias = alias.Trim().ToLowerInvariant();
        var normalizedIdentifier = identifier.Trim().ToLowerInvariant();
        return normalizedAlias.StartsWith(normalizedIdentifier, StringComparison.Ordinal);
    }

    public static bool IsStableVersion(string version) =>
        !PreReleasePattern().IsMatch(version);

    public static int CompareVersionsDescending(string? left, string? right)
    {
        var leftTokens = Tokenize(left);
        var rightTokens = Tokenize(right);
        var max = Math.Max(leftTokens.Count, rightTokens.Count);
        for (var index = 0; index < max; index++)
        {
            if (index >= leftTokens.Count)
            {
                return 1;
            }

            if (index >= rightTokens.Count)
            {
                return -1;
            }

            var comparison = CompareToken(leftTokens[index], rightTokens[index]);
            if (comparison != 0)
            {
                return -comparison;
            }
        }

        return string.Compare(right, left, StringComparison.OrdinalIgnoreCase);
    }

    private static List<string> Tokenize(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return [];
        }

        return Tokenizer().Matches(value)
            .Select(match => match.Value)
            .ToList();
    }

    private static int CompareToken(string left, string right)
    {
        if (long.TryParse(left, NumberStyles.None, CultureInfo.InvariantCulture, out var leftNumber) &&
            long.TryParse(right, NumberStyles.None, CultureInfo.InvariantCulture, out var rightNumber))
        {
            return leftNumber.CompareTo(rightNumber);
        }

        return string.Compare(left, right, StringComparison.OrdinalIgnoreCase);
    }

    [GeneratedRegex(@"[0-9]+|[a-zA-Z]+", RegexOptions.NonBacktracking, matchTimeoutMilliseconds: 100)]
    private static partial Regex Tokenizer();

    [GeneratedRegex(@"(?:alpha|beta|rc|milestone|snapshot|nightly|preview|ea)", RegexOptions.IgnoreCase | RegexOptions.NonBacktracking, matchTimeoutMilliseconds: 100)]
    private static partial Regex PreReleasePattern();
}
