import Foundation

public enum TrendWindow: String, CaseIterable, Identifiable, Sendable {
    case oneDay = "1D"
    case sevenDays = "7D"
    case thirtyDays = "30D"

    public var id: String { rawValue }

    public var title: String { rawValue }

    public var duration: TimeInterval {
        switch self {
        case .oneDay:
            60 * 60 * 24
        case .sevenDays:
            60 * 60 * 24 * 7
        case .thirtyDays:
            60 * 60 * 24 * 30
        }
    }

    /// Kalshi only accepts period_interval values of 1, 60, or 1440.
    public var intervalMinutes: Int {
        switch self {
        case .oneDay:
            1
        case .sevenDays:
            60
        case .thirtyDays:
            1_440
        }
    }
}

public struct TrendPoint: Hashable, Sendable {
    public let date: Date
    public let value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

public struct MarketTrend: Hashable, Sendable {
    public let marketTicker: String
    public let window: TrendWindow
    public let points: [TrendPoint]
    public let delta: Double?
    public let updatedAt: Date

    public init(marketTicker: String, window: TrendWindow, points: [TrendPoint], delta: Double?, updatedAt: Date) {
        self.marketTicker = marketTicker
        self.window = window
        self.points = points
        self.delta = delta
        self.updatedAt = updatedAt
    }
}
