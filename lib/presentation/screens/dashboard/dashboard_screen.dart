import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ble_device.dart';
import '../../../main.dart';
import '../../providers/providers.dart';
import '../../widgets/app_bottom_nav.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(connectionStateProvider, (_, next) {
      if (ref.read(demoModeProvider)) return;
      next.whenData((state) {
        if (state == 'disconnected' && mounted) {
          context.go('/scan');
        }
      });
    });

    // Pre-populate mock data in screenshot mode
    if (kScreenshotMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureDemoData();
      });
    }

    // Video tour: show dashboard, then navigate through health screens
    if (kVideoMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureDemoData();
        _runDashboardTour();
      });
    }
  }

  void _ensureDemoData() {
    ref.read(demoModeProvider.notifier).state = true;
    final mock = ref.read(mockRepositoryProvider);
    if (ref.read(connectedDeviceProvider) == null) {
      ref.read(connectedDeviceProvider.notifier).state =
          const BleDevice(id: 'QC-MOCK-001', name: 'QCBand Pro X1', rssi: -52);
    }
    if (ref.read(batteryProvider) == null) {
      ref.read(batteryProvider.notifier).update(mock.mockBattery());
    }
    if (ref.read(sportDataProvider) == null) {
      ref.read(sportDataProvider.notifier).update(mock.mockSportData());
    }
    if (ref.read(deviceInfoProvider) == null) {
      ref.read(deviceInfoProvider.notifier).state = mock.mockDeviceInfo();
    }
    ref.read(featureMapProvider.notifier).state = {
      'bloodOxygen': true,
      'bloodPressure': true,
      'temperature': true,
    };
  }

  Future<void> _runDashboardTour() async {
    // Show dashboard for 4s
    await Future.delayed(const Duration(seconds: 4));

    // Navigate to Heart Rate
    if (mounted) context.go('/heart-rate');

    // Heart rate will auto-start monitoring in video mode
    // Wait 8s for chart to build up
    await Future.delayed(const Duration(seconds: 8));

    // Navigate to Sleep
    if (mounted) context.go('/sleep');
    await Future.delayed(const Duration(seconds: 5));

    // Navigate to SpO2
    if (mounted) context.go('/spo2');
    await Future.delayed(const Duration(seconds: 5));

    // Back to dashboard
    if (mounted) context.go('/dashboard');
  }

  Future<void> _disconnect() async {
    final isDemo = ref.read(demoModeProvider);
    if (!isDemo) {
      try {
        await ref.read(qcbandRepositoryProvider).disconnect();
      } catch (_) {}
    }
    ref.read(connectedDeviceProvider.notifier).state = null;
    ref.read(demoModeProvider.notifier).state = false;
    if (mounted) context.go('/scan');
  }

  Future<void> _refreshData() async {
    if (ref.read(demoModeProvider)) {
      final mock = ref.read(mockRepositoryProvider);
      ref.read(batteryProvider.notifier).update(mock.mockBattery());
      ref.read(sportDataProvider.notifier).update(mock.mockSportData());
      return;
    }
    final repo = ref.read(qcbandRepositoryProvider);
    final queue = ref.read(commandQueueProvider);
    try {
      final battery = await queue.enqueue(() => repo.readBattery());
      ref.read(batteryProvider.notifier).update(battery);

      final sport = await queue.enqueue(() => repo.getCurrentSport());
      ref.read(sportDataProvider.notifier).update(sport);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final battery = ref.watch(batteryProvider);
    final sport = ref.watch(sportDataProvider);
    final deviceInfo = ref.watch(deviceInfoProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text(
          'QCBand Health',
          style: TextStyle(
            color: AppTheme.primary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: AppTheme.onSurfaceVariant,
            onPressed: _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled_rounded),
            color: AppTheme.onSurfaceVariant,
            onPressed: _disconnect,
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(activeIndex: 0),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _DeviceStatusCard(battery: battery, deviceInfo: deviceInfo),
            const SizedBox(height: 24),

            // Today's Activity
            Text("Today's Activity",
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            _ActivityGrid(sport: sport),
            const SizedBox(height: 24),

            // Health Metrics
            Text('Health Metrics',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            _MetricRow(
              icon: Icons.favorite_rounded,
              iconColor: AppTheme.heartRateColor,
              title: 'Heart Rate',
              subtitle: '72 BPM - Just now',
              onTap: () => context.go('/heart-rate'),
            ),
            const SizedBox(height: 12),
            _MetricRow(
              icon: Icons.bedtime_rounded,
              iconColor: AppTheme.sleepColor,
              title: 'Sleep',
              subtitle: '6h 53m - Last night',
              onTap: () => context.go('/sleep'),
            ),
            const SizedBox(height: 12),
            _MetricRow(
              icon: Icons.water_drop_rounded,
              iconColor: AppTheme.spo2Color,
              title: 'Blood Oxygen (SpO2)',
              subtitle: '98% - Optimal',
              onTap: () => context.go('/spo2'),
            ),
            const SizedBox(height: 24),

            const _InsightCard(),
          ],
        ),
      ),
    );
  }
}

