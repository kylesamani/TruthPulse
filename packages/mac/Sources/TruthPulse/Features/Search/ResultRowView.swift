import SwiftUI

struct ResultRowView: View {
    let result: SearchResult
    let trend: MarketTrend?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.market.title.highlightAttributedString(ranges: result.titleHighlights))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.kalshiInk)
                        .lineLimit(2)

                    if let subtitle = secondaryLine {
                        Text(subtitle.highlightAttributedString(ranges: result.subtitleHighlights))
                            .font(.system(size: 12))
                            .foregroundStyle(Color.kalshiMuted)
                            .lineLimit(1)
                    }

                    if let volume = result.market.volume24h ?? result.market.volume {
                        Text("Volume \(volume.compactVolumeString)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.kalshiMuted.opacity(0.85))
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 4) {
                        Text(result.emphasizedOdds.map { "\($0)%" } ?? "--")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.kalshiInk)

                        Text(result.emphasizedOutcomeLabel)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.kalshiMint)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.kalshiMintSoft)
                            .clipShape(Capsule())
                    }

                    SparklineView(trend: trend, lineWidth: 2)
                        .frame(width: 80, height: 28)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.white : Color.kalshiPanel)
                    .shadow(color: isSelected ? Color.black.opacity(0.06) : .clear, radius: 10, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.kalshiMint.opacity(0.55) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var secondaryLine: String? {
        if let subtitle = result.market.subtitle, !subtitle.isEmpty {
            return subtitle
        }
        if let eventTitle = result.market.eventTitle, !eventTitle.isEmpty,
           eventTitle != result.market.title {
            return eventTitle
        }
        return [result.market.yesLabel, result.market.noLabel].compactMap { $0 }.joined(separator: " / ").nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
