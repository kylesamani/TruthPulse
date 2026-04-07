import SwiftUI

public struct TruthPulseGlyph: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let points = [
            CGPoint(x: 0.02 * w, y: 0.58 * h),
            CGPoint(x: 0.28 * w, y: 0.58 * h),
            CGPoint(x: 0.40 * w, y: 0.24 * h),
            CGPoint(x: 0.56 * w, y: 0.82 * h),
            CGPoint(x: 0.72 * w, y: 0.40 * h),
            CGPoint(x: 0.98 * w, y: 0.40 * h)
        ]

        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

public struct TruthPulseMarkView: View {
    public var strokeColor: Color = .truthPulseMint
    public var background: Color = .truthPulseMintSoft
    public var size: CGFloat = 44
    public var lineWidth: CGFloat = 4

    public init(strokeColor: Color = .truthPulseMint, background: Color = .truthPulseMintSoft, size: CGFloat = 44, lineWidth: CGFloat = 4) {
        self.strokeColor = strokeColor
        self.background = background
        self.size = size
        self.lineWidth = lineWidth
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(background)
            .overlay {
                TruthPulseGlyph()
                    .stroke(strokeColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                    .padding(size * 0.19)
            }
            .frame(width: size, height: size)
    }
}

public struct TruthPulseWordmarkView: View {
    public init() {}

    public var body: some View {
        HStack(alignment: .center, spacing: 10) {
            TruthPulseMarkView(size: 34, lineWidth: 3.4)

            Text("TruthPulse")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.truthPulseInk)
        }
    }
}
