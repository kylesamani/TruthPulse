package com.truthpulse.search

import android.app.SearchManager
import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.provider.BaseColumns
import com.truthpulse.TruthPulseApp
import com.truthpulse.data.MarketSummary
import com.truthpulse.data.normalizedSearchText
import kotlinx.coroutines.runBlocking

/**
 * Provides Global Search integration via a ContentProvider.
 * When the system search queries our authority, we return matching markets
 * as search suggestions.
 */
class SearchIndexer {

    /**
     * ContentProvider that responds to Android Global Search queries.
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

            // Bootstrap from cache if needed
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
                "$odds% YES" + if (category.isNotEmpty()) " - $category" else ""
            } else {
                category
            }
        }
    }

    companion object {
        /**
         * Build a simple search index for AppSearch.
         * This is a lightweight wrapper that just makes markets findable via system search.
         */
        fun indexMarkets(context: Context, markets: List<MarketSummary>) {
            // The ContentProvider handles search dynamically.
            // This method is a hook for future AppSearch integration if needed.
            // For now, the live ContentProvider approach is sufficient since
            // the search service maintains its own in-memory index.
        }
    }
}
