package com.truthpulse.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.truthpulse.data.MarketTrend
import com.truthpulse.data.SearchResult
import com.truthpulse.data.TextHighlightRange

@Composable
fun ResultRow(
    result: SearchResult,
    trend: MarketTrend?,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val market = result.market
    val odds = result.emphasizedOdds
    val outcomeLabel = result.emphasizedOutcomeLabel

    val accessibilityLabel = buildString {
        append(market.title)
        if (odds != null) append(", $odds percent $outcomeLabel")
        market.category?.let { append(", category $it") }
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(CardRadius.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .clickable(onClick = onClick)
            .padding(12.dp)
            .semantics { contentDescription = accessibilityLabel }
            .heightIn(min = 48.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Odds badge
        if (odds != null) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(AccentSoft)
                    .padding(horizontal = 10.dp, vertical = 6.dp)
                    .widthIn(min = 48.dp),
            ) {
                Text(
                    text = "$odds%",
                    style = OddsTextStyle,
                    color = Accent,
                )
                Text(
                    text = outcomeLabel,
                    style = SubtitleTextStyle.copy(fontSize = 10.sp),
                    color = Muted,
                )
            }

            Spacer(modifier = Modifier.width(12.dp))
        }

        // Title + subtitle + category
        Column(
            modifier = Modifier.weight(1f),
        ) {
            HighlightedText(
                text = market.title,
                highlights = result.titleHighlights,
                style = TitleTextStyle,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 2,
            )

            market.subtitle?.let { subtitle ->
                Spacer(modifier = Modifier.height(2.dp))
                HighlightedText(
                    text = subtitle,
                    highlights = result.subtitleHighlights,
                    style = SubtitleTextStyle,
                    color = Muted,
                    maxLines = 1,
                )
            }

            market.category?.let { category ->
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = category.uppercase(),
                    style = SubtitleTextStyle.copy(
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Medium,
                        letterSpacing = 0.5.sp,
                    ),
                    color = Accent,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }

        // Sparkline
        if (trend != null && trend.points.size >= 2) {
            Spacer(modifier = Modifier.width(8.dp))
            Box(
                modifier = Modifier
                    .width(56.dp)
                    .height(28.dp),
            ) {
                SparklineChart(
                    points = trend.points,
                    delta = trend.delta,
                )
            }
        }
    }
}

@Composable
private fun HighlightedText(
    text: String,
    highlights: List<TextHighlightRange>,
    style: androidx.compose.ui.text.TextStyle,
    color: androidx.compose.ui.graphics.Color,
    maxLines: Int,
) {
    if (highlights.isEmpty()) {
        Text(
            text = text,
            style = style,
            color = color,
            maxLines = maxLines,
            overflow = TextOverflow.Ellipsis,
        )
        return
    }

    val annotated = buildAnnotatedString {
        withStyle(SpanStyle(color = color)) {
            append(text)
        }

        for (range in highlights) {
            val end = minOf(range.start + range.length, text.length)
            if (range.start < text.length) {
                addStyle(
                    SpanStyle(
                        color = Accent,
                        fontWeight = FontWeight.Bold,
                    ),
                    start = range.start,
                    end = end,
                )
            }
        }
    }

    Text(
        text = annotated,
        style = style,
        maxLines = maxLines,
        overflow = TextOverflow.Ellipsis,
    )
}
