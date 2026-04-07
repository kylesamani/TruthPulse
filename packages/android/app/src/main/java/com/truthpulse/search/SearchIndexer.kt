package com.truthpulse.search

import android.app.SearchManager
import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.provider.BaseColumns
import android.util.Log
import androidx.appsearch.app.AppSearchSchema
import androidx.appsearch.app.GenericDocument
import androidx.appsearch.app.PutDocumentsRequest
import androidx.appsearch.app.RemoveByDocumentIdRequest
import androidx.appsearch.app.SearchSpec
import androidx.appsearch.app.SetSchemaRequest
import androidx.appsearch.platformstorage.PlatformStorage
import com.truthpulse.TruthPulseApp
import com.truthpulse.data.MarketSummary
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.guava.await
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

private const val TAG = "TruthPulse"
private const val DB_NAME = "truthpulse_markets"
private const val NAMESPACE = "markets"
private const val SCHEMA_TYPE = "Market"

/**
 * Indexes markets into Android AppSearch platform storage.
 * This makes markets discoverable via OEM launcher search (Samsung, OnePlus, etc.).
 */
class SearchIndexer(private val context: Context) {

    /**
     * Index all markets into AppSearch platform storage.
     * Call after each successful market refresh.
     */
    suspend fun indexMarkets(markets: List<MarketSummary>) = withContext(Dispatchers.IO) {
        try {
            val session = PlatformStorage.createSearchSessionAsync(
                PlatformStorage.SearchContext.Builder(context, DB_NAME).build()
            ).await()

            // Set schema
            val schema = AppSearchSchema.Builder(SCHEMA_TYPE)
                .addProperty(
                    AppSearchSchema.StringPropertyConfig.Builder("title")
                        .setCardinality(AppSearchSchema.PropertyConfig.CARDINALITY_REQUIRED)
                        .setIndexingType(AppSearchSchema.StringPropertyConfig.INDEXING_TYPE_PREFIXES)
                        .setTokenizerType(AppSearchSchema.StringPropertyConfig.TOKENIZER_TYPE_PLAIN)
                        .build()
                )
                .addProperty(
                    AppSearchSchema.StringPropertyConfig.Builder("description")
                        .setCardinality(AppSearchSchema.PropertyConfig.CARDINALITY_OPTIONAL)
                        .setIndexingType(AppSearchSchema.StringPropertyConfig.INDEXING_TYPE_PREFIXES)
                        .setTokenizerType(AppSearchSchema.StringPropertyConfig.TOKENIZER_TYPE_PLAIN)
                        .build()
                )
                .addProperty(
                    AppSearchSchema.StringPropertyConfig.Builder("url")
                        .setCardinality(AppSearchSchema.PropertyConfig.CARDINALITY_REQUIRED)
                        .setIndexingType(AppSearchSchema.StringPropertyConfig.INDEXING_TYPE_NONE)
                        .build()
                )
                .addProperty(
                    AppSearchSchema.StringPropertyConfig.Builder("category")
                        .setCardinality(AppSearchSchema.PropertyConfig.CARDINALITY_OPTIONAL)
                        .setIndexingType(AppSearchSchema.StringPropertyConfig.INDEXING_TYPE_PREFIXES)
                        .setTokenizerType(AppSearchSchema.StringPropertyConfig.TOKENIZER_TYPE_PLAIN)
                        .build()
                )
                .addProperty(
                    AppSearchSchema.LongPropertyConfig.Builder("odds")
                        .setCardinality(AppSearchSchema.PropertyConfig.CARDINALITY_OPTIONAL)
                        .build()
                )
                .build()

            session.setSchemaAsync(
                SetSchemaRequest.Builder()
                    .addSchemas(schema)
                    .setForceOverride(true)
                    .build()
            ).await()

            // Index in batches of 500
            markets.chunked(500).forEach { batch ->
                val documents = batch.map { market ->
                    val odds = market.displayOdds
                    val desc = buildString {
                        if (odds != null) append("${odds}% YES")
                        market.category?.let {
                            if (isNotEmpty()) append(" — ")
                            append(it)
                        }
                        market.eventTitle?.let {
                            if (it != market.title) {
                                if (isNotEmpty()) append(" — ")
                                append(it)
                            }
                        }
                    }

                    val builder = GenericDocument.Builder<GenericDocument.Builder<*>>(
                        NAMESPACE, market.ticker, SCHEMA_TYPE
                    )
                        .setPropertyString("title", market.title)
                        .setPropertyString("url", market.resolvedWebUrl)

                    if (desc.isNotEmpty()) {
                        builder.setPropertyString("description", desc)
                    }
                    market.category?.let {
                        builder.setPropertyString("category", it)
                    }
                    if (odds != null) {
                        builder.setPropertyLong("odds", odds.toLong())
                    }

                    builder.build()
                }

                session.putAsync(
                    PutDocumentsRequest.Builder().addGenericDocuments(documents).build()
                ).await()
            }

            session.close()
            Log.d(TAG, "AppSearch: indexed ${markets.size} markets")
        } catch (e: Exception) {
            Log.w(TAG, "AppSearch indexing failed (non-fatal): ${e.message}")
        }
    }
}

/**
 * ContentProvider that responds to Android Global Search queries.
 * Kept as fallback for older devices/launchers that still use this approach.
 */
class MarketSearchProvider : ContentProvider() {

    private val suggestionColumns = arrayOf(
        BaseColumns._ID,
        SearchManager.SUGGEST_COLUMN_TEXT_1,
        SearchManager.SUGGEST_COLUMN_TEXT_2,
        SearchManager.SUGGEST_COLUMN_INTENT_DATA,
        SearchManager.SUGGEST_COLUMN_QUERY,
    )

    override fun onCreate(): Boolean = true

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        val cursor = MatrixCursor(suggestionColumns)

        val query = uri.lastPathSegment ?: selectionArgs?.firstOrNull() ?: return cursor
        if (query.length < 4) return cursor

        val app = context?.applicationContext as? TruthPulseApp ?: return cursor
        val searchService = app.searchService

        runBlocking {
            searchService.bootstrapIfNeeded()
        }

        val results = searchService.search(query, limit = 10)

        results.forEachIndexed { index, result ->
            cursor.addRow(
                arrayOf(
                    index.toLong(),
                    result.market.title,
                    formatSubtitle(result.market),
                    result.market.resolvedWebUrl,
                    result.market.title,
                )
            )
        }

        return cursor
    }

    override fun getType(uri: Uri): String =
        "vnd.android.cursor.dir/vnd.com.truthpulse.market"

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int = 0
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    private fun formatSubtitle(market: MarketSummary): String {
        val odds = market.displayOdds
        val category = market.category ?: ""
        return if (odds != null) {
            "$odds% YES" + if (category.isNotEmpty()) " — $category" else ""
        } else {
            category
        }
    }
}
