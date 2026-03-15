import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF330DF2);
  static const Color backgroundLight = Color(0xFFF7F7FB);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: primary,
        surface: Colors.white,
        background: backgroundLight,
      ),
      scaffoldBackgroundColor: backgroundLight,
      textTheme: ThemeData.light().textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundLight,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF121118),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFEFEFF6)),
        ),
      ),
    );
  }
}
