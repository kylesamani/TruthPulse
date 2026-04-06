using System;
using System.Collections.Generic;
using System.Globalization;
using System.Net;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;
using TruthPulse.Models;

namespace TruthPulse.Services;

public sealed class KalshiApiClient
{
    private const string BaseUrl = "https://api.elections.kalshi.com/trade-api/v2";
    private readonly HttpClient _http;

    public KalshiApiClient()
    {
        var handler = new HttpClientHandler
        {
            UseCookies = false
        };
        _http = new HttpClient(handler)
        {
            Timeout = TimeSpan.FromSeconds(20)
        };
        _http.DefaultRequestHeaders.Add("Accept", "application/json");
        _http.DefaultRequestHeaders.Add("User-Agent", "TruthPulse/1.0");
    }

    public async Task<List<MarketSummary>> FetchOpenMarketsAsync()
    {
        var allMarkets = new List<MarketSummary>();
        string? cursor = null;
        var consecutiveErrors = 0;

        do
        {
            var url = $"{BaseUrl}/events?status=open&limit=200&with_nested_markets=true";
            if (!string.IsNullOrEmpty(cursor))
                url += $"&cursor={Uri.EscapeDataString(cursor)}";

            string json;
            try
            {
                var response = await _http.GetAsync(url);

                if (response.StatusCode == HttpStatusCode.TooManyRequests)
                {
                    consecutiveErrors++;
                    if (consecutiveErrors >= 3)
                    {
                        // Return what we have so far rather than losing everything
                        break;
                    }
                    // Backoff: wait 2s, 4s
                    await Task.Delay(consecutiveErrors * 2000);
                    continue;
                }

                response.EnsureSuccessStatusCode();
                json = await response.Content.ReadAsStringAsync();
                consecutiveErrors = 0;
            }
            catch (HttpRequestException) when (allMarkets.Count > 0)
            {
                // If we already have some markets, return them rather than throwing
                break;
            }

            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            cursor = root.TryGetProperty("cursor", out var cursorEl)
                ? cursorEl.GetString()
                : null;

            if (!root.TryGetProperty("events", out var eventsEl))
                break;

            foreach (var eventEl in eventsEl.EnumerateArray())
            {
                var eventTicker = GetStringOrNull(eventEl, "event_ticker");
                var seriesTicker = GetStringOrNull(eventEl, "series_ticker");
                var eventTitle = GetStringOrNull(eventEl, "title");
                var eventSubtitle = GetStringOrNull(eventEl, "sub_title");
                var category = GetStringOrNull(eventEl, "category");

                var eventUrl = GetStringOrNull(eventEl, "url");

                if (!eventEl.TryGetProperty("markets", out var marketsEl))
                    continue;

                foreach (var m in marketsEl.EnumerateArray())
                {
                    var status = (GetStringOrNull(m, "status") ?? "").ToLowerInvariant();
                    if (status != "active" && status != "open")
                        continue;

                    var ticker = GetStringOrNull(m, "ticker") ?? "";
                    var title = GetStringOrNull(m, "title") ?? eventTitle ?? ticker;
                    var subtitle = GetStringOrNull(m, "sub_title");
                    var yesLabel = GetStringOrNull(m, "yes_sub_title");
                    var noLabel = GetStringOrNull(m, "no_sub_title");
                    var marketUrl = GetStringOrNull(m, "url") ?? eventUrl;

                    var lastPrice = ParseFlexibleDouble(m, "last_price_dollars");
                    var yesAsk = ParseFlexibleDouble(m, "yes_ask_dollars");
                    var yesBid = ParseFlexibleDouble(m, "yes_bid_dollars");
                    var noAsk = ParseFlexibleDouble(m, "no_ask_dollars");
                    var noBid = ParseFlexibleDouble(m, "no_bid_dollars");

                    var yesPrice = yesAsk ?? yesBid ?? lastPrice;
                    var noPrice = noAsk ?? noBid ?? (lastPrice.HasValue ? Math.Max(0, 1 - lastPrice.Value) : (double?)null);

                    var volume = ParseFlexibleDouble(m, "volume_fp");
                    var volume24h = ParseFlexibleDouble(m, "volume_24h_fp");
                    var openInterest = ParseFlexibleDouble(m, "open_interest_fp");
                    var liquidity = ParseFlexibleDouble(m, "liquidity_dollars");

                    var updatedAt = ParseFlexibleDate(m, "updated_time");
                    var openTime = ParseFlexibleDate(m, "open_time");
                    var closeTime = ParseFlexibleDate(m, "close_time");

                    allMarkets.Add(new MarketSummary
                    {
                        Ticker = ticker,
                        EventTicker = eventTicker,
                        SeriesTicker = seriesTicker,
                        Title = title,
                        Subtitle = subtitle,
                        YesLabel = yesLabel,
                        NoLabel = noLabel,
                        EventTitle = eventTitle,
                        EventSubtitle = eventSubtitle,
                        Category = category,
                        Status = status,
                        LastPrice = NormalizeUnitPrice(lastPrice),
                        YesPrice = NormalizeUnitPrice(yesPrice),
                        NoPrice = NormalizeUnitPrice(noPrice),
                        Volume = volume,
                        Volume24h = volume24h,
                        OpenInterest = openInterest,
                        Liquidity = liquidity,
                        UpdatedAt = updatedAt,
                        OpenTime = openTime,
                        CloseTime = closeTime,
                        WebUrl = marketUrl
                    });
                }
            }

            if (string.IsNullOrEmpty(cursor))
                break;

        } while (true);

        return allMarkets;
    }

