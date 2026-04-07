package com.truthpulse.data

import android.content.Context
import kotlinx.serialization.json.*

/**
 * Loads synonyms from assets/synonyms.json and expands query tokens at search time.
 */
class SynonymTable(context: Context) {

    private val table: Map<String, List<String>>

    init {
        table = loadFromAssets(context)
    }

    /**
     * Expand a list of query tokens using synonyms.
     * For each token that matches a synonym key, the expansions are appended.
     * Returns the original tokens plus any expanded terms.
     */
    fun expandTokens(tokens: List<String>): List<String> {
        val expanded = tokens.toMutableList()
        for (token in tokens) {
            val synonyms = table[token] ?: continue
            for (synonym in synonyms) {
                val synonymTokens = synonym.normalizedSearchText().searchTokens()
                for (st in synonymTokens) {
                    if (st !in expanded) {
                        expanded.add(st)
                    }
                }
            }
        }
        return expanded
    }

    private fun loadFromAssets(context: Context): Map<String, List<String>> {
        return try {
            val text = context.assets.open("synonyms.json").bufferedReader().readText()
            val root = Json.parseToJsonElement(text).jsonObject
            val synonymsObj = root["synonyms"]?.jsonObject ?: return emptyMap()

            val result = mutableMapOf<String, List<String>>()
            for ((key, value) in synonymsObj) {
                val values = (value as? JsonArray)?.mapNotNull { element ->
                    (element as? JsonPrimitive)?.contentOrNull
                } ?: continue
                result[key.lowercase()] = values
            }
            result
        } catch (_: Exception) {
            emptyMap()
        }
    }
}

// --- Search text normalization extensions ---

/**
 * Normalize text for search: lowercase, remove diacritics, collapse whitespace.
 */
fun String.normalizedSearchText(): String {
    return java.text.Normalizer.normalize(this, java.text.Normalizer.Form.NFD)
        .replace(Regex("[\\p{InCombiningDiacriticalMarks}]"), "")
        .lowercase()
        .replace(Regex("\\s+"), " ")
        .trim()
}

/**
 * Split normalized text into searchable tokens.
 */
fun String.searchTokens(): List<String> {
    return split(Regex("[^a-z0-9]+")).filter { it.isNotEmpty() }
}
