import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_qcband_sdk/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // The app's real BLE platform channels have no native implementation in the
  // demo/screenshot build. Stub them so StreamProvider activation does not
  // throw MissingPluginException and fail the test. Demo mode supplies all data.
  setUpAll(() {
    const methods = MethodChannel('com.tranthienhau.qcband/methods');
    const events = MethodChannel('com.tranthienhau.qcband/events');
    final messenger = binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(methods, (_) async => null);
    messenger.setMockMethodCallHandler(events, (_) async => null);

    // The native BLE plugin is absent in this demo build; ignore the benign
    // MissingPluginException raised when StreamProviders activate the channels.
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is MissingPluginException) return;
      prior?.call(details);
    };
  });

  // Pump fixed-duration frames (screens have always-on animation; do not
  // pumpAndSettle or the test will hang waiting for them to stop).
  Future<void> pumpFor(WidgetTester tester, int ms) async {
    const step = 100;
    for (var elapsed = 0; elapsed < ms; elapsed += step) {
      await tester.pump(const Duration(milliseconds: step));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot(name);
  }

  testWidgets('capture redesigned screens', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: QCBandApp()));
    await pumpFor(tester, 1500); // dashboard seeds demo data on first frame

    // 01 - Dashboard
    await shot(tester, '01_dashboard');

    // 02 - Heart Rate (auto-monitors in screenshot mode; let chart build up)
    await tester.tap(find.text('Heart Rate'));
    await pumpFor(tester, 5000);
    await shot(tester, '02_heart_rate');

    // Hop via bottom nav. The target icon is unique on each source screen.
    // 04 - Blood Oxygen (Activity tab; water_drop only in nav on heart-rate)
    await tester.tap(find.byIcon(Icons.water_drop_rounded));
    await pumpFor(tester, 1200);
    await shot(tester, '04_spo2');

    // 03 - Sleep (Sleep tab; bedtime only in nav on spo2)
    await tester.tap(find.byIcon(Icons.bedtime_rounded));
    await pumpFor(tester, 1200);
    await shot(tester, '03_sleep');

    // Back to dashboard (home only in nav on sleep), then disconnect to scanner.
    await tester.tap(find.byIcon(Icons.home_rounded));
    await pumpFor(tester, 800);

    // 05 - Scanner (disconnect routes to /scan; demo scan auto-populates)
    await tester.tap(find.byIcon(Icons.bluetooth_disabled_rounded));
    await pumpFor(tester, 3000);
    await shot(tester, '05_scan');
  });
}
