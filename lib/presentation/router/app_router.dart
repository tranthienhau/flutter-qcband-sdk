import 'package:go_router/go_router.dart';
import '../screens/scan/scan_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/heart_rate/heart_rate_screen.dart';
import '../screens/sleep/sleep_screen.dart';
import '../screens/spo2/spo2_screen.dart';

import '../../../main.dart';

final appRouter = GoRouter(
  initialLocation: kScreenshotMode ? '/dashboard' : '/scan',
  routes: [
    GoRoute(
      path: '/scan',
      builder: (context, state) => const ScanScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/heart-rate',
      builder: (context, state) => const HeartRateScreen(),
    ),
    GoRoute(
      path: '/sleep',
      builder: (context, state) => const SleepScreen(),
    ),
    GoRoute(
      path: '/spo2',
      builder: (context, state) => const Spo2Screen(),
    ),
  ],
);
