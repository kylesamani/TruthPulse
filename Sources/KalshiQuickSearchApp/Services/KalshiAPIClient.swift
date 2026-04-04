import Foundation

struct KalshiOpenEventsResponse: Decodable {
    let events: [KalshiEventDTO]
    let cursor: String?
}

struct KalshiEventDTO: Decodable {
    let eventTicker: String?
    let seriesTicker: String?
    let title: String?
    let subtitle: String?
    let category: String?
    let markets: [KalshiMarketDTO]?
    let productMetadata: [String: JSONValue]?
    let url: String?
    let slug: String?

    enum CodingKeys: String, CodingKey {
        case eventTicker = "event_ticker"
        case seriesTicker = "series_ticker"
        case title
        case subtitle = "sub_title"
        case category
        case markets
        case productMetadata = "product_metadata"
        case url
        case slug
    }
}

struct KalshiMarketDTO: Decodable {
    let ticker: String
    let title: String?
    let subtitle: String?
    let yesLabel: String?
    let noLabel: String?
    let status: String?
    let lastPrice: Double?
    let yesPrice: Double?
    let noPrice: Double?
    let volume: Double?
    let volume24h: Double?
    let openInterest: Double?
    let liquidity: Double?
    let updatedTime: Date?
    let openTime: Date?
    let closeTime: Date?
    let rulesPrimary: String?
    let rulesSecondary: String?
    let url: String?
    let slug: String?
    let result: String?
    let productMetadata: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case ticker
        case title
        case subtitle = "sub_title"
        case yesLabel = "yes_sub_title"
        case noLabel = "no_sub_title"
        case status
        case lastPrice = "last_price_dollars"
        case yesPrice = "yes_ask_dollars"
        case noPrice = "no_ask_dollars"
        case volume = "volume_fp"
        case volume24h = "volume_24h_fp"
        case openInterest = "open_interest_fp"
        case liquidity = "liquidity_dollars"
        case updatedTime = "updated_time"
        case openTime = "open_time"
        case closeTime = "close_time"
        case rulesPrimary = "rules_primary"
        case rulesSecondary = "rules_secondary"
        case url
        case slug
        case result
        case productMetadata = "product_metadata"
        case yesBid = "yes_bid_dollars"
        case noBid = "no_bid_dollars"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        ticker = try container.decode(String.self, forKey: .ticker)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        yesLabel = try container.decodeIfPresent(String.self, forKey: .yesLabel)
        noLabel = try container.decodeIfPresent(String.self, forKey: .noLabel)
        status = try container.decodeIfPresent(String.self, forKey: .status)

        let last = container.decodeFlexibleDouble(forKey: .lastPrice)
        let yesAsk = container.decodeFlexibleDouble(forKey: .yesPrice)
        let noAsk = container.decodeFlexibleDouble(forKey: .noPrice)
        let yesBid = container.decodeFlexibleDouble(forKey: .yesBid)
        let noBid = container.decodeFlexibleDouble(forKey: .noBid)

        lastPrice = last
        yesPrice = yesAsk ?? yesBid ?? last
        noPrice = noAsk ?? noBid ?? last.map { max(0, 1 - $0) }

        volume = container.decodeFlexibleDouble(forKey: .volume)
        volume24h = container.decodeFlexibleDouble(forKey: .volume24h)
        openInterest = container.decodeFlexibleDouble(forKey: .openInterest)
        liquidity = container.decodeFlexibleDouble(forKey: .liquidity)
        updatedTime = container.decodeFlexibleDate(forKey: .updatedTime)
        openTime = container.decodeFlexibleDate(forKey: .openTime)
        closeTime = container.decodeFlexibleDate(forKey: .closeTime)
        rulesPrimary = try container.decodeIfPresent(String.self, forKey: .rulesPrimary)
        rulesSecondary = try container.decodeIfPresent(String.self, forKey: .rulesSecondary)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        result = try container.decodeIfPresent(String.self, forKey: .result)
        productMetadata = try container.decodeIfPresent([String: JSONValue].self, forKey: .productMetadata)
    }
}

struct KalshiCandlestickResponse: Decodable {
    let ticker: String
    let candlesticks: [KalshiCandleDTO]
}

struct KalshiCandleDTO: Decodable {
    let endTs: Int64?
    let yesAskClose: Double?
    let yesBidClose: Double?
    let previousPrice: Double?

    enum CodingKeys: String, CodingKey {
        case endTs = "end_period_ts"
        case yesAsk = "yes_ask"
        case yesBid = "yes_bid"
        case price
    }

    private enum PriceKeys: String, CodingKey {
        case closeDollars = "close_dollars"
        case previousDollars = "previous_dollars"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        endTs = container.decodeFlexibleInt64(forKey: .endTs)

        if let askContainer = try? container.nestedContainer(keyedBy: PriceKeys.self, forKey: .yesAsk) {
            yesAskClose = askContainer.decodeFlexibleDouble(forKey: .closeDollars)
        } else {
            yesAskClose = nil
        }

        if let bidContainer = try? container.nestedContainer(keyedBy: PriceKeys.self, forKey: .yesBid) {
            yesBidClose = bidContainer.decodeFlexibleDouble(forKey: .closeDollars)
        } else {
            yesBidClose = nil
        }

        if let priceContainer = try? container.nestedContainer(keyedBy: PriceKeys.self, forKey: .price) {
            previousPrice = priceContainer.decodeFlexibleDouble(forKey: .previousDollars)
        } else {
            previousPrice = nil
        }
    }

    var bestPrice: Double? {
        yesAskClose ?? yesBidClose ?? previousPrice
    }
}

