import Foundation
import TruthPulseCore

@MainActor
final class IOSAppState: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [SearchResult] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var hasCachedMarkets = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastSyncDate: Date?

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
            }
            await refreshMarkets()
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
            await spotlightIndexer.indexMarkets(markets)
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

    private func updateResults() async {
        await executeSearch(generation: queryGeneration)
    }

    private func executeSearch(generation: UInt64) async {
        let results = await service.search(query: query)
        guard generation == queryGeneration else { return }
        self.results = results
        if errorMessage != nil { errorMessage = nil }
    }
}