class _DeviceStatusCard extends StatelessWidget {
  final dynamic battery;
  final dynamic deviceInfo;

  const _DeviceStatusCard({this.battery, this.deviceInfo});

  @override
  Widget build(BuildContext context) {
    final level = battery?.level ?? 0;
    final charging = battery?.charging ?? false;
    final deviceName = 'QCBand Pro X1';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.secondaryContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              charging
                  ? Icons.battery_charging_full_rounded
                  : level > 20
                      ? Icons.battery_full_rounded
                      : Icons.battery_1_bar_rounded,
              color: level > 20 ? AppTheme.batteryColor : AppTheme.error,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEVICE STATUS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  deviceName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  charging
                      ? 'Charging - $level%'
                      : '$level% Battery Remaining',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.batteryColor,
                  ),
                ),
              ],
            ),
          ),
          if (deviceInfo != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('HW: ${deviceInfo.hardware}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.outline)),
                Text('SW: ${deviceInfo.software}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.outline)),
              ],
            ),
        ],
      ),
    );
  }
}

class _ActivityGrid extends StatelessWidget {
  final dynamic sport;

  const _ActivityGrid({this.sport});

  @override
  Widget build(BuildContext context) {
    final steps = sport?.steps ?? 0;
    final calories = sport?.calories ?? 0.0;
    final distance = sport?.distance ?? 0;
    final goalPct = ((steps / 10000) * 100).clamp(0, 100).round();

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ActivityTile(
                icon: Icons.directions_walk_rounded,
                iconColor: AppTheme.stepsColor,
                value: '$steps',
                label: 'STEPS',
                badge: '$goalPct%',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ActivityTile(
                icon: Icons.local_fire_department_rounded,
                iconColor: AppTheme.caloriesColor,
                value: '${calories.toInt()}',
                unit: 'kcal',
                label: 'CALORIES',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ActivityTile(
          icon: Icons.straighten_rounded,
          iconColor: AppTheme.distanceColor,
          value: (distance / 1000).toStringAsFixed(1),
          unit: 'km',
          label: 'DISTANCE',
          wide: true,
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String? unit;
  final String label;
  final String? badge;
  final bool wide;

  const _ActivityTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    this.unit,
    required this.label,
    this.badge,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: iconColor),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryFixed.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: wide ? 12 : 36),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                  children: [
                    if (unit != null)
                      TextSpan(
                        text: ' $unit',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MetricRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            top: 8,
            child: Icon(
              Icons.trending_up_rounded,
              size: 96,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DAILY INSIGHT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),
              const SizedBox(
                width: 240,
                child: Text(
                  'Your recovery rate is 15% higher today.',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Great job maintaining a consistent sleep schedule this week!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
