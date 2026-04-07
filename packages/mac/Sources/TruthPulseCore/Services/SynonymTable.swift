import Foundation

/// Loads synonyms from the shared synonyms.json and expands query tokens at search time.
public struct SynonymTable: Sendable {
    private let table: [String: [String]]

    public init() {
        self.table = SynonymTable.load()
    }

    /// Expand a list of query tokens using synonyms.
    /// For each token, if it matches a synonym key, the expansions are appended.
    /// Returns the original tokens plus any expanded terms.
    public func expandTokens(_ tokens: [String]) -> [String] {
        var expanded = tokens
        for token in tokens {
            if let synonyms = table[token] {
                for synonym in synonyms {
                    let synonymTokens = synonym.normalizedSearchText.searchTokens
                    for st in synonymTokens where !expanded.contains(st) {
                        expanded.append(st)
                    }
                }
            }
        }
        return expanded
    }

    /// Expand a normalized query string into multiple query variants.
    /// Returns the original query plus queries with synonym expansions.
    public func expandQuery(_ normalizedQuery: String) -> [String] {
        let tokens = normalizedQuery.searchTokens
        let expandedTokens = expandTokens(tokens)
        let newTokens = expandedTokens.filter { !tokens.contains($0) }
        if newTokens.isEmpty {
            return [normalizedQuery]
        }
        return [normalizedQuery, newTokens.joined(separator: " ")]
    }

    private static func load() -> [String: [String]] {
        guard let url = Bundle.main.url(forResource: "synonyms", withExtension: "json")
                ?? bundleFallbackURL() else {
            return [:]
        }

        do {
            let data = try Data(contentsOf: url)
            let wrapper = try JSONDecoder().decode(SynonymFile.self, from: data)
            // Normalize all keys to lowercase
            var normalized: [String: [String]] = [:]
            for (key, values) in wrapper.synonyms {
                normalized[key.lowercased()] = values
            }
            return normalized
        } catch {
            return [:]
        }
    }

    /// Fallback: look for synonyms.json relative to the executable (for dev builds).
    private static func bundleFallbackURL() -> URL? {
        let executableURL = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
        // Walk up from .build/debug/TruthPulse to find packages/shared/synonyms.json
        var dir = executableURL.deletingLastPathComponent()
        for _ in 0..<6 {
            let candidate = dir.appendingPathComponent("packages/shared/synonyms.json")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }
}

private struct SynonymFile: Decodable {
    let synonyms: [String: [String]]
}
