#if canImport(UIKit)
import UIKit
#endif
import Foundation
import CoreSpotlight
import TruthPulseCore

enum IOSSyncInterval: Int, CaseIterable {
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

    static func load() -> IOSSyncInterval {
        let raw = UserDefaults.standard.integer(forKey: key)
        return IOSSyncInterval(rawValue: raw) ?? .oneHour
    }

    static func save(_ interval: IOSSyncInterval) {
        UserDefaults.standard.set(interval.rawValue, forKey: key)
    }
}

@MainActor
final class IOSAppState: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [SearchResult] = []
    @Published var selectedWindow: TrendWindow = .sevenDays
    @Published private(set) var trends: [String: MarketTrend] = [:]
    @Published private(set) var isRefreshing = false
    @Published private(set) var hasCachedMarkets = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastSyncDate: Date?
    @Published var syncInterval: IOSSyncInterval = IOSSyncInterval.load() {
        didSet { IOSSyncInterval.save(syncInterval) }
    }

    private let service: SearchService
    private let spotlightIndexer = SpotlightIndexer()
    private var searchTask: Task<Void, Never>?
    private var queryGeneration: UInt64 = 0

    init() {
        do {
            self.service = try SearchService()
            self.hasCachedMarkets = service.hasCacheOnDisk
        } catch {
            fatalError("Failed to initialize SearchService: \(error)")
        }
    }

    func onAppear() {
        Task {
            try? await service.bootstrapIfNeeded()
            let cached = await service.hasLoadedMarkets()
            hasCachedMarkets = cached
            if cached {
                lastSyncDate = await service.lastCacheDate()
                let markets = await service.allMarkets
                if !markets.isEmpty {
                    spotlightIndexer.indexMarkets(markets)
                }
            }

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
            return
        }

        guard trimmed.count >= 4 else { return }

        let gen = queryGeneration
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            await self?.executeSearch(generation: gen)
        }
    }

    func handleSpotlightContinuation(_ userActivity: NSUserActivity) {
        guard userActivity.activityType == CSSearchableItemActionType,
              let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              let url = URL(string: identifier) else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }

    func loadTrendIfNeeded(for market: MarketSummary) {
        guard let seriesTicker = market.seriesTicker else { return }
        let key = "\(market.ticker)::\(selectedWindow.rawValue)"
        if trends[key] != nil { return }

        Task {
            do {
                let trend = try await service.trend(for: market.ticker, seriesTicker: seriesTicker, window: selectedWindow)
                trends[key] = trend
            } catch {
                // Sparkline fetch failure is non-critical
            }
        }
    }

    func trend(for market: MarketSummary) -> MarketTrend? {
        let key = "\(market.ticker)::\(selectedWindow.rawValue)"
        return trends[key]
    }

    private func updateResults() async {
        await executeSearch(generation: queryGeneration)
    }

    private func executeSearch(generation: UInt64) async {
        let results = await service.search(query: query)
        guard generation == queryGeneration else { return }
        self.results = results
        if errorMessage != nil { errorMessage = nil }
        await prefetchVisibleTrends()
    }

    private func prefetchVisibleTrends() async {
        let top = Array(results.prefix(6))
        await withTaskGroup(of: Void.self) { group in
            for result in top {
                let ticker = result.market.ticker
                let seriesTicker = result.market.seriesTicker
                group.addTask { [weak self] in
                    guard let seriesTicker else { return }
                    let key = "\(ticker)::\(await self?.selectedWindow.rawValue ?? "")"
                    if await self?.trends[key] != nil { return }
                    do {
                        let trend = try await self?.service.trend(for: ticker, seriesTicker: seriesTicker, window: self?.selectedWindow ?? .sevenDays)
                        if let trend {
                            await MainActor.run { self?.trends[key] = trend }
                        }
                    } catch {}
                }
            }
        }
    }
}
