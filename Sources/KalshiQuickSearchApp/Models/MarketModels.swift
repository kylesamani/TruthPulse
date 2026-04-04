import Foundation

enum MarketOutcomeSide: String, Codable, Sendable {
    case yes
    case no
}

enum MatchField: String, Codable, Sendable {
    case title
    case subtitle
    case outcome
    case eventTitle
    case description
    case category
    case none
}

struct TextHighlightRange: Hashable, Codable, Sendable {
    let start: Int
    let length: Int
}

struct MarketSummary: Identifiable, Hashable, Codable, Sendable {
    let ticker: String
    let eventTicker: String?
    let seriesTicker: String?
    let title: String
    let subtitle: String?
    let yesLabel: String?
    let noLabel: String?
    let eventTitle: String?
    let eventSubtitle: String?
    let description: String?
    let category: String?
    let status: String
    let lastPrice: Double?
    let yesPrice: Double?
    let noPrice: Double?
    let volume: Double?
    let volume24h: Double?
    let openInterest: Double?
    let liquidity: Double?
    let updatedAt: Date?
    let openTime: Date?
    let closeTime: Date?
    let imageURL: URL?
    let webURL: URL?

    var id: String { ticker }

    var resolvedWebURL: URL {
        if let webURL {
            return webURL
        }

        if let eventTicker {
            let encodedEvent = eventTicker.lowercased()
            let encodedMarket = ticker.lowercased()
            if let url = URL(string: "https://kalshi.com/markets/\(encodedEvent)/\(encodedMarket)") {
                return url
            }
        }

        if let url = URL(string: "https://kalshi.com/browse?query=\(ticker.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ticker)") {
            return url
        }

        return URL(string: "https://kalshi.com")!
    }

    var displayOdds: Int? {
        let price = yesPrice ?? lastPrice
        guard let price else { return nil }
        return Int((price * 100).rounded())
    }

    var volumeSignal: Double {
        max(volume24h ?? 0, volume ?? 0)
    }
}

struct SearchResult: Identifiable, Hashable, Sendable {
    let market: MarketSummary
    let score: Double
    let matchedField: MatchField
    let matchedOutcome: MarketOutcomeSide?
    let titleHighlights: [TextHighlightRange]
    let subtitleHighlights: [TextHighlightRange]
    let outcomeHighlights: [TextHighlightRange]

    var id: String { market.id }

    var emphasizedOdds: Int? {
        switch matchedOutcome {
        case .yes:
            guard let value = market.yesPrice else { return market.displayOdds }
            return Int((value * 100).rounded())
        case .no:
            guard let value = market.noPrice else { return market.displayOdds }
            return Int((value * 100).rounded())
        case .none:
            return market.displayOdds
        }
    }

    var emphasizedOutcomeLabel: String {
        switch matchedOutcome {
        case .yes:
            return market.yesLabel ?? "YES"
        case .no:
            return market.noLabel ?? "NO"
        case .none:
            return "YES"
        }
    }
}
