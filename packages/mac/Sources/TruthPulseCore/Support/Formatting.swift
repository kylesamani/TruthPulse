import Foundation
import SwiftUI

public enum Formatters {
    public static let compactNumber: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.usesSignificantDigits = false
        formatter.notANumberSymbol = "-"
        return formatter
    }()

    @MainActor
    public static func relativeString(for date: Date, relativeTo referenceDate: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: referenceDate)
    }
}

public extension Double {
    var compactVolumeString: String {
        let value = self
        switch value {
        case 1_000_000...:
            return String(format: "%.1fM", value / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK", value / 1_000)
        default:
            return String(format: "%.0f", value)
        }
    }
}

public extension String {
    func highlightAttributedString(ranges: [TextHighlightRange], accent: Color = .kalshiMint) -> AttributedString {
        var attributed = AttributedString(self)
        let nsString = self as NSString

        for range in ranges {
            guard range.start >= 0, range.length > 0, range.start + range.length <= nsString.length else { continue }
            let start = attributed.index(attributed.startIndex, offsetByCharacters: range.start)
            let end = attributed.index(start, offsetByCharacters: range.length)
            attributed[start..<end].foregroundColor = accent
            attributed[start..<end].font = .system(size: 14, weight: .semibold)
        }

        return attributed
    }
}

public extension Color {
    static let truthPulseMint = Color(red: 0.06, green: 0.77, blue: 0.54)
    static let truthPulseMintDeep = Color(red: 0.03, green: 0.59, blue: 0.42)
    static let truthPulseMintSoft = Color(red: 0.90, green: 0.97, blue: 0.93)
    static let truthPulseLine = Color(red: 0.84, green: 0.93, blue: 0.88)
    static let truthPulseInk = Color(red: 0.06, green: 0.13, blue: 0.11)
    static let truthPulseMuted = Color(red: 0.36, green: 0.42, blue: 0.40)
    static let truthPulsePanel = Color(red: 0.97, green: 0.99, blue: 0.98)

    static let kalshiMint = truthPulseMint
    static let kalshiMintSoft = truthPulseMintSoft
    static let kalshiLine = truthPulseLine
    static let kalshiInk = truthPulseInk
    static let kalshiMuted = truthPulseMuted
    static let kalshiPanel = truthPulsePanel
}
