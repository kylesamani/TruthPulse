package com.truthpulse.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.truthpulse.R
import com.truthpulse.data.MarketTrend
import com.truthpulse.data.SearchResult
import kotlinx.coroutines.delay

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SearchScreen(
    viewModel: SearchViewModel = viewModel(),
) {
    val context = LocalContext.current
    val uiState by viewModel.uiState.collectAsState()
    val focusRequester = remember { FocusRequester() }
    val keyboardController = LocalSoftwareKeyboardController.current

    // Request focus on first composition
    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .widthIn(max = 600.dp)
            .then(
                if (true) Modifier.fillMaxWidth()
                else Modifier
            ),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp)
                .align(Alignment.TopCenter)
                .widthIn(max = 600.dp),
        ) {
            Spacer(modifier = Modifier.windowInsetsPadding(WindowInsets.statusBars))

            // Search bar
            OutlinedTextField(
                value = uiState.query,
                onValueChange = { viewModel.updateQuery(it) },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 8.dp)
                    .focusRequester(focusRequester)
                    .semantics { contentDescription = "Search prediction markets" },
                placeholder = {
                    Text(
                        text = stringResource(R.string.search_hint),
                        color = Muted,
                    )
                },
                leadingIcon = {
                    Icon(
                        imageVector = Icons.Default.Search,
                        contentDescription = null,
                        tint = Accent,
                    )
                },
                trailingIcon = {
                    if (uiState.query.isNotEmpty()) {
                        IconButton(
                            onClick = { viewModel.updateQuery("") },
                            modifier = Modifier.semantics {
                                contentDescription = "Clear search"
                            },
                        ) {
                            Icon(
                                imageVector = Icons.Default.Clear,
                                contentDescription = "Clear search",
                                tint = Muted,
                            )
                        }
                    }
                },
                singleLine = true,
                shape = MaterialTheme.shapes.large,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = Accent,
                    unfocusedBorderColor = MaterialTheme.colorScheme.outline,
                    cursorColor = Accent,
                ),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                keyboardActions = KeyboardActions(
                    onSearch = { keyboardController?.hide() }
                ),
            )

            // Status / content area
            when {
                uiState.isSyncing -> {
                    SyncingIndicator(
                        marketCount = uiState.marketCount,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 32.dp),
                    )
                }

                uiState.error != null -> {
                    ErrorMessage(
                        message = uiState.error!!,
                        onRetry = { viewModel.retry() },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 32.dp),
                    )
                }

                uiState.query.length < 4 -> {
                    EmptyState(
                        marketCount = uiState.marketCount,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 32.dp),
                    )
                }

                uiState.results.isEmpty() -> {
                    Text(
                        text = stringResource(R.string.no_results),
                        style = MaterialTheme.typography.bodyLarge,
                        color = Muted,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 32.dp)
                            .wrapContentWidth(Alignment.CenterHorizontally),
                    )
                }

                else -> {
                    ResultsList(
                        results = uiState.results,
                        trends = uiState.trends,
                        onResultClick = { result ->
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(result.market.resolvedWebUrl))
                            context.startActivity(intent)
                        },
                        onResultVisible = { result ->
                            viewModel.loadTrend(result)
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun ResultsList(
    results: List<SearchResult>,
    trends: Map<String, MarketTrend>,
    onResultClick: (SearchResult) -> Unit,
    onResultVisible: (SearchResult) -> Unit,
) {
    LazyColumn(
        contentPadding = PaddingValues(vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.fillMaxSize(),
    ) {
        items(
            items = results,
            key = { it.id },
        ) { result ->
            // Trigger trend loading when item becomes visible
            LaunchedEffect(result.id) {
                onResultVisible(result)
            }

            ResultRow(
                result = result,
                trend = trends[result.market.ticker],
                onClick = { onResultClick(result) },
            )
        }
    }
}

@Composable
private fun SyncingIndicator(
    marketCount: Int,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        CircularProgressIndicator(
            color = Accent,
            modifier = Modifier.size(32.dp),
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = stringResource(R.string.syncing_markets),
            style = MaterialTheme.typography.bodyLarge,
            color = Muted,
        )
        if (marketCount > 0) {
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = stringResource(R.string.market_count, marketCount),
                style = MaterialTheme.typography.bodyMedium,
                color = Muted,
            )
        }
    }
}

@Composable
private fun EmptyState(
    marketCount: Int,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = stringResource(R.string.search_prompt),
            style = MaterialTheme.typography.bodyLarge,
            color = Muted,
        )
        if (marketCount > 0) {
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = stringResource(R.string.market_count, marketCount),
                style = MaterialTheme.typography.bodyMedium,
                color = Muted,
            )
        }
    }
}

@Composable
private fun ErrorMessage(
    message: String,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = message,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.error,
        )
        Spacer(modifier = Modifier.height(12.dp))
        Button(
            onClick = onRetry,
            colors = ButtonDefaults.buttonColors(containerColor = Accent),
            modifier = Modifier.semantics { contentDescription = "Retry syncing markets" },
        ) {
            Text("Retry")
        }
    }
}
