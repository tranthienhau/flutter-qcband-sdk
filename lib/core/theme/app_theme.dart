import 'package:flutter/material.dart';

/// Vitality Core design system.
/// "Clinical Optimism" - light, vibrant wellness theme: Energetic Coral primary,
/// Deep Violet for sleep/recovery, Teal for activity. White cards on a near-white
/// canvas, Inter typography, soft ambient shadows, generous rounding.
class AppTheme {
  AppTheme._();

  // -- Core palette (Material 3 tonal roles) --
  static const primary = Color(0xFFB32822); // Energetic Coral (heart, primary actions)
  static const primaryContainer = Color(0xFFFF5F52);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryFixed = Color(0xFFFFDAD5);

  static const secondary = Color(0xFF4D41DF); // Deep Violet (sleep, recovery)
  static const mint = Color(0xFF00A891); // Teal accent (activity, SpO2)
  static const mintDim = Color(0xFF44DDC1);
  static const secondaryContainer = Color(0xFFC4C0FF); // Light violet tonal

  static const tertiary = Color(0xFF006B5C); // Teal
  static const tertiaryContainer = Color(0xFF00A891);

  static const error = Color(0xFFBA1A1A);

  static const background = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF); // surface-container-lowest (cards)
  static const surfaceLow = Color(0xFFF3F4F5);
  static const surfaceHigh = Color(0xFFE7E8E9);
  static const surfaceHighest = Color(0xFFE1E3E4);

  static const onSurface = Color(0xFF191C1D);
  static const onSurfaceVariant = Color(0xFF5A413D); // warm neutral
  static const outline = Color(0xFF8E706C);
  static const outlineVariant = Color(0xFFE2BEBA); // warm hairline

  // Ambient "Natural Light" card shadow (per design spec).
  static const cardShadow = BoxShadow(
    color: Color(0x14191C1D), // rgba(25,28,29,0.08)
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  static BoxDecoration cardDecoration({Color? color}) => BoxDecoration(
        color: color ?? surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineVariant.withValues(alpha: 0.5)),
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
          tertiaryContainer: tertiaryContainer,
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
          shadowColor: Colors.black.withValues(alpha: 0.08),
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

  // -- Health metric accent colors (semantic, per design) --
  static const heartRateColor = primary; // Coral
  static const sleepColor = secondary; // Violet
  static const spo2Color = tertiary; // Teal
  static const stepsColor = Color(0xFFEA580C); // Orange
  static const caloriesColor = primary; // Coral
  static const distanceColor = Color(0xFF2563EB); // Blue
  static const activeColor = Color(0xFF7C3AED); // Purple
  static const batteryColor = tertiary; // Teal (connected)

  // -- Sleep stage colors (violet/teal family) --
  static const deepSleepColor = Color(0xFF3622CA); // deep violet
  static const lightSleepColor = Color(0xFF675DF9); // violet
  static const remSleepColor = Color(0xFF00A891); // teal
  static const awakeColor = Color(0xFFF59E0B); // amber
}
