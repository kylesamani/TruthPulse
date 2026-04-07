import Foundation

public actor MarketCacheStore {
    private let cacheURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(appSupportDirectory: URL) {
        self.cacheURL = appSupportDirectory.appendingPathComponent("open-markets-cache.json")
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    /// Fast check — no file I/O beyond a stat call.
    nonisolated public func cacheFileExists() -> Bool {
        FileManager.default.fileExists(atPath: cacheURL.path)
    }

    public func savedAt() -> Date? {
        guard
            let data = try? Data(contentsOf: cacheURL),
            let payload = try? decoder.decode(CachedMarketsPayload.self, from: data)
        else {
            return nil
        }
        return payload.savedAt
    }

    public func loadMarkets() -> [MarketSummary] {
        guard
            let data = try? Data(contentsOf: cacheURL),
            let payload = try? decoder.decode(CachedMarketsPayload.self, from: data)
        else {
            return []
        }

        return payload.markets.filter { status in
            let normalized = status.status.lowercased()
            return normalized == "active" || normalized == "open"
        }
    }

    public func saveMarkets(_ markets: [MarketSummary]) {
        let payload = CachedMarketsPayload(savedAt: Date(), markets: markets)
        guard let data = try? encoder.encode(payload) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}

private struct CachedMarketsPayload: Codable {
    let savedAt: Date
    let markets: [MarketSummary]
}
