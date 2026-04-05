using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using TruthPulse.Models;

namespace TruthPulse.Services;

public record IndexedSearchCandidate(MarketSummary Market, double BaseRank);

public sealed class RankingPolicy
{
    public List<SearchResult> Rank(string query, List<IndexedSearchCandidate> candidates)
    {
        var normalizedQuery = NormalizeSearchText(query);
        var tokens = SearchTokens(normalizedQuery);

        var results = new List<SearchResult>();
        foreach (var candidate in candidates)
        {
            var result = Score(normalizedQuery, tokens, candidate);
            if (result != null)
                results.Add(result);
        }

        results.Sort((lhs, rhs) =>
        {
            var cmp = rhs.Score.CompareTo(lhs.Score);
            if (cmp != 0) return cmp;
            return rhs.Market.VolumeSignal.CompareTo(lhs.Market.VolumeSignal);
        });

        return results;
    }

    private SearchResult? Score(string normalizedQuery, string[] tokens, IndexedSearchCandidate candidate)
    {
        var market = candidate.Market;

        if (string.IsNullOrEmpty(normalizedQuery))
        {
            return new SearchResult
            {
                Market = market,
                Score = BaseMarketSignals(market) + candidate.BaseRank,
                MatchedField = MatchField.None,
                MatchedOutcome = null,
                TitleHighlights = new List<TextHighlightRange>(),
                SubtitleHighlights = new List<TextHighlightRange>(),
                OutcomeHighlights = new List<TextHighlightRange>()
            };
        }

        var fields = new (MatchField Field, string Value)[]
        {
            (MatchField.Title, market.Title),
            (MatchField.Subtitle, market.Subtitle ?? ""),
            (MatchField.Outcome, JoinNonNull(" ", market.YesLabel, market.NoLabel)),
            (MatchField.EventTitle, JoinNonNull(" ", market.EventTitle, market.EventSubtitle)),
            (MatchField.Category, market.Category ?? "")
        };

        var bestField = MatchField.None;
        var bestFieldScore = 0.0;
        var anyMatch = false;

        foreach (var (field, value) in fields)
        {
            if (string.IsNullOrEmpty(value)) continue;
            var fieldScore = TextScore(normalizedQuery, tokens, value, field);
            if (fieldScore > 0)
                anyMatch = true;
            if (fieldScore > bestFieldScore)
            {
                bestFieldScore = fieldScore;
                bestField = field;
            }
        }

        if (!anyMatch) return null;

        var outcome = MatchedOutcome(normalizedQuery, tokens, market);
        var titleHighlights = HighlightRanges(market.Title, normalizedQuery, tokens);
        var subtitleHighlights = HighlightRanges(market.Subtitle ?? "", normalizedQuery, tokens);
        var outcomeText = JoinNonNull(" ", market.YesLabel, market.NoLabel);
        var outcomeHighlights = HighlightRanges(outcomeText, normalizedQuery, tokens);

        var score = bestFieldScore;
        score += BaseMarketSignals(market);
        score += candidate.BaseRank;
        score += ProximityBonus(tokens, NormalizeSearchText(market.Title));

        return new SearchResult
        {
            Market = market,
            Score = score,
            MatchedField = bestField,
            MatchedOutcome = outcome,
            TitleHighlights = titleHighlights,
            SubtitleHighlights = subtitleHighlights,
            OutcomeHighlights = outcomeHighlights
        };
    }

    private double TextScore(string query, string[] tokens, string text, MatchField field)
    {
        var normalized = NormalizeSearchText(text);
        if (string.IsNullOrEmpty(normalized)) return 0;

        var weight = FieldWeight(field);
        var score = 0.0;

        if (normalized == query)
            score += weight * 4.0;
        if (normalized.Contains(query, StringComparison.Ordinal))
            score += weight * 2.0;
        if (normalized.StartsWith(query, StringComparison.Ordinal))
            score += weight * 1.2;

        var fieldTokens = SearchTokens(normalized);
        var coveredCount = 0;
        foreach (var token in tokens)
        {
            if (fieldTokens.Any(ft => ft == token || ft.StartsWith(token, StringComparison.Ordinal)))
                coveredCount++;
        }

        score += coveredCount * weight * 0.65;

        if (coveredCount == tokens.Length && tokens.Length > 0)
            score += weight * 1.25;

        return score;
    }

