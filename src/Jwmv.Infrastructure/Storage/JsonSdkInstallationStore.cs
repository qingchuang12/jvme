using Jwmv.Core.Abstractions;
using Jwmv.Core;
using Jwmv.Core.Models;
using Jwmv.Core.Utilities;
using System.Text.Json;

namespace Jwmv.Infrastructure.Storage;

public sealed class JsonSdkInstallationStore(JwmvPaths paths) : ISdkInstallationStore
{
    public async Task<IReadOnlyList<InstalledSdkVersion>> GetInstalledVersionsAsync(string? candidateName, CancellationToken cancellationToken)
    {
        paths.EnsureCreated();
        var result = new List<InstalledSdkVersion>();
        var roots = string.IsNullOrWhiteSpace(candidateName)
            ? Directory.EnumerateDirectories(Path.Combine(paths.VarDirectory, JwmvConstants.ManifestsDirectoryName), "*", SearchOption.TopDirectoryOnly)
            : Directory.Exists(paths.GetCandidateManifestsDirectory(SdkIdentifier.NormalizeCandidateName(candidateName)))
                ? [paths.GetCandidateManifestsDirectory(SdkIdentifier.NormalizeCandidateName(candidateName))]
                : Array.Empty<string>();

        foreach (var root in roots)
        {
            foreach (var file in Directory.EnumerateFiles(root, "*.json", SearchOption.TopDirectoryOnly))
            {
                var item = await ReadInstalledAsync(file, cancellationToken);
                if (item is not null)
                {
                    result.Add(item);
                }
            }
        }

        return result;
    }

    public async Task<InstalledSdkVersion?> FindAsync(string candidateName, string alias, CancellationToken cancellationToken)
    {
        var normalizedCandidate = SdkIdentifier.NormalizeCandidateName(candidateName);
        var exact = await ReadInstalledAsync(GetManifestPath(normalizedCandidate, alias), cancellationToken);
        if (exact is not null)
        {
            return exact;
        }

        var installed = await GetInstalledVersionsAsync(normalizedCandidate, cancellationToken);
        return installed
            .Where(item => SdkIdentifier.Matches(item.Alias, alias))
            .OrderBy(item => item.Version, Comparer<string>.Create(SdkIdentifier.CompareVersionsDescending))
            .FirstOrDefault();
    }

    public Task SaveAsync(InstalledSdkVersion installedVersion, CancellationToken cancellationToken)
    {
        var normalizedCandidate = SdkIdentifier.NormalizeCandidateName(installedVersion.CandidateName);
        paths.EnsureCandidateCreated(normalizedCandidate);
        return JsonFileHelper.WriteAsync(GetManifestPath(normalizedCandidate, installedVersion.Alias), installedVersion, cancellationToken);
    }

    public Task DeleteAsync(string candidateName, string alias, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var normalizedCandidate = SdkIdentifier.NormalizeCandidateName(candidateName);
        var path = GetManifestPath(normalizedCandidate, alias);
        if (File.Exists(path))
        {
            File.Delete(path);
        }

        return Task.CompletedTask;
    }

    private string GetManifestPath(string candidateName, string alias) =>
        Path.Combine(paths.GetCandidateManifestsDirectory(candidateName), $"{alias}.json");

    private static async Task<InstalledSdkVersion?> ReadInstalledAsync(string filePath, CancellationToken cancellationToken)
    {
        try
        {
            return await JsonFileHelper.ReadAsync<InstalledSdkVersion>(filePath, cancellationToken);
        }
        catch (JsonException)
        {
            var legacy = await JsonFileHelper.ReadAsync<InstalledJavaVersion>(filePath, cancellationToken);
            if (legacy is null)
            {
                return null;
            }

            return new InstalledSdkVersion
            {
                CandidateName = JwmvConstants.CandidateName,
                Version = legacy.JavaVersion,
                Alias = legacy.Alias,
                DisplayName = legacy.DisplayAlias,
                Distribution = legacy.Distribution,
                DistributionAlias = legacy.DistributionAlias,
                InstallDirectory = legacy.InstallDirectory,
                HomeDirectory = legacy.JavaHome,
                BinDirectory = Path.Combine(legacy.JavaHome, "bin"),
                HomeEnvironmentVariable = "JAVA_HOME",
                PrimaryExecutableName = OperatingSystem.IsWindows() ? "java.exe" : "java",
                ArchiveType = legacy.ArchiveType,
                PackageFileName = legacy.PackageFileName,
                SourcePackageId = legacy.SourcePackageId,
                InstalledAtUtc = legacy.InstalledAtUtc
            };
        }
    }
}
