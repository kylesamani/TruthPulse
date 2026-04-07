package com.truthpulse.data

import kotlinx.serialization.Serializable
import java.net.URLEncoder
import kotlin.math.roundToInt

enum class MarketOutcomeSide { YES, NO }

enum class MatchField { TITLE, SUBTITLE, OUTCOME, EVENT_TITLE, DESCRIPTION, CATEGORY, NONE }

data class TextHighlightRange(val start: Int, val length: Int)

@Serializable
data class MarketSummary(
    val ticker: String,
    val eventTicker: String? = null,
    val seriesTicker: String? = null,
    val title: String,
    val subtitle: String? = null,
    val yesLabel: String? = null,
    val noLabel: String? = null,
    val eventTitle: String? = null,
    val eventSubtitle: String? = null,
    val category: String? = null,
    val status: String = "active",
    val lastPrice: Double? = null,
    val yesPrice: Double? = null,
    val noPrice: Double? = null,
    val volume: Double? = null,
    val volume24h: Double? = null,
    val openInterest: Double? = null,
    val liquidity: Double? = null,
    val updatedAtMillis: Long? = null,
    val openTimeMillis: Long? = null,
    val closeTimeMillis: Long? = null,
    val imageUrl: String? = null,
    val webUrl: String? = null,
) {
    val id: String get() = ticker

    val resolvedWebUrl: String
        get() {
            webUrl?.let { return it }

            if (seriesTicker != null && eventTicker != null) {
                val series = seriesTicker.lowercase()
                val event = eventTicker.lowercase()
                return "https://kalshi.com/markets/$series/m/$event"
            }

            val encoded = URLEncoder.encode(title, "UTF-8")
            return "https://kalshi.com/browse?query=$encoded"
        }

    val displayOdds: Int?
        get() {
            val price = yesPrice ?: lastPrice ?: return null
            return (price * 100).roundToInt()
        }

    val volumeSignal: Double
        get() = maxOf(volume24h ?: 0.0, volume ?: 0.0)
}

data class SearchResult(
    val market: MarketSummary,
    val score: Double,
    val matchedField: MatchField,
    val matchedOutcome: MarketOutcomeSide?,
    val titleHighlights: List<TextHighlightRange>,
    val subtitleHighlights: List<TextHighlightRange>,
    val outcomeHighlights: List<TextHighlightRange>,
) {
    val id: String get() = market.id

    val emphasizedOdds: Int?
        get() = when (matchedOutcome) {
            MarketOutcomeSide.YES -> {
                market.yesPrice?.let { (it * 100).roundToInt() } ?: market.displayOdds
            }
            MarketOutcomeSide.NO -> {
                market.noPrice?.let { (it * 100).roundToInt() } ?: market.displayOdds
            }
            null -> market.displayOdds
        }

    val emphasizedOutcomeLabel: String
        get() = when (matchedOutcome) {
            MarketOutcomeSide.YES -> market.yesLabel ?: "YES"
            MarketOutcomeSide.NO -> market.noLabel ?: "NO"
            null -> "YES"
        }
}
