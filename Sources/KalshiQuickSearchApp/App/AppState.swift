import AppKit
import Combine
import Foundation

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
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastRefreshDate: Date?

    private let service: SearchService
    private var pollingTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?

    init(service: SearchService) {
        self.service = service
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
        let showDetail = resultCount > 0

        if !hasQuery || resultCount == 0 {
            let compactHeight: CGFloat = errorMessage == nil ? 212 : 236
            return SearchPanelMetrics(
                width: 452,
                height: compactHeight,
                listWidth: 420,
                detailWidth: 0,
                showDetail: false,
                visibleRowCount: 0
            )
        }

        let visibleRows = min(max(resultCount, 1), 5)
        let rowHeight: CGFloat = 84
        let headerHeight: CGFloat = 114
        let footerPadding: CGFloat = 24
        let listHeight = CGFloat(visibleRows) * rowHeight
        let computedHeight = min(max(headerHeight + listHeight + footerPadding, 266), 556)

        return SearchPanelMetrics(
            width: showDetail ? 748 : 468,
            height: computedHeight,
            listWidth: showDetail ? 458 : 436,
            detailWidth: showDetail ? 248 : 0,
            showDetail: showDetail,
            visibleRowCount: visibleRows
        )
    }

    func start() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            guard let self else { return }
            await self.performInitialLoad()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                await self.refreshMarkets()
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        searchTask?.cancel()
    }

    func performInitialLoad() async {
        await refreshMarkets(force: true)
    }

    func refreshMarkets(force: Bool = false) async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            try await service.bootstrapIfNeeded()
            if await service.hasLoadedMarkets() {
                await updateResults()
            }
            try await service.refreshOpenMarkets(force: force)
            errorMessage = nil
            lastRefreshDate = Date()
            await updateResults()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setQuery(_ newValue: String) {
        query = newValue
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            await self?.updateResults()
        }
    }

    func updateResults() async {
        do {
            let results = try await service.search(query: query)
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
        } catch {
            self.results = []
            self.selectedResultID = nil
            self.errorMessage = error.localizedDescription
        }
    }

    func moveSelection(offset: Int) {
        guard !results.isEmpty else { return }
        let currentIndex = results.firstIndex(where: { $0.id == selectedResultID }) ?? 0
        let nextIndex = min(max(currentIndex + offset, 0), results.count - 1)
        selectedResultID = results[nextIndex].id
        Task { await loadTrendIfNeeded(for: results[nextIndex].market.ticker) }
    }

    func select(_ result: SearchResult) {
        selectedResultID = result.id
        Task { await loadTrendIfNeeded(for: result.market.ticker) }
    }

    func openSelectedMarket() {
        guard let selectedResult else { return }
        NSWorkspace.shared.open(selectedResult.market.resolvedWebURL)
    }

    func refreshNow() {
        Task {
            await refreshMarkets(force: true)
        }
    }

    func loadSelectedTrend() {
        guard let selectedResult else { return }
        Task { await loadTrendIfNeeded(for: selectedResult.market.ticker, force: true) }
    }

    private func prefetchVisibleTrends() async {
        let top = Array(results.prefix(6))
        await withTaskGroup(of: Void.self) { group in
            for result in top {
                let ticker = result.market.ticker
                group.addTask { [weak self] in
                    await self?.loadTrendIfNeeded(for: ticker)
                }
            }
        }
    }

    private func loadTrendIfNeeded(for marketTicker: String, force: Bool = false) async {
        if !force, trends["\(marketTicker)::\(selectedWindow.rawValue)"] != nil {
            return
        }

        do {
            let trend = try await service.trend(for: marketTicker, window: selectedWindow)
            trends["\(marketTicker)::\(selectedWindow.rawValue)"] = trend
        } catch {
            // Keep the UI fast and quiet if a sparkline fetch fails.
        }
    }
}
