import SwiftUI
import TruthPulseCore

struct SparklineView: View {
    let trend: MarketTrend?
    let lineWidth: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.kalshiMintSoft.opacity(0.4))

                if let trend, trend.points.count > 1 {
                    let minValue: CGFloat = 0
                    let span: CGFloat = 100

                    Path { path in
                        for (index, point) in trend.points.enumerated() {
                            let x = geometry.size.width * CGFloat(index) / CGFloat(max(trend.points.count - 1, 1))
                            let normalizedY = (point.value - minValue) / span
                            let y = geometry.size.height - CGFloat(normalizedY) * geometry.size.height
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        (trend.delta ?? 0) >= 0 ? Color.kalshiMint : Color.red.opacity(0.85),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
                } else {
                    Text("No trend")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.kalshiMuted)
                }
            }
        }
    }
}
