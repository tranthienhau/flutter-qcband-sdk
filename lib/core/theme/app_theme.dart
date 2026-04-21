import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const _primaryColor = Color(0xFF6C5CE7);
  static const _secondaryColor = Color(0xFF00B894);
  static const _errorColor = Color(0xFFD63031);
  static const _surfaceColor = Color(0xFF1E1E2E);
  static const _backgroundColor = Color(0xFF0F0F1A);
  static const _cardColor = Color(0xFF2A2A3E);

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: _primaryColor,
          secondary: _secondaryColor,
          error: _errorColor,
          surface: _surfaceColor,
        ),
        scaffoldBackgroundColor: _backgroundColor,
        cardColor: _cardColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: _backgroundColor,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        cardTheme: CardThemeData(
          color: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          headlineMedium: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: Colors.white70),
          bodyMedium: TextStyle(fontSize: 14, color: Colors.white60),
        ),
      );

  // Health metric colors
  static const heartRateColor = Color(0xFFFF6B6B);
  static const sleepColor = Color(0xFF748FFC);
  static const spo2Color = Color(0xFF51CF66);
  static const stepsColor = Color(0xFFFFD43B);
  static const caloriesColor = Color(0xFFFF922B);
  static const distanceColor = Color(0xFF20C997);
  static const batteryColor = Color(0xFF69DB7C);

  // Sleep stage colors
  static const deepSleepColor = Color(0xFF364FC7);
  static const lightSleepColor = Color(0xFF748FFC);
  static const remSleepColor = Color(0xFFDA77F2);
  static const awakeColor = Color(0xFFFF6B6B);
}
