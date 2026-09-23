import 'package:flutter/material.dart';

class AppTheme {
  // Color Palette from your screenshot template
  static const Color backgroundDark = Color(0xFF0B0710);
  static const Color surfaceDark = Color(0xFF140F1D);
  static const Color cardColor = Color(0xFF1C1427);

  // Gradient for Primary Buttons & Highlights
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFC04848), Color(0xFF480048)], // Or Pink to Violet gradient
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color primaryPink = Color(0xFFE6007A);
  static const Color accentViolet = Color(0xFF9C27B0);
  static const Color accentGold = Color(0xFFFFD700);

  // Material Dark Theme Data
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      primaryColor: primaryPink,
      colorScheme: const ColorScheme.dark(
        primary: primaryPink,
        surface: surfaceDark,
        secondary: accentViolet,
      ),
      fontFamily: 'sans-serif',
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: accentGold,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}