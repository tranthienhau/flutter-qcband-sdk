import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/providers.dart';
import 'presentation/router/app_router.dart';

/// Set to true to auto-start in demo mode for screenshots.
const kScreenshotMode = false;

/// Set to true to auto-tour all screens for video recording.
const kVideoMode = false;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        if (kScreenshotMode || kVideoMode)
          demoModeProvider.overrideWith((ref) => true),
      ],
      child: const QCBandApp(),
    ),
  );
}

class QCBandApp extends StatelessWidget {
  const QCBandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'QCBand Health',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
