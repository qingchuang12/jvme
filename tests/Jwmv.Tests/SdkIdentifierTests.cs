using Jwmv.Core.Utilities;

namespace Jwmv.Tests;

public sealed class SdkIdentifierTests
{
    [Theory]
    [InlineData("9.5.1", true)]
    [InlineData("4.0.0-rc-5", false)]
    [InlineData("9.6.0-milestone-2", false)]
    [InlineData("2.3.0-Beta", false)]
    public void IsStableVersion_FiltersPrereleaseMarkers(string version, bool expected)
    {
        Assert.Equal(expected, SdkIdentifier.IsStableVersion(version));
    }

    [Fact]
    public void CompareVersionsDescending_PrefersNewestStableVersion()
    {
        var versions = new[] { "3.9.8", "3.9.15", "3.8.9" };

        var sorted = versions.OrderBy(item => item, Comparer<string>.Create(SdkIdentifier.CompareVersionsDescending)).ToList();

        Assert.Equal(["3.9.15", "3.9.8", "3.8.9"], sorted);
    }
}
