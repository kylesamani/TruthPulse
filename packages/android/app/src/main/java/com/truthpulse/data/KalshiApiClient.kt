package com.truthpulse.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.*
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

class KalshiApiClient {

    private val baseUrl = "https://api.elections.kalshi.com/trade-api/v2"

    private val client = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        coerceInputValues = true
    }

    /**
     * Fetch all open markets with cursor pagination.
     */
    suspend fun fetchOpenMarkets(): List<MarketSummary> = withContext(Dispatchers.IO) {
        val allMarkets = mutableListOf<MarketSummary>()
        var cursor: String? = null

        do {
            val url = buildString {
                append("$baseUrl/events?status=open&limit=200&with_nested_markets=true")
                if (!cursor.isNullOrEmpty()) {
                    append("&cursor=$cursor")
                }
            }

            val request = Request.Builder()
                .url(url)
                .header("Accept", "application/json")
                .get()
                .build()

            val response = client.newCall(request).execute()
            if (!response.isSuccessful) {
                response.close()
                throw RuntimeException("HTTP ${response.code}: ${response.message}")
            }

            val body = response.body?.string() ?: throw RuntimeException("Empty response body")
            response.close()

            val root = json.parseToJsonElement(body).jsonObject
            val events = root["events"]?.jsonArray ?: break
            if (events.isEmpty()) break

            for (eventElement in events) {
                val event = eventElement.jsonObject
                val markets = event["markets"]?.jsonArray ?: continue

                for (marketElement in markets) {
                    val market = marketElement.jsonObject
                    val status = market.stringOrNull("status")?.lowercase() ?: ""
                    if (status != "active" && status != "open") continue

                    allMarkets.add(parseMarket(market, event))
                }
            }

            cursor = root.stringOrNull("cursor")
        } while (!cursor.isNullOrEmpty())

        allMarkets
    }

    /**
     * Fetch candlestick trend data for a specific market.
     */
    suspend fun fetchTrend(
        marketTicker: String,
        seriesTicker: String,
        window: TrendWindow,
    ): MarketTrend = withContext(Dispatchers.IO) {
        val now = System.currentTimeMillis() / 1000
        val startTs = now - window.durationSeconds

        val url = "$baseUrl/series/$seriesTicker/markets/$marketTicker/candlesticks" +
            "?start_ts=$startTs&end_ts=$now&period_interval=${window.intervalMinutes}"

        val request = Request.Builder()
            .url(url)
            .header("Accept", "application/json")
            .get()
            .build()

        val response = client.newCall(request).execute()
        if (!response.isSuccessful) {
            response.close()
            throw RuntimeException("HTTP ${response.code}: ${response.message}")
        }

        val body = response.body?.string() ?: throw RuntimeException("Empty response body")
        response.close()

        val root = json.parseToJsonElement(body).jsonObject
        val candlesticks = root["candlesticks"]?.jsonArray ?: JsonArray(emptyList())

        val points = candlesticks.mapNotNull { element ->
            val candle = element.jsonObject
            val timestamp = candle.flexibleLong("end_period_ts") ?: return@mapNotNull null
            val rawPrice = bestCandlePrice(candle) ?: return@mapNotNull null
            val normalizedPrice = if (rawPrice > 1.0) rawPrice else rawPrice * 100.0
            TrendPoint(
                timestampMillis = timestamp * 1000,
                value = normalizedPrice,
            )
        }.sortedBy { it.timestampMillis }

        val delta = if (points.size >= 2) {
            points.last().value - points.first().value
        } else null

        MarketTrend(
            marketTicker = marketTicker,
            window = window,
            points = points,
            delta = delta,
            updatedAtMillis = System.currentTimeMillis(),
        )
    }

    private fun bestCandlePrice(candle: JsonObject): Double? {
        // yes_ask.close_dollars -> yes_bid.close_dollars -> price.previous_dollars
        candle["yes_ask"]?.jsonObject?.flexibleDouble("close_dollars")?.let { return it }
        candle["yes_bid"]?.jsonObject?.flexibleDouble("close_dollars")?.let { return it }
        candle["price"]?.jsonObject?.flexibleDouble("previous_dollars")?.let { return it }
        return null
    }

    private fun parseMarket(market: JsonObject, event: JsonObject): MarketSummary {
        val lastPrice = market.flexibleDouble("last_price_dollars")
        val yesAsk = market.flexibleDouble("yes_ask_dollars")
        val noAsk = market.flexibleDouble("no_ask_dollars")
        val yesBid = market.flexibleDouble("yes_bid_dollars")
        val noBid = market.flexibleDouble("no_bid_dollars")

        val yesPrice = yesAsk ?: yesBid ?: lastPrice
        val noPrice = noAsk ?: noBid ?: lastPrice?.let { maxOf(0.0, 1.0 - it) }

        val imageUrl = extractImageUrl(event, market)
        val webUrl = market.stringOrNull("url") ?: event.stringOrNull("url")

        return MarketSummary(
            ticker = market.stringOrNull("ticker") ?: "",
            eventTicker = event.stringOrNull("event_ticker"),
            seriesTicker = event.stringOrNull("series_ticker"),
            title = market.stringOrNull("title") ?: event.stringOrNull("title") ?: "",
            subtitle = market.stringOrNull("sub_title"),
            yesLabel = market.stringOrNull("yes_sub_title"),
            noLabel = market.stringOrNull("no_sub_title"),
            eventTitle = event.stringOrNull("title"),
            eventSubtitle = event.stringOrNull("sub_title"),
            category = event.stringOrNull("category"),
            status = market.stringOrNull("status") ?: "active",
            lastPrice = normalizeUnitPrice(lastPrice),
            yesPrice = normalizeUnitPrice(yesPrice),
            noPrice = normalizeUnitPrice(noPrice),
            volume = market.flexibleDouble("volume_fp"),
            volume24h = market.flexibleDouble("volume_24h_fp"),
            openInterest = market.flexibleDouble("open_interest_fp"),
            liquidity = market.flexibleDouble("liquidity_dollars"),
            updatedAtMillis = parseTimestampMillis(market.stringOrNull("updated_time")),
            openTimeMillis = parseTimestampMillis(market.stringOrNull("open_time")),
            closeTimeMillis = parseTimestampMillis(market.stringOrNull("close_time")),
            imageUrl = imageUrl,
            webUrl = webUrl,
        )
    }

    private fun extractImageUrl(event: JsonObject, market: JsonObject): String? {
        // Check product_metadata.image in event then market
        for (obj in listOf(event, market)) {
            val metadata = obj["product_metadata"]?.jsonObject ?: continue
            metadata["image"]?.let { imageVal ->
                val str = when (imageVal) {
                    is JsonPrimitive -> imageVal.contentOrNull
                    else -> null
                }
                if (!str.isNullOrEmpty()) return str
            }
        }
        return null
    }

    private fun normalizeUnitPrice(value: Double?): Double? {
        if (value == null) return null
        return if (value > 1.0) value / 100.0 else value
    }

    private fun parseTimestampMillis(isoString: String?): Long? {
        if (isoString.isNullOrEmpty()) return null
        return try {
            java.time.Instant.parse(isoString).toEpochMilli()
        } catch (_: Exception) {
            try {
                // Try without fractional seconds
                java.time.Instant.parse(isoString.replace(Regex("\\.\\d+"), "")).toEpochMilli()
            } catch (_: Exception) {
                null
            }
        }
    }
}

// --- JSON helper extensions ---

/** Read a string field, tolerating missing/null. */
internal fun JsonObject.stringOrNull(key: String): String? {
    val element = this[key] ?: return null
    return if (element is JsonPrimitive) element.contentOrNull else null
}

/**
 * Flexibly read a number that might be encoded as int, float, or string.
 */
internal fun JsonObject.flexibleDouble(key: String): Double? {
    val element = this[key] ?: return null
    if (element is JsonNull) return null
    if (element is JsonPrimitive) {
        element.doubleOrNull?.let { return it }
        element.longOrNull?.let { return it.toDouble() }
        element.contentOrNull?.toDoubleOrNull()?.let { return it }
    }
    return null
}

internal fun JsonObject.flexibleLong(key: String): Long? {
    val element = this[key] ?: return null
    if (element is JsonNull) return null
    if (element is JsonPrimitive) {
        element.longOrNull?.let { return it }
        element.intOrNull?.let { return it.toLong() }
        element.contentOrNull?.toLongOrNull()?.let { return it }
    }
    return null
}
