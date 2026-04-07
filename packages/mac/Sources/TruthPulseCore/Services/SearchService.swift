import Foundation

/// Pre-computed search index entry for a single market.
private struct IndexedMarket: Sendable {
    let market: MarketSummary
    let haystack: String // pre-normalized, joined searchable text
}

public actor SearchService {
    private let apiClient: KalshiAPIClient
    private let cacheStore: MarketCacheStore
    private let rankingPolicy = RankingPolicy()
    private let synonymTable = SynonymTable()
    private var trendCache: [String: MarketTrend] = [:]
    private var lastRefresh: Date?
    private var markets: [MarketSummary] = []
    private var index: [IndexedMarket] = []

    /// Synchronous check — no actor hop needed. Safe because it only does a file stat.
    nonisolated public let hasCacheOnDisk: Bool

    public init(apiClient: KalshiAPIClient = KalshiAPIClient()) throws {
        let appSupport = try SearchService.makeAppSupportDirectory()
        self.apiClient = apiClient
        self.cacheStore = MarketCacheStore(appSupportDirectory: appSupport)
        self.hasCacheOnDisk = cacheStore.cacheFileExists()
    }

    public func bootstrapIfNeeded() async throws {
        if markets.isEmpty {
            let loaded = await cacheStore.loadMarkets()
            setMarkets(loaded)
        }
    }

    public func hasLoadedMarkets() async -> Bool {
        if markets.isEmpty {
            let loaded = await cacheStore.loadMarkets()
            setMarkets(loaded)
        }
        return !markets.isEmpty
    }

    public func lastCacheDate() async -> Date? {
        await cacheStore.savedAt()
    }

    public func refreshOpenMarkets(force: Bool = false) async throws {
        if !force, let lastRefresh, Date().timeIntervalSince(lastRefresh) < 45 {
            return
        }

        let fetched = try await apiClient.fetchOpenMarkets()
        setMarkets(fetched)
        await cacheStore.saveMarkets(fetched)
        self.lastRefresh = Date()
    }

    private func setMarkets(_ newMarkets: [MarketSummary]) {
        markets = newMarkets
        index = newMarkets.map { market in
            let fields = [
                market.title,
                market.subtitle ?? "",
                market.yesLabel ?? "",
                market.noLabel ?? "",
                market.eventTitle ?? "",
                market.eventSubtitle ?? "",
                market.category ?? "",
                market.ticker
            ]
            let haystack = fields.joined(separator: " ").normalizedSearchText
            return IndexedMarket(market: market, haystack: haystack)
        }
    }

    /// All currently loaded markets (for Spotlight indexing).
    public var allMarkets: [MarketSummary] { markets }

    public func search(query: String, limit: Int = 30) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let normalizedQuery = trimmed.normalizedSearchText
        let tokens = normalizedQuery.searchTokens
        let expandedTokens = synonymTable.expandTokens(tokens)

        let candidates = index
            .filter { entry in
                // Match on original query phrase
                if entry.haystack.contains(normalizedQuery) { return true }
                // Match if all original tokens present
                if tokens.allSatisfy({ entry.haystack.contains($0) }) { return true }
                // Match if all expanded tokens (with synonyms) present
                if expandedTokens.count > tokens.count {
                    return expandedTokens.allSatisfy { entry.haystack.contains($0) }
                }
                return false
            }
            .map { IndexedSearchCandidate(market: $0.market, baseRank: 0) }

        return Array(rankingPolicy.rank(query: query, candidates: candidates).prefix(limit))
    }

    public func trend(for marketTicker: String, seriesTicker: String, window: TrendWindow) async throws -> MarketTrend {
        let key = cacheKey(for: marketTicker, window: window)
        if let cached = trendCache[key], Date().timeIntervalSince(cached.updatedAt) < 300 {
            return cached
        }

        let trend = try await apiClient.fetchTrend(for: marketTicker, seriesTicker: seriesTicker, window: window)
        trendCache[key] = trend
        return trend
    }

    private func cacheKey(for marketTicker: String, window: TrendWindow) -> String {
        "\(marketTicker)::\(window.rawValue)"
    }

    public static func makeAppSupportDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("TruthPulse", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

}
