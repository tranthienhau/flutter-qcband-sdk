import 'package:flutter/material.dart';

/// Vitality Health Systems design system.
/// Light, clinical-yet-energetic: Medical Blue primary + Mint accent,
/// white cards on a near-white canvas, Inter typography, 16px rounding.
class AppTheme {
  AppTheme._();

  // -- Core palette (Material 3 tonal roles) --
  static const primary = Color(0xFF0058BC); // Medical Blue
  static const primaryContainer = Color(0xFF0070EB);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryFixed = Color(0xFFD8E2FF);

  static const secondary = Color(0xFF006B5A); // Mint text/icon
  static const mint = Color(0xFF00D1B2); // Brand Mint fill
  static const mintDim = Color(0xFF2CDEBF);
  static const secondaryContainer = Color(0xFF54F8D7);

  static const tertiary = Color(0xFFBC000A); // Alert / heart red
  static const tertiaryContainer = Color(0xFFE2241F);

  static const error = Color(0xFFBA1A1A);

  static const background = Color(0xFFFAF9FE);
  static const surface = Color(0xFFFFFFFF); // surface-container-lowest (cards)
  static const surfaceLow = Color(0xFFF4F3F8);
  static const surfaceHigh = Color(0xFFE9E7ED);
  static const surfaceHighest = Color(0xFFE3E2E7);

  static const onSurface = Color(0xFF1A1B1F);
  static const onSurfaceVariant = Color(0xFF414755);
  static const outline = Color(0xFF717786);
  static const outlineVariant = Color(0xFFC1C6D7);

  // Ambient card shadow (Z-2 in the design spec).
  static const cardShadow = BoxShadow(
    color: Color(0x0D000000), // rgba(0,0,0,0.05)
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  static BoxDecoration cardDecoration({Color? color}) => BoxDecoration(
        color: color ?? surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineVariant.withValues(alpha: 0.3)),
        boxShadow: const [cardShadow],
      );

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.light(
          primary: primary,
          onPrimary: onPrimary,
          primaryContainer: primaryContainer,
          secondary: secondary,
          secondaryContainer: secondaryContainer,
          tertiary: tertiary,
          error: error,
          surface: surface,
          onSurface: onSurface,
          onSurfaceVariant: onSurfaceVariant,
          outline: outline,
          outlineVariant: outlineVariant,
        ),
        scaffoldBackgroundColor: background,
        cardColor: surface,
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          surfaceTintColor: Colors.transparent,
          foregroundColor: primary,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: primary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: IconThemeData(color: primary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: onPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
        cardTheme: CardThemeData(
          color: surface,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black.withValues(alpha: 0.05),
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: onSurface,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: onSurface,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
          bodyLarge: TextStyle(fontSize: 17, color: onSurface),
          bodyMedium: TextStyle(fontSize: 15, color: onSurfaceVariant),
          labelLarge: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: onSurfaceVariant,
          ),
        ),
      );

  // -- Health metric accent colors (mapped onto the new palette) --
  static const heartRateColor = tertiary; // #BC000A
  static const sleepColor = primary; // #0058BC
  static const spo2Color = mint; // #00D1B2
  static const stepsColor = primary;
  static const caloriesColor = tertiary;
  static const distanceColor = secondary;
  static const batteryColor = secondary;

  // -- Sleep stage colors --
  static const deepSleepColor = Color(0xFF1D4ED8); // blue-700
  static const lightSleepColor = Color(0xFF60A5FA); // blue-400
  static const remSleepColor = Color(0xFFC084FC); // purple-400
  static const awakeColor = Color(0xFFFB923C); // orange-400
}
