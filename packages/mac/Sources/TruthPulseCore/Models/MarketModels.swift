import Foundation

public enum MarketOutcomeSide: String, Codable, Sendable {
    case yes
    case no
}

public enum MatchField: String, Codable, Sendable {
    case title
    case subtitle
    case outcome
    case eventTitle
    case description
    case category
    case none
}

public struct TextHighlightRange: Hashable, Codable, Sendable {
    public let start: Int
    public let length: Int

    public init(start: Int, length: Int) {
        self.start = start
        self.length = length
    }
}

public struct MarketSummary: Identifiable, Hashable, Codable, Sendable {
    public let ticker: String
    public let eventTicker: String?
    public let seriesTicker: String?
    public let title: String
    public let subtitle: String?
    public let yesLabel: String?
    public let noLabel: String?
    public let eventTitle: String?
    public let eventSubtitle: String?
    public let category: String?
    public let status: String
    public let lastPrice: Double?
    public let yesPrice: Double?
    public let noPrice: Double?
    public let volume: Double?
    public let volume24h: Double?
    public let openInterest: Double?
    public let liquidity: Double?
    public let updatedAt: Date?
    public let openTime: Date?
    public let closeTime: Date?
    public let imageURL: URL?
    public let webURL: URL?

    public var id: String { ticker }

    public init(
        ticker: String,
        eventTicker: String?,
        seriesTicker: String?,
        title: String,
        subtitle: String?,
        yesLabel: String?,
        noLabel: String?,
        eventTitle: String?,
        eventSubtitle: String?,
        category: String?,
        status: String,
        lastPrice: Double?,
        yesPrice: Double?,
        noPrice: Double?,
        volume: Double?,
        volume24h: Double?,
        openInterest: Double?,
        liquidity: Double?,
        updatedAt: Date?,
        openTime: Date?,
        closeTime: Date?,
        imageURL: URL?,
        webURL: URL?
    ) {
        self.ticker = ticker
        self.eventTicker = eventTicker
        self.seriesTicker = seriesTicker
        self.title = title
        self.subtitle = subtitle
        self.yesLabel = yesLabel
        self.noLabel = noLabel
        self.eventTitle = eventTitle
        self.eventSubtitle = eventSubtitle
        self.category = category
        self.status = status
        self.lastPrice = lastPrice
        self.yesPrice = yesPrice
        self.noPrice = noPrice
        self.volume = volume
        self.volume24h = volume24h
        self.openInterest = openInterest
        self.liquidity = liquidity
        self.updatedAt = updatedAt
        self.openTime = openTime
        self.closeTime = closeTime
        self.imageURL = imageURL
        self.webURL = webURL
    }

    /// URL to the event overview page (chart, description, all contracts).
    public var resolvedWebURL: URL {
        if let seriesTicker {
            let series = seriesTicker.lowercased()
            if let url = URL(string: "https://kalshi.com/markets/\(series)") {
                return url
            }
        }

        if let webURL {
            return webURL
        }

        let searchTerm = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ticker
        return URL(string: "https://kalshi.com/browse?query=\(searchTerm)")
            ?? URL(string: "https://kalshi.com")!
    }

    /// URL to the specific contract page — more likely to deep-link into the Kalshi app.
    public var deepLinkURL: URL {
        if let seriesTicker, let eventTicker {
            let series = seriesTicker.lowercased()
            let event = eventTicker.lowercased()
            if let url = URL(string: "https://kalshi.com/markets/\(series)/m/\(event)") {
                return url
            }
        }
        return resolvedWebURL
    }

    public var displayOdds: Int? {
        let price = yesPrice ?? lastPrice
        guard let price else { return nil }
        return Int((price * 100).rounded())
    }

    public var volumeSignal: Double {
        max(volume24h ?? 0, volume ?? 0)
    }
}

public struct SearchResult: Identifiable, Hashable, Sendable {
    public let market: MarketSummary
    public let score: Double
    public let matchedField: MatchField
    public let matchedOutcome: MarketOutcomeSide?
    public let titleHighlights: [TextHighlightRange]
    public let subtitleHighlights: [TextHighlightRange]
    public let outcomeHighlights: [TextHighlightRange]

    public var id: String { market.id }

    public init(
        market: MarketSummary,
        score: Double,
        matchedField: MatchField,
        matchedOutcome: MarketOutcomeSide?,
        titleHighlights: [TextHighlightRange],
        subtitleHighlights: [TextHighlightRange],
        outcomeHighlights: [TextHighlightRange]
    ) {
        self.market = market
        self.score = score
        self.matchedField = matchedField
        self.matchedOutcome = matchedOutcome
        self.titleHighlights = titleHighlights
        self.subtitleHighlights = subtitleHighlights
        self.outcomeHighlights = outcomeHighlights
    }

    public var emphasizedOdds: Int? {
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

    public var emphasizedOutcomeLabel: String {
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
