package com.truthpulse.search

import com.truthpulse.data.*
import kotlin.math.ln
import kotlin.math.max

/**
 * Multi-signal ranking algorithm matching the macOS Swift implementation.
 *
 * Field weights: title=30, outcome=24, subtitle=22, eventTitle=18, category=7
 * Text scoring: exact x4, substring x2, prefix x1.2, token coverage x0.65, all-tokens bonus x1.25
 * Market signals: ln(1+liquidity)*2.2 + ln(1+volume)*2.8 + ln(1+OI)*1.2 + recency
 * Proximity bonus: max(0, 18 - spread*0.18)
 */
class RankingPolicy {

    fun rank(query: String, candidates: List<IndexedSearchCandidate>): List<SearchResult> {
        val normalizedQuery = query.normalizedSearchText()
        val tokens = normalizedQuery.searchTokens()

        return candidates
            .mapNotNull { score(normalizedQuery, tokens, it) }
            .sortedWith(compareByDescending<SearchResult> { it.score }
                .thenByDescending { it.market.volumeSignal })
    }

    private fun score(
        query: String,
        tokens: List<String>,
        candidate: IndexedSearchCandidate,
    ): SearchResult? {
        val market = candidate.market

        if (query.isEmpty()) {
            return SearchResult(
                market = market,
                score = baseMarketSignals(market) + candidate.baseRank,
                matchedField = MatchField.NONE,
                matchedOutcome = null,
                titleHighlights = emptyList(),
                subtitleHighlights = emptyList(),
                outcomeHighlights = emptyList(),
            )
        }

        val fields = listOf(
            MatchField.TITLE to market.title,
            MatchField.SUBTITLE to (market.subtitle ?: ""),
            MatchField.OUTCOME to listOfNotNull(market.yesLabel, market.noLabel).joinToString(" "),
            MatchField.EVENT_TITLE to listOfNotNull(market.eventTitle, market.eventSubtitle).joinToString(" "),
            MatchField.CATEGORY to (market.category ?: ""),
        )

        var bestField = MatchField.NONE
        var bestFieldScore = 0.0
        var anyMatch = false

        for ((field, value) in fields) {
            if (value.isEmpty()) continue
            val fieldScore = textScore(query, tokens, value, field)
            if (fieldScore > 0) anyMatch = true
            if (fieldScore > bestFieldScore) {
                bestFieldScore = fieldScore
                bestField = field
            }
        }

        if (!anyMatch) return null

        val outcome = matchedOutcome(query, tokens, market)
        val titleHighlights = highlightRanges(market.title, query, tokens)
        val subtitleHighlights = highlightRanges(market.subtitle ?: "", query, tokens)
        val outcomeText = listOfNotNull(market.yesLabel, market.noLabel).joinToString(" ")
        val outcomeHighlights = highlightRanges(outcomeText, query, tokens)

        var totalScore = bestFieldScore
        totalScore += baseMarketSignals(market)
        totalScore += candidate.baseRank
        totalScore += proximityBonus(tokens, market.title.normalizedSearchText())

        return SearchResult(
            market = market,
            score = totalScore,
            matchedField = bestField,
            matchedOutcome = outcome,
            titleHighlights = titleHighlights,
            subtitleHighlights = subtitleHighlights,
            outcomeHighlights = outcomeHighlights,
        )
    }

    private fun textScore(query: String, tokens: List<String>, text: String, field: MatchField): Double {
        val normalized = text.normalizedSearchText()
        if (normalized.isEmpty()) return 0.0

        val weight = fieldWeight(field)
        var score = 0.0

        if (normalized == query) score += weight * 4.0
        if (normalized.contains(query)) score += weight * 2.0
        if (normalized.startsWith(query)) score += weight * 1.2

        val fieldTokens = normalized.searchTokens()
        val coveredTokens = tokens.filter { token ->
            fieldTokens.any { ft -> ft == token || ft.startsWith(token) }
        }

        score += coveredTokens.size.toDouble() * weight * 0.65

        if (coveredTokens.size == tokens.size && tokens.isNotEmpty()) {
            score += weight * 1.25
        }

        return score
    }

    private fun matchedOutcome(query: String, tokens: List<String>, market: MarketSummary): MarketOutcomeSide? {
        val yesText = (market.yesLabel ?: "").normalizedSearchText()
        val noText = (market.noLabel ?: "").normalizedSearchText()

        val yesScore = textScore(query, tokens, yesText, MatchField.OUTCOME)
        val noScore = textScore(query, tokens, noText, MatchField.OUTCOME)

        if (yesScore == 0.0 && noScore == 0.0) return null
        return if (yesScore >= noScore) MarketOutcomeSide.YES else MarketOutcomeSide.NO
    }

    private fun fieldWeight(field: MatchField): Double = when (field) {
        MatchField.TITLE -> 30.0
        MatchField.SUBTITLE -> 22.0
        MatchField.OUTCOME -> 24.0
        MatchField.EVENT_TITLE -> 18.0
        MatchField.DESCRIPTION -> 10.0
        MatchField.CATEGORY -> 7.0
        MatchField.NONE -> 0.0
    }

    private fun baseMarketSignals(market: MarketSummary): Double {
        val liquidity = ln(1.0 + (market.liquidity ?: 0.0)) * 2.2
        val volume = ln(1.0 + max(market.volume24h ?: 0.0, market.volume ?: 0.0)) * 2.8
        val openInterest = ln(1.0 + (market.openInterest ?: 0.0)) * 1.2

        val recency: Double = market.updatedAtMillis?.let { updatedAt ->
            val hours = max((System.currentTimeMillis() - updatedAt).toDouble() / 3_600_000.0, 0.0)
            max(0.0, 6.0 - hours) * 0.6
        } ?: 0.0

        return liquidity + volume + openInterest + recency
    }

    private fun proximityBonus(tokens: List<String>, title: String): Double {
        if (tokens.size <= 1) return 0.0
        val positions = tokens.mapNotNull { token ->
            val idx = title.indexOf(token)
            if (idx >= 0) idx else null
        }
        if (positions.size != tokens.size) return 0.0
        val spread = (positions.max()) - (positions.min())
        return max(0.0, 18.0 - spread.toDouble() * 0.18)
    }

    private fun highlightRanges(text: String, query: String, tokens: List<String>): List<TextHighlightRange> {
        val lowercased = text.lowercase()
        val ranges = mutableListOf<TextHighlightRange>()

        if (query.isNotEmpty()) {
            val idx = lowercased.indexOf(query)
            if (idx >= 0) {
                ranges.add(TextHighlightRange(start = idx, length = query.length))
                return ranges
            }
        }

        for (token in tokens) {
            val idx = lowercased.indexOf(token)
            if (idx >= 0) {
                ranges.add(TextHighlightRange(start = idx, length = token.length))
            }
        }

        return ranges
    }
}

data class IndexedSearchCandidate(
    val market: MarketSummary,
    val baseRank: Double,
)
