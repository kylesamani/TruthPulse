package com.truthpulse.data

enum class TrendWindow(val label: String, val durationSeconds: Long, val intervalMinutes: Int) {
    ONE_DAY("1D", 60L * 60 * 24, 1),
    SEVEN_DAYS("7D", 60L * 60 * 24 * 7, 60),
    THIRTY_DAYS("30D", 60L * 60 * 24 * 30, 1440);
}

data class TrendPoint(
    val timestampMillis: Long,
    val value: Double,
)

data class MarketTrend(
    val marketTicker: String,
    val window: TrendWindow,
    val points: List<TrendPoint>,
    val delta: Double?,
    val updatedAtMillis: Long,
)
