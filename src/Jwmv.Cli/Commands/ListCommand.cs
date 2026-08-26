using Jwmv.Core.Abstractions;
using Jwmv.Core.Models;
using Spectre.Console;
using Spectre.Console.Cli;

namespace Jwmv.Cli.Commands;

public sealed class ListCommand(ISdkVersionManager manager, IAnsiConsole console) : AsyncCommand<ListCommand.Settings>
{
    public sealed class Settings : CommandSettings
    {
        [CommandArgument(0, "[candidate-or-filter]")]
        public string? CandidateOrFilter { get; init; }

        [CommandArgument(1, "[filter]")]
        public string? Filter { get; init; }

        [CommandOption("-r|--refresh")]
        public bool Refresh { get; init; }
    }

    protected override async Task<int> ExecuteAsync(CommandContext context, Settings settings, CancellationToken cancellationToken)
    {
        // If no arguments provided, show all candidates like SDKMAN's "sdk list" without arguments
        if (string.IsNullOrWhiteSpace(settings.CandidateOrFilter) && string.IsNullOrWhiteSpace(settings.Filter))
        {
            return await ShowCandidatesAsync(cancellationToken);
        }

        var candidateName = CommandHelpers.IsKnownCandidate(settings.CandidateOrFilter) ? settings.CandidateOrFilter : "java";
        var filter = CommandHelpers.IsKnownCandidate(settings.CandidateOrFilter) ? settings.Filter : settings.CandidateOrFilter;

        // Force refresh when listing a specific candidate to ensure we have fresh data
        var forceRefresh = settings.Refresh || !string.IsNullOrWhiteSpace(settings.CandidateOrFilter);

        var sdkAvailable = await manager.ListAvailableAsync(new SdkCatalogQuery
        {
            CandidateName = candidateName,
            VersionFilter = filter,
            ForceRefresh = forceRefresh
        }, cancellationToken);
        var installed = await manager.ListInstalledAsync(candidateName, cancellationToken);
        var current = await manager.ResolveCurrentAsync(candidateName!, null, cancellationToken);
        var installedAliases = installed.ToDictionary(item => item.Alias, StringComparer.OrdinalIgnoreCase);
        var wide = CommandHelpers.IsWide(console);
        var medium = CommandHelpers.IsMediumOrWider(console);
        var isJava = string.Equals(candidateName, "java", StringComparison.OrdinalIgnoreCase);

        var table = CommandHelpers.CreateTable();
        if (medium && !isJava)
        {
            table.AddColumn(CommandHelpers.Header("Candidate"));
        }

        table.AddColumn(CommandHelpers.Header("Version"));
        table.AddColumn(CommandHelpers.Header("Alias"));
        if (wide && isJava)
        {
            table.AddColumn(CommandHelpers.Header("Java"));
            table.AddColumn(CommandHelpers.Header("Vendor"));
        }
        else if (wide)
        {
            table.AddColumn(CommandHelpers.Header("Support"));
        }

        table.AddColumn(CommandHelpers.Header("Status"));

        foreach (var package in sdkAvailable)
        {
            var statusParts = new List<string>();
            if (installedAliases.ContainsKey(package.Alias))
            {
                statusParts.Add("[green]installed[/]");
            }

            if (string.Equals(current.Alias, package.Alias, StringComparison.OrdinalIgnoreCase))
            {
                statusParts.Add($"[yellow]{Markup.Escape(current.Source.ToString())}[/]");
            }

            var row = new List<string>();
            if (medium && !isJava)
            {
                row.Add(CommandHelpers.Candidate(package.CandidateName));
            }

            row.Add(CommandHelpers.Version(package.Version));
            row.Add(CommandHelpers.Alias(package.Alias));
            if (wide && isJava)
            {
                // For Java, show version details from DisplayName or Version
                var javaVersionDetails = package.DisplayName != package.Version
                    ? package.DisplayName
                    : package.Version;
                row.Add(CommandHelpers.Text(javaVersionDetails));
                row.Add(CommandHelpers.Text(package.Distribution ?? "N/A"));
            }
            else if (wide)
            {
                row.Add(CommandHelpers.Support(package.SupportTerm));
            }

            row.Add(CommandHelpers.Status(statusParts));
            table.AddRow(row.ToArray());
        }

        console.Write(table);
        CommandHelpers.WriteSuccess(console, $"{sdkAvailable.Count} package(s) shown, {installed.Count} installed locally.");
        return 0;
    }

    private async Task<int> ShowCandidatesAsync(CancellationToken cancellationToken)
    {
        var candidates = await manager.ListCandidatesAsync(null, cancellationToken);
        var wide = CommandHelpers.IsWide(console);
        var medium = CommandHelpers.IsMediumOrWider(console);

        console.MarkupLine("[bold deepskyblue1]SDK candidates[/] [grey]for jwmv[/]");
        console.MarkupLine("[grey]Use[/] [blue]jwmv list <candidate>[/] [grey]to see available versions.[/]");

        var table = CommandHelpers.CreateTable();
        table.AddColumn(CommandHelpers.Header("Candidate"));
        table.AddColumn(CommandHelpers.Header("Latest"));
        table.AddColumn(CommandHelpers.Header("Description"));
        if (medium)
        {
            table.AddColumn(CommandHelpers.Header("Website"));
        }

        if (wide)
        {
            table.AddColumn(CommandHelpers.Header("Try"));
        }

        foreach (var candidate in candidates)
        {
            var row = new List<string>
            {
                CommandHelpers.Candidate(candidate.Name),
                CommandHelpers.Version(candidate.LatestVersion),
                CommandHelpers.Text(CommandHelpers.Shorten(candidate.Description, wide ? 44 : 28))
            };

            if (medium)
            {
                row.Add(CommandHelpers.Url(candidate.WebsiteUri));
            }

            if (wide)
            {
                row.Add($"[grey]jwmv list[/] [blue]{Markup.Escape(candidate.Name)}[/]");
            }

            table.AddRow(row.ToArray());
        }

        console.Write(table);
        CommandHelpers.WriteSuccess(console, $"{candidates.Count} candidate(s) shown.");
        return 0;
    }
}
