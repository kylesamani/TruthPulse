using System;
using System.Collections.Generic;

namespace TruthPulse.Models;

public enum TrendWindow
{
    OneDay,
    SevenDays,
    ThirtyDays
}

public static class TrendWindowExtensions
{
    public static string Label(this TrendWindow window) => window switch
    {
        TrendWindow.OneDay => "1D",
        TrendWindow.SevenDays => "7D",
        TrendWindow.ThirtyDays => "30D",
        _ => "1D"
    };

    public static double DurationSeconds(this TrendWindow window) => window switch
    {
        TrendWindow.OneDay => 86400,
        TrendWindow.SevenDays => 604800,
        TrendWindow.ThirtyDays => 2592000,
        _ => 86400
    };

    public static int IntervalMinutes(this TrendWindow window) => window switch
    {
        TrendWindow.OneDay => 1,
        TrendWindow.SevenDays => 60,
        TrendWindow.ThirtyDays => 1440,
        _ => 1
    };
}

public record TrendPoint(DateTime Date, double Value);

public record MarketTrend
{
    public string MarketTicker { get; init; } = "";
    public TrendWindow Window { get; init; }
    public List<TrendPoint> Points { get; init; } = new();
    public double? Delta { get; init; }
    public DateTime UpdatedAt { get; init; }
}
