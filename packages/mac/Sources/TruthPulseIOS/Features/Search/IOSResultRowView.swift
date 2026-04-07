import SwiftUI
import TruthPulseCore

struct IOSResultRowView: View {
    let result: SearchResult

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

                if let volume = result.market.volume24h ?? result.market.volume {
                    Text("Vol \(volume.compactVolumeString)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
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
            }
        }
        .padding(.vertical, 4)
        .frame(minHeight: 44)
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
}
