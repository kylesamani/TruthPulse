package com.truthpulse.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.truthpulse.TruthPulseApp
import com.truthpulse.data.MarketTrend
import com.truthpulse.data.SearchResult
import com.truthpulse.data.TrendWindow
import android.util.Log
import com.truthpulse.search.SearchIndexer
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

data class SearchUiState(
    val query: String = "",
    val results: List<SearchResult> = emptyList(),
    val trends: Map<String, MarketTrend> = emptyMap(),
    val isSyncing: Boolean = true,
    val marketCount: Int = 0,
    val error: String? = null,
)

class SearchViewModel(application: Application) : AndroidViewModel(application) {

    private val app = application as TruthPulseApp
    private val searchService = app.searchService
    private val searchIndexer = SearchIndexer(application)

    private val _uiState = MutableStateFlow(SearchUiState())
    val uiState: StateFlow<SearchUiState> = _uiState.asStateFlow()

    private var searchJob: Job? = null
    private val trendJobs = mutableMapOf<String, Job>()

    init {
        loadMarkets()
    }

    private fun loadMarkets() {
        viewModelScope.launch {
            Log.d("TruthPulse", "loadMarkets: starting")
            _uiState.update { it.copy(isSyncing = true, error = null) }

            try {
                // Try loading from cache first
                val hasCached = searchService.hasLoadedMarkets()
                Log.d("TruthPulse", "loadMarkets: hasCached=$hasCached")
                if (hasCached) {
                    _uiState.update {
                        it.copy(
                            isSyncing = false,
                            marketCount = searchService.marketCount,
                        )
                    }
                }

                // Then refresh from network
                Log.d("TruthPulse", "loadMarkets: refreshing from network")
                searchService.refreshOpenMarkets(force = true)
                Log.d("TruthPulse", "loadMarkets: done, marketCount=${searchService.marketCount}")
                _uiState.update {
                    it.copy(
                        isSyncing = false,
                        marketCount = searchService.marketCount,
                        error = null,
                    )
                }

                // Index into AppSearch for OS-level search
                launch {
                    searchIndexer.indexMarkets(searchService.allMarkets())
                }

                // Re-run search if there's an active query
                val query = _uiState.value.query
                if (query.length >= 4) {
                    performSearch(query)
                }
            } catch (e: Exception) {
                Log.e("TruthPulse", "loadMarkets: error", e)
                val hasCached = searchService.marketCount > 0
                _uiState.update {
                    it.copy(
                        isSyncing = false,
                        error = if (!hasCached) "Failed to load markets: ${e.message}" else null,
                    )
                }
            }
        }
    }

    fun updateQuery(query: String) {
        Log.d("TruthPulse", "updateQuery: '$query'")
        _uiState.update { it.copy(query = query) }

        searchJob?.cancel()

        if (query.length < 4) {
            _uiState.update { it.copy(results = emptyList(), trends = emptyMap()) }
            return
        }

        // 80ms debounce
        searchJob = viewModelScope.launch {
            delay(80)
            performSearch(query)
        }
    }

    private fun performSearch(query: String) {
        val results = searchService.search(query)
        Log.d("TruthPulse", "performSearch: '$query' -> ${results.size} results")
        _uiState.update {
            it.copy(results = results)
        }
    }

    fun loadTrend(result: SearchResult) {
        val ticker = result.market.ticker
        val seriesTicker = result.market.seriesTicker ?: return

        // Don't re-fetch if already loaded or in progress
        if (_uiState.value.trends.containsKey(ticker)) return
        if (trendJobs.containsKey(ticker)) return

        trendJobs[ticker] = viewModelScope.launch {
            try {
                val trend = searchService.trend(
                    marketTicker = ticker,
                    seriesTicker = seriesTicker,
                    window = TrendWindow.SEVEN_DAYS,
                )
                _uiState.update {
                    it.copy(trends = it.trends + (ticker to trend))
                }
            } catch (_: Exception) {
                // Silently fail — sparkline is optional
            } finally {
                trendJobs.remove(ticker)
            }
        }
    }

    fun retry() {
        loadMarkets()
    }
}
