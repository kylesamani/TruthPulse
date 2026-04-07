package com.truthpulse.data

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File

/**
 * Persists market data as JSON on disk for instant startup.
 */
class MarketCacheStore(private val context: Context) {

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    private val cacheFile: File
        get() = File(context.filesDir, "markets_cache.json")

    private val timestampFile: File
        get() = File(context.filesDir, "markets_cache_ts.txt")

    fun cacheFileExists(): Boolean = cacheFile.exists() && cacheFile.length() > 0

    suspend fun loadMarkets(): List<MarketSummary> = withContext(Dispatchers.IO) {
        try {
            if (!cacheFile.exists()) return@withContext emptyList()
            val text = cacheFile.readText()
            if (text.isBlank()) return@withContext emptyList()
            json.decodeFromString<List<MarketSummary>>(text)
        } catch (e: Exception) {
            emptyList()
        }
    }

    suspend fun saveMarkets(markets: List<MarketSummary>) = withContext(Dispatchers.IO) {
        try {
            cacheFile.writeText(json.encodeToString(markets))
            timestampFile.writeText(System.currentTimeMillis().toString())
        } catch (_: Exception) {
            // Best-effort cache
        }
    }

    fun savedAtMillis(): Long? {
        return try {
            if (!timestampFile.exists()) null
            else timestampFile.readText().trim().toLongOrNull()
        } catch (_: Exception) {
            null
        }
    }
}
