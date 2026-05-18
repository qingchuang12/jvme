using System.Xml.Linq;
using Jwmv.Core.Abstractions;
using Jwmv.Core.Models;
using Jwmv.Core.Utilities;

namespace Jwmv.Infrastructure.Catalog;

public sealed class MavenCatalogProvider(IHttpClientFactory httpClientFactory) : ISdkCatalogProvider
{
    private const string MetadataPath = "maven2/org/apache/maven/apache-maven/maven-metadata.xml";

    public SdkCandidate Candidate { get; } = new()
    {
        Name = "maven",
        DisplayName = "Apache Maven",
        Description = "Build and dependency management tool for Java projects.",
        WebsiteUri = new Uri("https://maven.apache.org/"),
        HomeEnvironmentVariable = "MAVEN_HOME",
        PrimaryExecutableName = OperatingSystem.IsWindows() ? "mvn.cmd" : "mvn"
    };

    public async Task<IReadOnlyList<SdkPackage>> GetPackagesAsync(CancellationToken cancellationToken)
    {
        using var client = httpClientFactory.CreateClient(ServiceCollectionExtensions.MavenCentralClientName);
        var xml = await client.GetStringAsync(MetadataPath, cancellationToken);
        var document = XDocument.Parse(xml);
        var versions = document.Descendants("version")
            .Select(element => element.Value.Trim())
            .Where(version => !string.IsNullOrWhiteSpace(version))
            .Where(SdkIdentifier.IsStableVersion)
            .ToList();

        return versions
            .Select(CreatePackage)
            .OrderBy(package => package.Version, Comparer<string>.Create(SdkIdentifier.CompareVersionsDescending))
            .ToList();
    }

    private SdkPackage CreatePackage(string version)
    {
        var fileName = $"apache-maven-{version}-bin.zip";
        var path = $"maven2/org/apache/maven/apache-maven/{version}/{fileName}";
        var downloadUri = new Uri($"https://repo.maven.apache.org/{path}", UriKind.Absolute);
        return new SdkPackage
        {
            Id = $"maven-{version}",
            CandidateName = Candidate.Name,
            Version = version,
            Alias = version,
            DisplayName = version,
            ArchiveType = "zip",
            FileName = fileName,
            DownloadUri = downloadUri,
            ChecksumUri = new Uri($"{downloadUri}.sha512", UriKind.Absolute),
            ChecksumType = "sha512"
        };
    }
}
