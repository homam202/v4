import 'package:flutter/material.dart';

/// TerraMag brand palette: Deep Navy (background), Cyan (waves), Gold (detections).
class TM {
  static const navy = Color(0xFF0A1628);
  static const navySurface = Color(0xFF12223D);
  static const cyan = Color(0xFF00E5FF);
  static const gold = Color(0xFFFFC107);
  static const hot = Color(0xFFFF1744);
  static const grey = Color(0xFF8A94A6);
}

ThemeData terraMagTheme() {
  final scheme = const ColorScheme.dark(
    primary: TM.cyan,
    secondary: TM.gold,
    surface: TM.navySurface,
    error: TM.hot,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: TM.navy,
    appBarTheme: const AppBarTheme(backgroundColor: TM.navy, elevation: 0),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: TM.navySurface,
      indicatorColor: TM.cyan.withOpacity(0.2),
      labelTextStyle: WidgetStatePropertyAll(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: TM.navySurface.withOpacity(0.92),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    // Large, high-contrast text for outdoor/sunlight use.
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 96, fontWeight: FontWeight.w800, color: Colors.white),
    ),
  );
}
