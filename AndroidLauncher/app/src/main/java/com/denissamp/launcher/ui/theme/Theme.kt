package com.denissamp.launcher.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val DarkColorScheme = darkColorScheme(
    primary = Color(0xFFFF8F00),
    secondary = Color(0xFF1E88E5),
    background = Color(0xFF101418),
    surface = Color(0xFF151A20),
    onPrimary = Color.Black,
    onSecondary = Color.White,
    onSurface = Color.White
)

@Composable
fun SampLauncherTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = DarkColorScheme,
        typography = MaterialTheme.typography,
        content = content
    )
}
