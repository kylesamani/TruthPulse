using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.UI.Dispatching;
using TruthPulse.Models;
using TruthPulse.Services;

namespace TruthPulse.ViewModels;

public partial class SearchViewModel : ObservableObject
{
    private readonly SearchService _searchService;
    private readonly DispatcherQueue _dispatcherQueue;
    private Timer? _debounceTimer;
    private const int DebounceMs = 80;
    private const int MinQueryLength = 4;

    [ObservableProperty]
    private string _query = "";

    [ObservableProperty]
    private SearchResult? _selectedResult;

    [ObservableProperty]
    private TrendWindow _selectedWindow = TrendWindow.SevenDays;

    [ObservableProperty]
    private bool _isRefreshing;

    [ObservableProperty]
    private string? _lastSyncText;

    [ObservableProperty]
    private string? _errorMessage;

    [ObservableProperty]
    private MarketTrend? _selectedTrend;

    [ObservableProperty]
    private int _resultCount;

    public ObservableCollection<SearchResult> Results { get; } = new();

    public bool HasCachedMarkets => _searchService.HasCachedMarkets;

    /// <summary>
    /// Raised after Results collection is updated on the UI thread.
    /// MainWindow subscribes to rebuild the ListView.
    /// </summary>
    public event Action? ResultsChanged;

    public SearchViewModel(DispatcherQueue dispatcherQueue)
        : this(new SearchService(), dispatcherQueue) { }

    public SearchViewModel(SearchService searchService, DispatcherQueue dispatcherQueue)
    {
        _searchService = searchService;
        _dispatcherQueue = dispatcherQueue;
    }

    partial void OnQueryChanged(string value)
    {
        _debounceTimer?.Dispose();
        _debounceTimer = new Timer(_ => RunSearch(value), null, DebounceMs, Timeout.Infinite);
    }

    partial void OnSelectedResultChanged(SearchResult? value)
    {
        if (value != null)
            _ = LoadTrendIfNeededAsync(value);
    }

    partial void OnSelectedWindowChanged(TrendWindow value)
    {
        if (SelectedResult != null)
            _ = LoadTrendIfNeededAsync(SelectedResult);
    }

    private void RunSearch(string query)
    {
        var trimmed = query.Trim();

        List<SearchResult> results;
        if (trimmed.Length < MinQueryLength)
        {
            results = new List<SearchResult>();
        }
        else
        {
            results = _searchService.Search(trimmed);
        }

        _dispatcherQueue.TryEnqueue(() =>
        {
            Results.Clear();
            foreach (var r in results)
                Results.Add(r);

            ResultCount = Results.Count;

            if (Results.Count > 0)
                SelectedResult = Results[0];
            else
                SelectedResult = null;

            ResultsChanged?.Invoke();
        });
    }

    public async Task OnPopoverOpenAsync()
    {
        ErrorMessage = null;

        try
        {
            await _searchService.BootstrapIfNeededAsync();
            UpdateSyncText();

            var lastSync = await _searchService.LastCacheDateAsync();
            if (lastSync == null || (DateTime.UtcNow - lastSync.Value).TotalSeconds > 60)
            {
                await RefreshMarketsAsync();
            }
        }
        catch (Exception ex)
        {
            ErrorMessage = $"Failed to load markets: {ex.Message}";
        }
    }

    [RelayCommand]
    public async Task RefreshMarketsAsync()
    {
        if (IsRefreshing) return;
        IsRefreshing = true;
        ErrorMessage = null;

        try
        {
            await _searchService.RefreshOpenMarketsAsync(force: true);
            UpdateSyncText();

            if (!string.IsNullOrWhiteSpace(Query) && Query.Trim().Length >= MinQueryLength)
                RunSearch(Query);
        }
        catch (Exception ex)
        {
            ErrorMessage = $"Refresh failed: {ex.Message}";
        }
        finally
        {
            IsRefreshing = false;
        }
    }

    private async Task LoadTrendIfNeededAsync(SearchResult result)
    {
        if (result.Market.SeriesTicker == null)
        {
            SelectedTrend = null;
            return;
        }

        try
        {
            var trend = await _searchService.GetTrendAsync(
                result.Market.Ticker,
                result.Market.SeriesTicker,
                SelectedWindow);
            SelectedTrend = trend;
        }
        catch
        {
            SelectedTrend = null;
        }
    }

    public void MoveSelection(int offset)
    {
        if (Results.Count == 0) return;

        var currentIndex = SelectedResult != null ? Results.IndexOf(SelectedResult) : -1;
        var newIndex = Math.Clamp(currentIndex + offset, 0, Results.Count - 1);
        SelectedResult = Results[newIndex];
    }

    [RelayCommand]
    public void OpenSelectedMarket()
    {
        if (SelectedResult == null) return;
        var url = SelectedResult.Market.ResolvedWebUrl();
        try
        {
            Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
        }
        catch
        {
            // Silently fail if browser can't open
        }
    }

    private async void UpdateSyncText()
    {
        var savedAt = await _searchService.LastCacheDateAsync();
        if (savedAt.HasValue)
        {
            var ago = DateTime.UtcNow - savedAt.Value;
            LastSyncText = ago.TotalMinutes < 1
                ? "Last synced just now"
                : ago.TotalMinutes < 60
                    ? $"Last synced {(int)ago.TotalMinutes}m ago"
                    : $"Last synced {(int)ago.TotalHours}h ago";
        }
        else
        {
            LastSyncText = null;
        }
    }
}
