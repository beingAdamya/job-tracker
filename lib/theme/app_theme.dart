import 'package:flutter/material.dart';
import '../models/app_settings.dart';

// How different two colours are: 1 = identical, 21 = black on white.
// 4.5 or more is comfortable to read.
double contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

// Builds the app's look from the settings. `base` is light or dark;
// custom colours (if switched on) are laid over that base.
ThemeData buildTheme(AppSettings s, Brightness base) {
  final custom = s.customEnabled;
  final accent = (custom && s.customAccent != null)
      ? Color(s.customAccent!)
      : Colors.indigo;

  var scheme = ColorScheme.fromSeed(seedColor: accent, brightness: base);

  if (custom) {
    final bg = s.customBg != null ? Color(s.customBg!) : scheme.surface;
    final text = s.customText != null ? Color(s.customText!) : scheme.onSurface;

    // A little of the text colour mixed into the background gives
    // slightly different shades for cards, dialogs and borders
    Color mix(double amount) =>
        Color.alphaBlend(text.withValues(alpha: amount), bg);

    scheme = scheme.copyWith(
      surface: bg,
      onSurface: text,
      onSurfaceVariant: mix(0.75),
      outline: mix(0.5),
      outlineVariant: mix(0.2),
      surfaceContainerLowest: mix(0.02),
      surfaceContainerLow: mix(0.05),
      surfaceContainer: mix(0.08),
      surfaceContainerHigh: mix(0.11),
      surfaceContainerHighest: mix(0.14),
    );
  }

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
  );
}