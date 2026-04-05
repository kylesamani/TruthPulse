using System;
using System.Collections.Generic;

namespace TruthPulse.Models;

public enum MarketOutcomeSide
{
    Yes,
    No
}

public enum MatchField
{
    None,
    Title,
    Subtitle,
    Outcome,
    EventTitle,
    Description,
    Category
}

public record TextHighlightRange(int Start, int Length);

public record MarketSummary
{
    public string Ticker { get; init; } = "";
    public string? EventTicker { get; init; }
    public string? SeriesTicker { get; init; }
    public string Title { get; init; } = "";
    public string? Subtitle { get; init; }
    public string? YesLabel { get; init; }
    public string? NoLabel { get; init; }
    public string? EventTitle { get; init; }
    public string? EventSubtitle { get; init; }
    public string? Category { get; init; }
    public string Status { get; init; } = "active";
    public double? LastPrice { get; init; }
    public double? YesPrice { get; init; }
    public double? NoPrice { get; init; }
    public double? Volume { get; init; }
    public double? Volume24h { get; init; }
    public double? OpenInterest { get; init; }
    public double? Liquidity { get; init; }
    public DateTime? UpdatedAt { get; init; }
    public DateTime? OpenTime { get; init; }
    public DateTime? CloseTime { get; init; }
    public string? WebUrl { get; init; }

    public string Id => Ticker;

    public int? DisplayOdds
    {
        get
        {
            var price = YesPrice ?? LastPrice;
            if (price == null) return null;
            return (int)Math.Round(price.Value * 100);
        }
    }

    public double VolumeSignal => Math.Max(Volume24h ?? 0, Volume ?? 0);

    public string ResolvedWebUrl()
    {
        if (WebUrl != null)
            return WebUrl;

        if (SeriesTicker != null && EventTicker != null)
        {
            var series = SeriesTicker.ToLowerInvariant();
            var evt = EventTicker.ToLowerInvariant();
            return $"https://kalshi.com/markets/{series}/m/{evt}";
        }

        return $"https://kalshi.com/browse?query={Uri.EscapeDataString(Title)}";
    }
}

public record SearchResult
{
    public MarketSummary Market { get; init; } = new();
    public double Score { get; init; }
    public MatchField MatchedField { get; init; }
    public MarketOutcomeSide? MatchedOutcome { get; init; }
    public List<TextHighlightRange> TitleHighlights { get; init; } = new();
    public List<TextHighlightRange> SubtitleHighlights { get; init; } = new();
    public List<TextHighlightRange> OutcomeHighlights { get; init; } = new();

    public string Id => Market.Id;

    public int? EmphasizedOdds => MatchedOutcome switch
    {
        MarketOutcomeSide.Yes => Market.YesPrice != null
            ? (int)Math.Round(Market.YesPrice.Value * 100)
            : Market.DisplayOdds,
        MarketOutcomeSide.No => Market.NoPrice != null
            ? (int)Math.Round(Market.NoPrice.Value * 100)
            : Market.DisplayOdds,
        _ => Market.DisplayOdds
    };

    public string EmphasizedOutcomeLabel => MatchedOutcome switch
    {
        MarketOutcomeSide.Yes => Market.YesLabel ?? "YES",
        MarketOutcomeSide.No => Market.NoLabel ?? "NO",
        _ => "YES"
    };
}
