import Foundation

struct IndexedSearchCandidate: Sendable {
    let market: MarketSummary
    let baseRank: Double
}

struct RankingPolicy: Sendable {
    func rank(query: String, candidates: [IndexedSearchCandidate]) -> [SearchResult] {
        let normalizedQuery = query.normalizedSearchText
        let tokens = normalizedQuery.searchTokens

        let results = candidates.compactMap { candidate in
            score(query: normalizedQuery, tokens: tokens, candidate: candidate)
        }

        return results.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.market.volumeSignal > rhs.market.volumeSignal
            }
            return lhs.score > rhs.score
        }
    }

    private func score(query: String, tokens: [String], candidate: IndexedSearchCandidate) -> SearchResult? {
        let market = candidate.market

        if query.isEmpty {
            return SearchResult(
                market: market,
                score: baseMarketSignals(for: market) + candidate.baseRank,
                matchedField: .none,
                matchedOutcome: nil,
                titleHighlights: [],
                subtitleHighlights: [],
                outcomeHighlights: []
            )
        }

        let fields: [(MatchField, String)] = [
            (.title, market.title),
            (.subtitle, market.subtitle ?? ""),
            (.outcome, [market.yesLabel, market.noLabel].compactMap { $0 }.joined(separator: " ")),
            (.eventTitle, [market.eventTitle, market.eventSubtitle].compactMap { $0 }.joined(separator: " ")),
            (.category, market.category ?? "")
        ]

        var bestField: MatchField = .none
        var bestFieldScore = 0.0
        var anyMatch = false

        for (field, value) in fields where !value.isEmpty {
            let fieldScore = textScore(query: query, tokens: tokens, text: value, field: field)
            if fieldScore > 0 {
                anyMatch = true
            }
            if fieldScore > bestFieldScore {
                bestFieldScore = fieldScore
                bestField = field
            }
        }

        guard anyMatch else { return nil }

        let outcome = matchedOutcome(query: query, tokens: tokens, market: market)
        let titleHighlights = highlightRanges(for: market.title, query: query, tokens: tokens)
        let subtitleHighlights = highlightRanges(for: market.subtitle ?? "", query: query, tokens: tokens)
        let outcomeText = [market.yesLabel, market.noLabel].compactMap { $0 }.joined(separator: " ")
        let outcomeHighlights = highlightRanges(for: outcomeText, query: query, tokens: tokens)

        var score = bestFieldScore
        score += baseMarketSignals(for: market)
        score += candidate.baseRank
        score += proximityBonus(tokens: tokens, title: market.title.normalizedSearchText)

        return SearchResult(
            market: market,
            score: score,
            matchedField: bestField,
            matchedOutcome: outcome,
            titleHighlights: titleHighlights,
            subtitleHighlights: subtitleHighlights,
            outcomeHighlights: outcomeHighlights
        )
    }

    private func textScore(query: String, tokens: [String], text: String, field: MatchField) -> Double {
        let normalized = text.normalizedSearchText
        guard !normalized.isEmpty else { return 0 }

        let weight = fieldWeight(field)
        var score = 0.0

        if normalized == query {
            score += weight * 4.0
        }
        if normalized.contains(query) {
            score += weight * 2.0
        }
        if normalized.hasPrefix(query) {
            score += weight * 1.2
        }

        let fieldTokens = normalized.searchTokens
        let coveredTokens = tokens.filter { token in
            fieldTokens.contains(where: { $0 == token || $0.hasPrefix(token) })
        }

        score += Double(coveredTokens.count) * weight * 0.65

        if coveredTokens.count == tokens.count, !tokens.isEmpty {
            score += weight * 1.25
        }

        return score
    }

    private func matchedOutcome(query: String, tokens: [String], market: MarketSummary) -> MarketOutcomeSide? {
        let yesText = (market.yesLabel ?? "").normalizedSearchText
        let noText = (market.noLabel ?? "").normalizedSearchText

        let yesScore = textScore(query: query, tokens: tokens, text: yesText, field: .outcome)
        let noScore = textScore(query: query, tokens: tokens, text: noText, field: .outcome)

        if yesScore == 0, noScore == 0 {
            return nil
        }

        return yesScore >= noScore ? .yes : .no
    }

    private func fieldWeight(_ field: MatchField) -> Double {
        switch field {
        case .title:
            30
        case .subtitle:
            22
        case .outcome:
            24
        case .eventTitle:
            18
        case .description:
            10
        case .category:
            7
        case .none:
            0
        }
    }

    private func baseMarketSignals(for market: MarketSummary) -> Double {
        let liquidity = log1p(market.liquidity ?? 0) * 2.2
        let volume = log1p(max(market.volume24h ?? 0, market.volume ?? 0)) * 2.8
        let openInterest = log1p(market.openInterest ?? 0) * 1.2

        let recency: Double
        if let updatedAt = market.updatedAt {
            let hours = max(Date().timeIntervalSince(updatedAt) / 3_600, 0)
            recency = max(0, 6 - hours) * 0.6
        } else {
            recency = 0
        }

        return liquidity + volume + openInterest + recency
    }

    private func proximityBonus(tokens: [String], title: String) -> Double {
        guard tokens.count > 1 else { return 0 }
        let positions = tokens.compactMap { token in
            title.range(of: token)?.lowerBound.utf16Offset(in: title)
        }
        guard positions.count == tokens.count else { return 0 }
        let spread = (positions.max() ?? 0) - (positions.min() ?? 0)
        return max(0, 18 - Double(spread) * 0.18)
    }

    private func highlightRanges(for text: String, query: String, tokens: [String]) -> [TextHighlightRange] {
        let lowercased = text.lowercased()
        var ranges: [TextHighlightRange] = []

        if !query.isEmpty, let range = lowercased.range(of: query) {
            let nsRange = NSRange(range, in: text)
            ranges.append(TextHighlightRange(start: nsRange.location, length: nsRange.length))
        } else {
            for token in tokens {
                guard let range = lowercased.range(of: token) else { continue }
                let nsRange = NSRange(range, in: text)
                ranges.append(TextHighlightRange(start: nsRange.location, length: nsRange.length))
            }
        }

        return ranges
    }
}

extension String {
    var normalizedSearchText: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var searchTokens: [String] {
        components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }
}
