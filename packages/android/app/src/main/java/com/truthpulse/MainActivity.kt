package com.truthpulse

import android.app.SearchManager
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.truthpulse.ui.SearchScreen
import com.truthpulse.ui.TruthPulseTheme

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        handleSearchIntent(intent)

        setContent {
            TruthPulseTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    SearchScreen()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleSearchIntent(intent)
    }

    /**
     * Handle incoming search intents from Global Search.
     * ACTION_VIEW: user tapped a suggestion — open the Kalshi URL.
     * ACTION_SEARCH: user typed and pressed enter — we just let the in-app search handle it.
     */
    private fun handleSearchIntent(intent: Intent?) {
        intent ?: return

        when (intent.action) {
            Intent.ACTION_VIEW -> {
                val url = intent.dataString
                if (!url.isNullOrEmpty()) {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                }
            }
            Intent.ACTION_SEARCH -> {
                // The search query will be picked up by the in-app SearchScreen
                // via the ViewModel. Nothing extra needed here.
            }
        }
    }
}
