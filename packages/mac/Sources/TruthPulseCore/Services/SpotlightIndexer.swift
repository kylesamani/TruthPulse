import CoreSpotlight
import Foundation

/// Indexes prediction markets into Core Spotlight for system-wide search.
public final class SpotlightIndexer: Sendable {
    private static let domainIdentifier = "com.truthpulse.markets"

    public init() {}

    private static func log(_ message: String) {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("TruthPulse", isDirectory: true)
        guard let dir else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("spotlight.log")
        let line = "[\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            try? data.write(to: url)
        }
    }

    /// Index all markets into Core Spotlight. Fire-and-forget.
    public func indexMarkets(_ markets: [MarketSummary]) {
        Self.log("indexMarkets called with \(markets.count) markets")

        let items = markets.compactMap { makeSearchableItem(from: $0) }
        Self.log("Created \(items.count) searchable items")

        guard !items.isEmpty else {
            Self.log("No items to index")
            return
        }

        let index = CSSearchableIndex.default()

        // Delete old items first
        index.deleteSearchableItems(withDomainIdentifiers: [Self.domainIdentifier]) { [items] error in
            if let error {
                Self.log("Delete failed: \(error)")
            } else {
                Self.log("Delete succeeded")
            }

            // Index in batches, chaining via global queue to avoid deadlock
            let batchSize = 500
            Self.indexBatch(items: items, index: index, batchSize: batchSize, offset: 0)
        }
    }

    private static func indexBatch(items: [CSSearchableItem], index: CSSearchableIndex, batchSize: Int, offset: Int) {
        guard offset < items.count else {
            let totalCount = items.count
            log("All batches complete: \(totalCount) items")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .truthPulseSpotlightIndexed,
                    object: nil,
                    userInfo: ["count": totalCount]
                )
            }
            return
        }

        let end = min(offset + batchSize, items.count)
        let batch = Array(items[offset..<end])

        // Use DispatchQueue.global to break out of CoreSpotlight's callback queue
        DispatchQueue.global(qos: .utility).async {
            index.indexSearchableItems(batch) { error in
                if let error {
                    log("Batch \(offset)-\(end) error: \(error)")
                }
                // Chain next batch from global queue
                DispatchQueue.global(qos: .utility).async {
                    indexBatch(items: items, index: index, batchSize: batchSize, offset: end)
                }
            }
        }
    }

    /// Remove all TruthPulse items from the Spotlight index.
    public func deindexAll() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [Self.domainIdentifier]) { _ in }
    }

    private func makeSearchableItem(from market: MarketSummary) -> CSSearchableItem? {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)

        attributes.title = market.title
        attributes.contentDescription = formatDescription(for: market)
        attributes.contentURL = market.resolvedWebURL

        #if os(macOS)
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") {
            attributes.thumbnailURL = iconURL
        }
        #endif

        if let category = market.category {
            attributes.subject = category
        }

        if let closeTime = market.closeTime {
            attributes.metadataModificationDate = closeTime
        }

        let item = CSSearchableItem(
            uniqueIdentifier: market.resolvedWebURL.absoluteString,
            domainIdentifier: Self.domainIdentifier,
            attributeSet: attributes
        )

        if let closeTime = market.closeTime {
            item.expirationDate = closeTime.addingTimeInterval(86400)
        }

        return item
    }

    private func formatDescription(for market: MarketSummary) -> String {
        var parts: [String] = []

        if let odds = market.displayOdds {
            parts.append("\(odds)% YES")
        }

        if let closeTime = market.closeTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            parts.append("closes \(formatter.string(from: closeTime))")
        }

        return parts.joined(separator: " — ")
    }
}

public extension Notification.Name {
    static let truthPulseSpotlightIndexed = Notification.Name("truthPulseSpotlightIndexed")
}