    public async Task<MarketTrend> FetchTrendAsync(string marketTicker, string seriesTicker, TrendWindow window)
    {
        var now = DateTimeOffset.UtcNow;
        var startTs = now.ToUnixTimeSeconds() - (long)window.DurationSeconds();
        var endTs = now.ToUnixTimeSeconds();
        var interval = window.IntervalMinutes();

        var url = $"{BaseUrl}/series/{seriesTicker}/markets/{marketTicker}/candlesticks" +
                  $"?start_ts={startTs}&end_ts={endTs}&period_interval={interval}";

        var json = await _http.GetStringAsync(url);
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        var points = new List<TrendPoint>();

        if (root.TryGetProperty("candlesticks", out var candlesEl))
        {
            foreach (var candle in candlesEl.EnumerateArray())
            {
                var endTsVal = ParseFlexibleLong(candle, "end_period_ts");
                var rawPrice = GetCandlePrice(candle);

                if (endTsVal == null || rawPrice == null)
                    continue;

                var normalizedPrice = rawPrice.Value > 1 ? rawPrice.Value : rawPrice.Value * 100;

                var date = DateTimeOffset.FromUnixTimeSeconds(endTsVal.Value).UtcDateTime;
                points.Add(new TrendPoint(date, normalizedPrice));
            }
        }

        points.Sort((a, b) => a.Date.CompareTo(b.Date));

        double? delta = null;
        if (points.Count >= 2)
            delta = points[^1].Value - points[0].Value;

        return new MarketTrend
        {
            MarketTicker = marketTicker,
            Window = window,
            Points = points,
            Delta = delta,
            UpdatedAt = DateTime.UtcNow
        };
    }

    private static double? GetCandlePrice(JsonElement candle)
    {
        if (candle.TryGetProperty("yes_ask", out var yesAsk))
        {
            var val = ParseFlexibleDoubleFromElement(yesAsk, "close_dollars");
            if (val != null) return val;
        }

        if (candle.TryGetProperty("yes_bid", out var yesBid))
        {
            var val = ParseFlexibleDoubleFromElement(yesBid, "close_dollars");
            if (val != null) return val;
        }

        if (candle.TryGetProperty("price", out var price))
        {
            var val = ParseFlexibleDoubleFromElement(price, "previous_dollars");
            if (val != null) return val;
        }

        return null;
    }

    private static double? NormalizeUnitPrice(double? value)
    {
        if (value == null) return null;
        return value.Value > 1 ? value.Value / 100 : value.Value;
    }

    private static string? GetStringOrNull(JsonElement el, string prop)
    {
        if (el.TryGetProperty(prop, out var val) && val.ValueKind == JsonValueKind.String)
            return val.GetString();
        return null;
    }

    private static double? ParseFlexibleDouble(JsonElement parent, string prop)
    {
        if (!parent.TryGetProperty(prop, out var el))
            return null;
        return ParseFlexibleDoubleValue(el);
    }

    private static double? ParseFlexibleDoubleFromElement(JsonElement parent, string prop)
    {
        if (!parent.TryGetProperty(prop, out var el))
            return null;
        return ParseFlexibleDoubleValue(el);
    }

    private static double? ParseFlexibleDoubleValue(JsonElement el)
    {
        switch (el.ValueKind)
        {
            case JsonValueKind.Number:
                return el.GetDouble();
            case JsonValueKind.String:
                var s = el.GetString();
                if (double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out var d))
                    return d;
                return null;
            default:
                return null;
        }
    }

    private static long? ParseFlexibleLong(JsonElement parent, string prop)
    {
        if (!parent.TryGetProperty(prop, out var el))
            return null;

        return el.ValueKind switch
        {
            JsonValueKind.Number => el.GetInt64(),
            JsonValueKind.String when long.TryParse(el.GetString(), out var l) => l,
            _ => null
        };
    }

    private static DateTime? ParseFlexibleDate(JsonElement parent, string prop)
    {
        if (!parent.TryGetProperty(prop, out var el))
            return null;

        if (el.ValueKind == JsonValueKind.String)
        {
            var s = el.GetString();
            if (s == null) return null;

            if (DateTimeOffset.TryParse(s, CultureInfo.InvariantCulture,
                    DateTimeStyles.RoundtripKind, out var dto))
                return dto.UtcDateTime;
        }

        if (el.ValueKind == JsonValueKind.Number)
        {
            return DateTimeOffset.FromUnixTimeSeconds(el.GetInt64()).UtcDateTime;
        }

        return null;
    }
}
