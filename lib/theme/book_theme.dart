import 'package:flutter/material.dart';

ThemeData bookTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E4D3B),
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xFF9CD3B6) : const Color(0xFF1E4D3B),
        onPrimary: dark ? const Color(0xFF123B29) : Colors.white,
        surface: dark ? const Color(0xFF222823) : Colors.white,
        onSurface: dark ? const Color(0xFFE5EEE8) : Colors.black87,
        onSurfaceVariant: dark
            ? const Color(0xFFBBC7BE)
            : const Color(0xFF61685F),
        outlineVariant: dark
            ? const Color(0xFF424D46)
            : const Color(0xFFD8DDD8),
      );
  final background = dark ? const Color(0xFF141A16) : const Color(0xFFF5F5F0);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'serif',
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: scheme.surface),
  );
}

extension BookThemeContext on BuildContext {
  BookColors get bookColors => BookColors(Theme.of(this));
}

/// Semantic colors shared by custom cards, search fields and book screens.
class BookColors {
  const BookColors(this.theme);
  final ThemeData theme;
  bool get dark => theme.brightness == Brightness.dark;
  Color get background => theme.scaffoldBackgroundColor;
  Color get adminBackground => dark ? background : const Color(0xFFF5F1E8);
  Color get surface => theme.colorScheme.surface;
  Color get text => theme.colorScheme.onSurface;
  Color get secondaryText => theme.colorScheme.onSurfaceVariant;
  Color get mutedText => theme.colorScheme.onSurfaceVariant;
  Color get border => theme.colorScheme.outlineVariant;
  Color get primary => theme.colorScheme.primary;
  Color get adminPrimary => dark ? primary : const Color(0xFF1F3A2E);
  Color get onPrimary => theme.colorScheme.onPrimary;
}
