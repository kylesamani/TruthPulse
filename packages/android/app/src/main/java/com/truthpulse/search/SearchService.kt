package com.truthpulse.search

import android.content.Context
import com.truthpulse.data.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Core search service: maintains market index, search, and trend caching.
 * Mirrors the Swift actor-based SearchService.
 */
class SearchService(context: Context) {

    private val apiClient = KalshiApiClient()
    private val cacheStore = MarketCacheStore(context)
    val synonymTable = SynonymTable(context)
    private val rankingPolicy = RankingPolicy()

    private val mutex = Mutex()
    private var markets: List<MarketSummary> = emptyList()
    private var index: List<IndexedMarket> = emptyList()
    private var lastRefreshMillis: Long? = null
    private val trendCache = mutableMapOf<String, MarketTrend>()

    val hasCacheOnDisk: Boolean get() = cacheStore.cacheFileExists()

    val marketCount: Int get() = markets.size

    suspend fun bootstrapIfNeeded() {
        mutex.withLock {
            if (markets.isEmpty()) {
                val loaded = cacheStore.loadMarkets()
                setMarketsInternal(loaded)
            }
        }
    }

    suspend fun hasLoadedMarkets(): Boolean {
        mutex.withLock {
            if (markets.isEmpty()) {
                val loaded = cacheStore.loadMarkets()
                setMarketsInternal(loaded)
            }
            return markets.isNotEmpty()
        }
    }

    fun lastCacheDateMillis(): Long? = cacheStore.savedAtMillis()

    /**
     * Refresh markets from the API with a 45-second debounce.
     */
    suspend fun refreshOpenMarkets(force: Boolean = false) {
        mutex.withLock {
            val now = System.currentTimeMillis()
            if (!force) {
                lastRefreshMillis?.let { last ->
                    if (now - last < 45_000) return
                }
            }
        }

        val fetched = apiClient.fetchOpenMarkets()

        mutex.withLock {
            setMarketsInternal(fetched)
            lastRefreshMillis = System.currentTimeMillis()
        }

        cacheStore.saveMarkets(fetched)
    }

    private fun setMarketsInternal(newMarkets: List<MarketSummary>) {
        markets = newMarkets
        index = newMarkets.map { market ->
            val fields = listOf(
                market.title,
                market.subtitle ?: "",
                market.yesLabel ?: "",
                market.noLabel ?: "",
                market.eventTitle ?: "",
                market.eventSubtitle ?: "",
                market.category ?: "",
                market.ticker,
            )
            val haystack = fields.joinToString(" ").normalizedSearchText()
            IndexedMarket(market = market, haystack = haystack)
        }
    }

    /**
     * Search markets using two-pass filtering with synonym expansion.
     */
    fun search(query: String, limit: Int = 30): List<SearchResult> {
        val trimmed = query.trim()
        if (trimmed.isEmpty()) return emptyList()

        val normalizedQuery = trimmed.normalizedSearchText()
        val tokens = normalizedQuery.searchTokens()
        val expandedTokens = synonymTable.expandTokens(tokens)

        val candidates = index
            .filter { entry ->
                // Pass 1: phrase match
                if (entry.haystack.contains(normalizedQuery)) return@filter true
                // Pass 2: all original tokens
                if (tokens.all { entry.haystack.contains(it) }) return@filter true
                // Pass 3: expanded tokens (synonym expansion)
                if (expandedTokens.size > tokens.size) {
                    return@filter expandedTokens.all { entry.haystack.contains(it) }
                }
                false
            }
            .map { IndexedSearchCandidate(market = it.market, baseRank = 0.0) }

        return rankingPolicy.rank(query, candidates).take(limit)
    }

    /**
     * Fetch trend data with 5-minute cache.
     */
    suspend fun trend(marketTicker: String, seriesTicker: String, window: TrendWindow): MarketTrend {
        val key = "$marketTicker::${window.name}"
        val now = System.currentTimeMillis()

        mutex.withLock {
            trendCache[key]?.let { cached ->
                if (now - cached.updatedAtMillis < 300_000) return cached
            }
        }

        val trend = apiClient.fetchTrend(marketTicker, seriesTicker, window)

        mutex.withLock {
            trendCache[key] = trend
        }

        return trend
    }

    /** All currently loaded markets (for AppSearch indexing). */
    fun allMarkets(): List<MarketSummary> = markets
}

private data class IndexedMarket(
    val market: MarketSummary,
    val haystack: String,
)
