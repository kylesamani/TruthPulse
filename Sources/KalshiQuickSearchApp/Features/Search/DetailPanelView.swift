import SwiftUI

struct DetailPanelView: View {
    let result: SearchResult?
    let trend: MarketTrend?
    @Binding var selectedWindow: TrendWindow
    let onWindowChanged: () -> Void
    let onOpenInBrowser: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let result {
                HStack(alignment: .top, spacing: 14) {
                    ZStack(alignment: .bottomTrailing) {
                        CachedAsyncImage(url: result.market.imageURL) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.kalshiMintSoft)
                                .overlay(
                                    Image(systemName: "globe.americas")
                                        .font(.system(size: 28))
                                        .foregroundStyle(Color.kalshiMint)
                                )
                        }
                        .frame(width: 58, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                        TruthPulseMarkView(size: 28, lineWidth: 2.5)
                            .offset(x: 6, y: 6)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.market.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.kalshiInk)
                            .lineLimit(3)

                        if let eventTitle = result.market.eventTitle {
                            Text(eventTitle)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.kalshiMuted)
                                .lineLimit(2)
                        }

                        HStack(spacing: 8) {
                            Label(result.emphasizedOdds.map { "\($0)% \(result.emphasizedOutcomeLabel)" } ?? "--", systemImage: "chart.bar.fill")
                            if let volume = result.market.volume24h ?? result.market.volume {
                                Text("Vol \(volume.compactVolumeString)")
                            }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.kalshiMint)
                    }
                }

                Picker("Trend Window", selection: $selectedWindow) {
                    ForEach(TrendWindow.allCases) { window in
                        Text(window.title).tag(window)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedWindow) { _, _ in
                    onWindowChanged()
                }

                SparklineView(trend: trend, lineWidth: 3)
                    .frame(height: 110)

                if let delta = trend?.delta {
                    Text(delta >= 0 ? "Up \(Int(delta.rounded())) pts in \(selectedWindow.title)" : "Down \(Int(abs(delta).rounded())) pts in \(selectedWindow.title)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(delta >= 0 ? Color.kalshiMint : Color.red.opacity(0.85))
                }

                if let description = result.market.description {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.kalshiMuted)
                        .lineSpacing(3)
                        .lineLimit(4)
                } else {
                    Text("Keyboard-first lookup for live markets. Press Return at any time to jump straight to the market on Kalshi.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.kalshiMuted)
                        .lineSpacing(3)
                }

                Button(action: onOpenInBrowser) {
                    Label("Open on Kalshi", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.kalshiMint)

            } else {
                VStack(alignment: .leading, spacing: 10) {
                    TruthPulseWordmarkView()

                    Text("Type to search open Kalshi markets across titles, event text, descriptions, and outcome labels.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.kalshiMuted)

                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.95))
        )
    }
}
