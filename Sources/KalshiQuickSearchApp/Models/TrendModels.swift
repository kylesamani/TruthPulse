import Foundation

enum TrendWindow: String, CaseIterable, Identifiable, Sendable {
    case oneDay = "1D"
    case sevenDays = "7D"
    case thirtyDays = "30D"

    var id: String { rawValue }

    var title: String { rawValue }

    var duration: TimeInterval {
        switch self {
        case .oneDay:
            60 * 60 * 24
        case .sevenDays:
            60 * 60 * 24 * 7
        case .thirtyDays:
            60 * 60 * 24 * 30
        }
    }

    var intervalMinutes: Int {
        switch self {
        case .oneDay:
            60
        case .sevenDays:
            240
        case .thirtyDays:
            1_440
        }
    }
}

struct TrendPoint: Hashable, Sendable {
    let date: Date
    let value: Double
}

struct MarketTrend: Hashable, Sendable {
    let marketTicker: String
    let window: TrendWindow
    let points: [TrendPoint]
    let delta: Double?
    let updatedAt: Date
}
