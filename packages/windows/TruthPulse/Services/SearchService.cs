using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using TruthPulse.Models;

namespace TruthPulse.Services;

public sealed class SearchService
{
    private readonly KalshiApiClient _apiClient;
    private readonly MarketCacheStore _cacheStore;
    private readonly RankingPolicy _rankingPolicy = new();
    private readonly Dictionary<string, MarketTrend> _trendCache = new();
    private readonly SemaphoreSlim _lock = new(1, 1);

    private List<MarketSummary> _markets = new();
    private List<IndexedMarket> _index = new();
    private DateTime? _lastRefresh;

    public SearchService(KalshiApiClient? apiClient = null, MarketCacheStore? cacheStore = null)
    {
        _apiClient = apiClient ?? new KalshiApiClient();
        _cacheStore = cacheStore ?? new MarketCacheStore();
    }

    public bool HasCachedMarkets => _cacheStore.Exists();
    public bool HasLoadedMarkets => _markets.Count > 0;

    public async Task BootstrapIfNeededAsync()
    {
        await _lock.WaitAsync();
        try
        {
            if (_markets.Count == 0)
            {
                var loaded = await _cacheStore.LoadAsync();
                SetMarkets(loaded);
            }
        }
        finally
        {
            _lock.Release();
        }
    }

    public async Task<DateTime?> LastCacheDateAsync()
    {
        return await _cacheStore.SavedAtAsync();
    }

    public async Task RefreshOpenMarketsAsync(bool force = false)
    {
        await _lock.WaitAsync();
        try
        {
            if (!force && _lastRefresh.HasValue &&
                (DateTime.UtcNow - _lastRefresh.Value).TotalSeconds < 45)
                return;
        }
        finally
        {
            _lock.Release();
        }

        var fetched = await _apiClient.FetchOpenMarketsAsync();

        await _lock.WaitAsync();
        try
        {
            SetMarkets(fetched);
            await _cacheStore.SaveAsync(fetched);
            _lastRefresh = DateTime.UtcNow;
        }
        finally
        {
            _lock.Release();
        }
    }

    public List<SearchResult> Search(string query, int limit = 30)
    {
        var trimmed = query.Trim();
        if (string.IsNullOrEmpty(trimmed))
            return new List<SearchResult>();

        var normalizedQuery = RankingPolicy.NormalizeSearchText(trimmed);
        var tokens = RankingPolicy.SearchTokens(normalizedQuery);

        List<IndexedSearchCandidate> candidates;
        _lock.Wait();
        try
        {
            candidates = _index
                .Where(entry =>
                {
                    if (entry.Haystack.Contains(normalizedQuery, StringComparison.Ordinal))
                        return true;
                    return tokens.All(t => entry.Haystack.Contains(t, StringComparison.Ordinal));
                })
                .Select(entry => new IndexedSearchCandidate(entry.Market, 0))
                .ToList();
        }
        finally
        {
            _lock.Release();
        }

        var results = _rankingPolicy.Rank(query, candidates);
        return results.Take(limit).ToList();
    }

    public async Task<MarketTrend> GetTrendAsync(string marketTicker, string seriesTicker, TrendWindow window)
    {
        var key = $"{marketTicker}::{window}";

        await _lock.WaitAsync();
        try
        {
            if (_trendCache.TryGetValue(key, out var cached) &&
                (DateTime.UtcNow - cached.UpdatedAt).TotalSeconds < 300)
                return cached;
        }
        finally
        {
            _lock.Release();
        }

        var trend = await _apiClient.FetchTrendAsync(marketTicker, seriesTicker, window);

        await _lock.WaitAsync();
        try
        {
            _trendCache[key] = trend;
        }
        finally
        {
            _lock.Release();
        }

        return trend;
    }

    private void SetMarkets(List<MarketSummary> markets)
    {
        _markets = markets;
        _index = markets.Select(market =>
        {
            var fields = new[]
            {
                market.Title,
                market.Subtitle ?? "",
                market.YesLabel ?? "",
                market.NoLabel ?? "",
                market.EventTitle ?? "",
                market.EventSubtitle ?? "",
                market.Category ?? "",
                market.Ticker
            };
            var haystack = RankingPolicy.NormalizeSearchText(string.Join(" ", fields));
            return new IndexedMarket(market, haystack);
        }).ToList();
    }

    private record IndexedMarket(MarketSummary Market, string Haystack);
}
