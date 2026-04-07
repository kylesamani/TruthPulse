package com.truthpulse.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import com.truthpulse.data.TrendPoint

@Composable
fun SparklineChart(
    points: List<TrendPoint>,
    delta: Double?,
    modifier: Modifier = Modifier,
) {
    if (points.size < 2) return

    val lineColor = when {
        delta == null -> Accent
        delta > 0 -> Color(0xFF34C759) // Green for positive
        delta < 0 -> Color(0xFFFF3B30) // Red for negative
        else -> Accent
    }

    val description = when {
        delta == null -> "Trend chart"
        delta > 0 -> "Trend up by ${String.format("%.1f", delta)} cents"
        delta < 0 -> "Trend down by ${String.format("%.1f", -delta)} cents"
        else -> "Trend flat"
    }

    Canvas(
        modifier = modifier
            .fillMaxSize()
            .semantics { contentDescription = description }
    ) {
        val values = points.map { it.value }
        val minVal = values.min()
        val maxVal = values.max()
        val range = if (maxVal - minVal < 0.001) 1.0 else maxVal - minVal

        val padding = 2f
        val drawWidth = size.width - padding * 2
        val drawHeight = size.height - padding * 2

        val path = Path()
        points.forEachIndexed { index, point ->
            val x = padding + (index.toFloat() / (points.size - 1).toFloat()) * drawWidth
            val y = padding + drawHeight - ((point.value - minVal) / range).toFloat() * drawHeight

            if (index == 0) {
                path.moveTo(x, y)
            } else {
                path.lineTo(x, y)
            }
        }

        drawPath(
            path = path,
            color = lineColor,
            style = Stroke(
                width = 2f,
                cap = StrokeCap.Round,
                join = StrokeJoin.Round,
            )
        )

        // Draw endpoint dot
        val lastPoint = points.last()
        val lastX = padding + drawWidth
        val lastY = padding + drawHeight - ((lastPoint.value - minVal) / range).toFloat() * drawHeight
        drawCircle(
            color = lineColor,
            radius = 3f,
            center = Offset(lastX, lastY),
        )
    }
}
