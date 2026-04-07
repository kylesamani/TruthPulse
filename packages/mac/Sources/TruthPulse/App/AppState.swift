import AppKit
import Combine
import Foundation
import TruthPulseCore

enum SyncInterval: Int, CaseIterable {
    case oneMinute = 60
    case oneHour = 3600
    case threeHours = 10800
    case sixHours = 21600
    case twelveHours = 43200
    case twentyFourHours = 86400

    var label: String {
        switch self {
        case .oneMinute: return "1 minute"
        case .oneHour: return "1 hour"
        case .threeHours: return "3 hours"
        case .sixHours: return "6 hours"
        case .twelveHours: return "12 hours"
        case .twentyFourHours: return "24 hours"
        }
    }

    private static let key = "syncIntervalSeconds"

    static func load() -> SyncInterval {
        let raw = UserDefaults.standard.integer(forKey: key)
        return SyncInterval(rawValue: raw) ?? .oneMinute
    }

    static func save(_ interval: SyncInterval) {
        UserDefaults.standard.set(interval.rawValue, forKey: key)
    }
}

struct SearchPanelMetrics: Equatable {
    let width: CGFloat
    let height: CGFloat
    let listWidth: CGFloat
    let detailWidth: CGFloat
    let showDetail: Bool
    let visibleRowCount: Int
}

