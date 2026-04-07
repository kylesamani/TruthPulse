import SwiftUI
import TruthPulseCore

struct IOSResultRowView: View {
    let result: SearchResult
    let trend: MarketTrend?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.market.title.highlightAttributedString(ranges: result.titleHighlights))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)

                if let subtitle = secondaryLine {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    if let volume = result.market.volume24h ?? result.market.volume {
                        Text("Vol \(volume.compactVolumeString)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tertiary)
                    }

                    if let trend, let delta = trend.delta {
                        Text(deltaText(delta))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(delta >= 0 ? Color.truthPulseMint : .red)
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text(result.emphasizedOdds.map { "\($0)%" } ?? "--")
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.primary)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)

                Text(result.emphasizedOutcomeLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.truthPulseMint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.truthPulseMintSoft)
                    .clipShape(Capsule())

                if let trend, trend.points.count > 1 {
                    IOSSparklineView(trend: trend)
                        .frame(width: 60, height: 24)
                }
            }
        }
        .padding(.vertical, 4)
        .frame(minHeight: 48)
    }

    private var secondaryLine: String? {
        if let subtitle = result.market.subtitle, !subtitle.isEmpty {
            return subtitle
        }
        if let eventTitle = result.market.eventTitle, !eventTitle.isEmpty,
           eventTitle != result.market.title {
            return eventTitle
        }
        let combined = [result.market.yesLabel, result.market.noLabel].compactMap { $0 }.joined(separator: " / ")
        return combined.isEmpty ? nil : combined
    }

    private func deltaText(_ delta: Double) -> String {
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(Int(delta)) pts"
    }
}