    private MarketOutcomeSide? MatchedOutcome(string query, string[] tokens, MarketSummary market)
    {
        var yesText = NormalizeSearchText(market.YesLabel ?? "");
        var noText = NormalizeSearchText(market.NoLabel ?? "");

        var yesScore = TextScore(query, tokens, yesText, MatchField.Outcome);
        var noScore = TextScore(query, tokens, noText, MatchField.Outcome);

        if (yesScore == 0 && noScore == 0)
            return null;

        return yesScore >= noScore ? MarketOutcomeSide.Yes : MarketOutcomeSide.No;
    }

    private static double FieldWeight(MatchField field) => field switch
    {
        MatchField.Title => 30,
        MatchField.Subtitle => 22,
        MatchField.Outcome => 24,
        MatchField.EventTitle => 18,
        MatchField.Description => 10,
        MatchField.Category => 7,
        _ => 0
    };

    private static double BaseMarketSignals(MarketSummary market)
    {
        var liquidity = Math.Log(1 + (market.Liquidity ?? 0)) * 2.2;
        var volume = Math.Log(1 + Math.Max(market.Volume24h ?? 0, market.Volume ?? 0)) * 2.8;
        var openInterest = Math.Log(1 + (market.OpenInterest ?? 0)) * 1.2;

        var recency = 0.0;
        if (market.UpdatedAt.HasValue)
        {
            var hours = Math.Max((DateTime.UtcNow - market.UpdatedAt.Value).TotalHours, 0);
            recency = Math.Max(0, 6 - hours) * 0.6;
        }

        return liquidity + volume + openInterest + recency;
    }

    private static double ProximityBonus(string[] tokens, string title)
    {
        if (tokens.Length <= 1) return 0;

        var positions = new List<int>();
        foreach (var token in tokens)
        {
            var idx = title.IndexOf(token, StringComparison.Ordinal);
            if (idx < 0) return 0;
            positions.Add(idx);
        }

        if (positions.Count != tokens.Length) return 0;

        var spread = positions.Max() - positions.Min();
        return Math.Max(0, 18 - spread * 0.18);
    }

    private static List<TextHighlightRange> HighlightRanges(string text, string query, string[] tokens)
    {
        var lowercased = text.ToLowerInvariant();
        var ranges = new List<TextHighlightRange>();

        if (!string.IsNullOrEmpty(query))
        {
            var idx = lowercased.IndexOf(query, StringComparison.Ordinal);
            if (idx >= 0)
            {
                ranges.Add(new TextHighlightRange(idx, query.Length));
                return ranges;
            }
        }

        foreach (var token in tokens)
        {
            var idx = lowercased.IndexOf(token, StringComparison.Ordinal);
            if (idx >= 0)
                ranges.Add(new TextHighlightRange(idx, token.Length));
        }

        return ranges;
    }

    public static string NormalizeSearchText(string text)
    {
        var decomposed = text.Normalize(NormalizationForm.FormD);
        var sb = new StringBuilder(decomposed.Length);
        foreach (var c in decomposed)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark)
                sb.Append(c);
        }

        var stripped = sb.ToString().Normalize(NormalizationForm.FormC).ToLowerInvariant();

        // Collapse whitespace
        var parts = stripped.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
        return string.Join(" ", parts);
    }

    public static string[] SearchTokens(string normalizedText)
    {
        // Match Swift: split on non-alphanumeric characters (CharacterSet.alphanumerics.inverted)
        var tokens = new List<string>();
        var sb = new StringBuilder();
        foreach (var c in normalizedText)
        {
            if (char.IsLetterOrDigit(c))
            {
                sb.Append(c);
            }
            else
            {
                if (sb.Length > 0)
                {
                    tokens.Add(sb.ToString());
                    sb.Clear();
                }
            }
        }
        if (sb.Length > 0)
            tokens.Add(sb.ToString());

        return tokens.ToArray();
    }

    private static string JoinNonNull(string separator, params string?[] values)
    {
        return string.Join(separator, values.Where(v => v != null));
    }
}