struct KalshiAPIClient: Sendable {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let baseURL = URL(string: "https://api.elections.kalshi.com/trade-api/v2")!

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: configuration)
        self.decoder = JSONDecoder()
    }

    func fetchOpenMarkets() async throws -> [MarketSummary] {
        var cursor: String?
        var allMarkets: [MarketSummary] = []

        repeat {
            var components = URLComponents(url: baseURL.appendingPathComponent("events"), resolvingAgainstBaseURL: false)!
            var queryItems = [
                URLQueryItem(name: "status", value: "open"),
                URLQueryItem(name: "limit", value: "200"),
                URLQueryItem(name: "with_nested_markets", value: "true")
            ]
            if let cursor {
                queryItems.append(URLQueryItem(name: "cursor", value: cursor))
            }
            components.queryItems = queryItems

            let response: KalshiOpenEventsResponse = try await get(url: components.url!)
            guard !response.events.isEmpty else { break }
            let markets = response.events.flatMap { event in
                (event.markets ?? [])
                    .filter { market in
                        let normalized = (market.status ?? "").lowercased()
                        return normalized == "active" || normalized == "open"
                    }
                    .map { $0.toDomain(event: event) }
            }
            allMarkets.append(contentsOf: markets)
            cursor = response.cursor
        } while cursor != nil && !cursor!.isEmpty

        return allMarkets
    }

    func fetchTrend(for marketTicker: String, seriesTicker: String, window: TrendWindow) async throws -> MarketTrend {
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-window.duration)
        let path = "series/\(seriesTicker)/markets/\(marketTicker)/candlesticks"
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "start_ts", value: String(Int64(startDate.timeIntervalSince1970))),
            URLQueryItem(name: "end_ts", value: String(Int64(endDate.timeIntervalSince1970))),
            URLQueryItem(name: "period_interval", value: String(window.intervalMinutes))
        ]

        let response: KalshiCandlestickResponse = try await get(url: components.url!)

        let points = response.candlesticks.compactMap { candle -> TrendPoint? in
            guard let timestamp = candle.endTs, let rawPrice = candle.bestPrice else { return nil }
            let normalizedPrice = rawPrice > 1 ? rawPrice : rawPrice * 100
            return TrendPoint(date: Date(timeIntervalSince1970: TimeInterval(timestamp)), value: normalizedPrice)
        }.sorted { $0.date < $1.date }

        let delta: Double?
        if let first = points.first?.value, let last = points.last?.value {
            delta = last - first
        } else {
            delta = nil
        }

        return MarketTrend(
            marketTicker: marketTicker,
            window: window,
            points: points,
            delta: delta,
            updatedAt: Date()
        )
    }

    private func get<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        return try decoder.decode(T.self, from: data)
    }
}

private extension KalshiMarketDTO {
    func toDomain(event: KalshiEventDTO) -> MarketSummary {
        let combinedMetadata = [event.productMetadata, productMetadata]
            .compactMap { $0 }
            .reduce(into: [String: JSONValue]()) { partial, next in
                partial.merge(next) { current, _ in current }
            }

        let imageURL = (combinedMetadata["image"]?.stringValue)
            .flatMap(URL.init(string:))
            ?? combinedMetadata.values.flatMap { $0.collectURLStrings() }
                .compactMap(URL.init(string:))
                .first(where: { $0.absoluteString.lowercased().contains("image") || $0.pathExtension.lowercased().matchesAny(of: ["png", "jpg", "jpeg", "webp"]) })

        let url = [self.url, event.url]
            .compactMap { $0 }
            .compactMap(URL.init(string:))
            .first

        return MarketSummary(
            ticker: ticker,
            eventTicker: event.eventTicker,
            seriesTicker: event.seriesTicker,
            title: title ?? event.title ?? ticker,
            subtitle: subtitle,
            yesLabel: yesLabel,
            noLabel: noLabel,
            eventTitle: event.title,
            eventSubtitle: event.subtitle,
            category: event.category,
            status: status ?? "active",
            lastPrice: normalizeUnitPrice(lastPrice),
            yesPrice: normalizeUnitPrice(yesPrice),
            noPrice: normalizeUnitPrice(noPrice),
            volume: volume,
            volume24h: volume24h,
            openInterest: openInterest,
            liquidity: liquidity,
            updatedAt: updatedTime,
            openTime: openTime,
            closeTime: closeTime,
            imageURL: imageURL,
            webURL: url
        )
    }

    private func normalizeUnitPrice(_ value: Double?) -> Double? {
        guard let value else { return nil }
        return value > 1 ? value / 100 : value
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleDouble(forKey key: Key) -> Double? {
        if let double = try? decodeIfPresent(Double.self, forKey: key) {
            return double
        }
        if let int = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(int)
        }
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return Double(string)
        }
        return nil
    }

    func decodeFlexibleInt64(forKey key: Key) -> Int64? {
        if let int = try? decodeIfPresent(Int64.self, forKey: key) {
            return int
        }
        if let int = try? decodeIfPresent(Int.self, forKey: key) {
            return Int64(int)
        }
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return Int64(string)
        }
        return nil
    }

    func decodeFlexibleDate(forKey key: Key) -> Date? {
        if let date = try? decodeIfPresent(Date.self, forKey: key) {
            return date
        }
        guard let string = (try? decodeIfPresent(String.self, forKey: key)) ?? nil else {
            return nil
        }
        return Date.parsedKalshiTimestamp(string)
    }
}

private extension Date {
    static func parsedKalshiTimestamp(_ string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) {
            return date
        }
        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        return basic.date(from: string)
    }
}

private extension String {
    func matchesAny(of extensions: [String]) -> Bool {
        extensions.contains(self)
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
