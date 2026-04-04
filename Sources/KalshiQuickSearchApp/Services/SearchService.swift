import Foundation

actor SearchService {
    private let apiClient: KalshiAPIClient
    private let cacheStore: MarketCacheStore
    private let rankingPolicy = RankingPolicy()
    private var trendCache: [String: MarketTrend] = [:]
    private var lastRefresh: Date?
    private var markets: [MarketSummary] = []

    init(apiClient: KalshiAPIClient = KalshiAPIClient()) throws {
        let appSupport = try SearchService.makeAppSupportDirectory()
        self.apiClient = apiClient
        self.cacheStore = MarketCacheStore(appSupportDirectory: appSupport)
    }

    func bootstrapIfNeeded() async throws {
        if markets.isEmpty {
            markets = await cacheStore.loadMarkets()
        }
    }

    func hasLoadedMarkets() async -> Bool {
        if markets.isEmpty {
            markets = await cacheStore.loadMarkets()
        }
        return !markets.isEmpty
    }

    func refreshOpenMarkets(force: Bool = false) async throws {
        if !force, let lastRefresh, Date().timeIntervalSince(lastRefresh) < 45 {
            return
        }

        let markets = try await apiClient.fetchOpenMarkets()
        self.markets = markets
        await cacheStore.saveMarkets(markets)
        self.lastRefresh = Date()
    }

    func search(query: String, limit: Int = 30) async throws -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if markets.isEmpty {
            markets = await cacheStore.loadMarkets()
            if markets.isEmpty {
                try await refreshOpenMarkets(force: true)
            }
        }

        let normalizedQuery = trimmed.normalizedSearchText
        let tokens = normalizedQuery.searchTokens
        let candidates = markets
            .filter { market in
                Self.matches(query: normalizedQuery, tokens: tokens, market: market)
            }
            .map { market in
                IndexedSearchCandidate(market: market, baseRank: 0)
            }

        return Array(rankingPolicy.rank(query: query, candidates: candidates).prefix(limit))
    }

    func trend(for marketTicker: String, window: TrendWindow) async throws -> MarketTrend {
        let key = cacheKey(for: marketTicker, window: window)
        if let cached = trendCache[key], Date().timeIntervalSince(cached.updatedAt) < 300 {
            return cached
        }

        let trend = try await apiClient.fetchTrend(for: marketTicker, window: window)
        trendCache[key] = trend
        return trend
    }

    private func cacheKey(for marketTicker: String, window: TrendWindow) -> String {
        "\(marketTicker)::\(window.rawValue)"
    }

    static func makeAppSupportDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("KalshiQuickSearch", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func matches(query: String, tokens: [String], market: MarketSummary) -> Bool {
        let searchableFields = [
            market.title,
            market.subtitle ?? "",
            market.yesLabel ?? "",
            market.noLabel ?? "",
            market.eventTitle ?? "",
            market.eventSubtitle ?? "",
            market.description ?? "",
            market.category ?? "",
            market.ticker
        ]

        let haystack = searchableFields
            .joined(separator: " ")
            .normalizedSearchText

        if haystack.contains(query) {
            return true
        }

        return tokens.allSatisfy { token in
            haystack.contains(token)
        }
    }
}
