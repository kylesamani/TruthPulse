import SwiftUI
import TruthPulseCore

struct IOSSparklineView: View {
    let trend: MarketTrend

    var body: some View {
        GeometryReader { geometry in
            if trend.points.count > 1 {
                Path { path in
                    let span: CGFloat = 100
                    for (index, point) in trend.points.enumerated() {
                        let x = geometry.size.width * CGFloat(index) / CGFloat(max(trend.points.count - 1, 1))
                        let normalizedY = point.value / span
                        let y = geometry.size.height - CGFloat(normalizedY) * geometry.size.height
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    (trend.delta ?? 0) >= 0 ? Color.truthPulseMint : Color.red.opacity(0.85),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }
}
