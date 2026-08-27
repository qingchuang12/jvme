using Jwmv.Core.Abstractions;
using Jwmv.Core.Models;
using Spectre.Console;
using Spectre.Console.Cli;

namespace Jwmv.Cli.Commands;

public sealed class CandidatesCommand(ISdkVersionManager manager, IAnsiConsole console) : AsyncCommand<CandidatesCommand.Settings>
{
    public sealed class Settings : CommandSettings
    {
        [CommandArgument(0, "[filter]")]
        public string? Filter { get; init; }

        [CommandOption("-i|--interactive")]
        public bool Interactive { get; init; }

        [CommandOption("--no-interactive")]
        public bool NoInteractive { get; init; }
    }

    protected override async Task<int> ExecuteAsync(CommandContext context, Settings settings, CancellationToken cancellationToken)
    {
        var candidates = await manager.ListCandidatesAsync(settings.Filter, cancellationToken);
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