@MainActor
final class AppState: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [SearchResult] = []
    @Published var selectedResultID: SearchResult.ID?
    @Published var selectedWindow: TrendWindow = .sevenDays
    @Published private(set) var trends: [String: MarketTrend] = [:]
    @Published private(set) var isRefreshing = false
    @Published private(set) var hasCachedMarkets = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var spotlightIndexedCount: Int = 0
    @Published private(set) var spotlightLastIndexed: Date?
    @Published var syncInterval: SyncInterval = SyncInterval.load()

    private let service: SearchService
    private let spotlightIndexer = SpotlightIndexer()
    private var refreshTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var queryGeneration: UInt64 = 0

    init(service: SearchService) {
        self.service = service
        self.hasCachedMarkets = service.hasCacheOnDisk

        NotificationCenter.default.addObserver(forName: .truthPulseSpotlightIndexed, object: nil, queue: .main) { [weak self] notification in
            guard let self, let count = notification.userInfo?["count"] as? Int else { return }
            Task { @MainActor in
                self.spotlightIndexedCount = count
                self.spotlightLastIndexed = Date()
            }
        }
    }

    var selectedResult: SearchResult? {
        if let selectedResultID, let selected = results.first(where: { $0.id == selectedResultID }) {
            return selected
        }
        return results.first
    }

    var panelMetrics: SearchPanelMetrics {
        let hasQuery = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let resultCount = results.count
        let panelWidth: CGFloat = 520

        if !hasQuery || resultCount == 0 {
            return SearchPanelMetrics(
                width: panelWidth,
                height: 120,
                listWidth: panelWidth - 28,
                detailWidth: 0,
                showDetail: false,
                visibleRowCount: 0
            )
        }

        let visibleRows = min(max(resultCount, 1), 4)
        let rowHeight: CGFloat = 96
        let headerHeight: CGFloat = 140
        let footerPadding: CGFloat = 28
        let listHeight = CGFloat(visibleRows) * rowHeight
        let computedHeight = headerHeight + listHeight + footerPadding

        return SearchPanelMetrics(
            width: panelWidth,
            height: computedHeight,
            listWidth: panelWidth - 28,
            detailWidth: 0,
            showDetail: false,
            visibleRowCount: visibleRows
        )
    }

    /// Called each time the popover opens.
    func onPopoverOpen() {
        Task {
            // Load cache first so search is available immediately
            try? await service.bootstrapIfNeeded()
            let cached = await service.hasLoadedMarkets()
            hasCachedMarkets = cached
            if cached {
                lastSyncDate = await service.lastCacheDate()
                // Index cached markets into Spotlight immediately
                let markets = await service.allMarkets
                if !markets.isEmpty {
                    spotlightIndexer.indexMarkets(markets)
                }
            }

            // Only refresh from Kalshi if enough time has passed since last sync
            let needsRefresh: Bool
            if let lastSync = lastSyncDate {
                needsRefresh = Date().timeIntervalSince(lastSync) > Double(syncInterval.rawValue)
            } else {
                needsRefresh = true
            }

            if needsRefresh {
                await refreshMarkets()
            }
        }
    }

    func refreshMarkets() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            try await service.refreshOpenMarkets(force: true)
            errorMessage = nil
            lastSyncDate = Date()
            hasCachedMarkets = true
            await updateResults()

            // Re-index Spotlight after successful refresh (fire-and-forget,
            // completion arrives via NotificationCenter)
            let markets = await service.allMarkets
            spotlightIndexer.indexMarkets(markets)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setQuery(_ newValue: String) {
        query = newValue
        queryGeneration &+= 1
        searchTask?.cancel()

        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            results = []
            selectedResultID = nil
            return
        }

        // Auto-search only with 4+ characters
        guard trimmed.count >= 4 else { return }

        let capturedGeneration = queryGeneration
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            await self?.executeSearch(generation: capturedGeneration)
        }
    }

    func updateResults() async {
        let currentGeneration = queryGeneration
        await executeSearch(generation: currentGeneration)
    }

    private func executeSearch(generation: UInt64) async {
        let results = await service.search(query: query)
        guard generation == queryGeneration else { return }
        self.results = results
        if let selectedResultID, results.contains(where: { $0.id == selectedResultID }) {
            self.selectedResultID = selectedResultID
        } else {
            self.selectedResultID = results.first?.id
        }
        if errorMessage != nil {
            errorMessage = nil
        }
        await prefetchVisibleTrends()
    }

    func moveSelection(offset: Int) {
        guard !results.isEmpty else { return }
        let currentIndex = results.firstIndex(where: { $0.id == selectedResultID }) ?? 0
        let nextIndex = min(max(currentIndex + offset, 0), results.count - 1)
        let market = results[nextIndex].market
        selectedResultID = results[nextIndex].id
        Task { await loadTrendIfNeeded(for: market.ticker, seriesTicker: market.seriesTicker) }
    }

    func select(_ result: SearchResult) {
        selectedResultID = result.id
        Task { await loadTrendIfNeeded(for: result.market.ticker, seriesTicker: result.market.seriesTicker) }
    }

    func openSelectedMarket() {
        guard let selectedResult else { return }
        NSWorkspace.shared.open(selectedResult.market.resolvedWebURL)
    }

    func loadSelectedTrend() {
        guard let selectedResult else { return }
        Task { await loadTrendIfNeeded(for: selectedResult.market.ticker, seriesTicker: selectedResult.market.seriesTicker, force: true) }
    }

    private func prefetchVisibleTrends() async {
        let top = Array(results.prefix(6))
        await withTaskGroup(of: Void.self) { group in
            for result in top {
                let ticker = result.market.ticker
                let seriesTicker = result.market.seriesTicker
                group.addTask { [weak self] in
                    await self?.loadTrendIfNeeded(for: ticker, seriesTicker: seriesTicker)
                }
            }
        }
    }

    private func loadTrendIfNeeded(for marketTicker: String, seriesTicker: String?, force: Bool = false) async {
        guard let seriesTicker else { return }
        if !force, trends["\(marketTicker)::\(selectedWindow.rawValue)"] != nil {
            return
        }

        do {
            let trend = try await service.trend(for: marketTicker, seriesTicker: seriesTicker, window: selectedWindow)
            trends["\(marketTicker)::\(selectedWindow.rawValue)"] = trend
        } catch {
            // Keep the UI fast and quiet if a sparkline fetch fails.
        }
    }
}
