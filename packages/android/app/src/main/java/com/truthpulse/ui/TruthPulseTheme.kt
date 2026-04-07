package com.truthpulse.ui

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

// Brand colors
val Accent = Color(0xFF4ECDC4)
val AccentSoft = Color(0x264ECDC4) // 15% opacity
val Ink = Color(0xFF1A1A1A)
val Muted = Color(0xFF8E8E93)
val CardLight = Color(0xFFF8F8F8)
val CardDark = Color(0xFF1E1E1E)
val SurfaceLight = Color(0xFFFFFFFF)
val SurfaceDark = Color(0xFF121212)

// Design tokens
val CardRadius = 16 // dp
val OddsTextStyle = TextStyle(fontSize = 20.sp, fontWeight = FontWeight.Bold)
val TitleTextStyle = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
val SubtitleTextStyle = TextStyle(fontSize = 12.sp)

private val LightColorScheme = lightColorScheme(
    primary = Accent,
    onPrimary = Color.White,
    primaryContainer = AccentSoft,
    onPrimaryContainer = Ink,
    secondary = Accent,
    background = SurfaceLight,
    onBackground = Ink,
    surface = SurfaceLight,
    onSurface = Ink,
    surfaceVariant = CardLight,
    onSurfaceVariant = Muted,
    outline = Color(0xFFE0E0E0),
)

private val DarkColorScheme = darkColorScheme(
    primary = Accent,
    onPrimary = Ink,
    primaryContainer = AccentSoft,
    onPrimaryContainer = Color.White,
    secondary = Accent,
    background = SurfaceDark,
    onBackground = Color.White,
    surface = SurfaceDark,
    onSurface = Color.White,
    surfaceVariant = CardDark,
    onSurfaceVariant = Muted,
    outline = Color(0xFF3A3A3A),
)

@Composable
fun TruthPulseTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    // Explicitly disable dynamicColor to preserve brand mint
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography(
            bodyLarge = TextStyle(fontSize = 14.sp),
            bodyMedium = TextStyle(fontSize = 12.sp),
            titleMedium = TitleTextStyle,
            labelLarge = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Medium),
        ),
        content = content,
    )
}
