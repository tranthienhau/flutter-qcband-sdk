import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ble_device.dart';
import '../../../main.dart';
import '../../providers/providers.dart';

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
    final device = ref.watch(connectedDeviceProvider);
    final battery = ref.watch(batteryProvider);
    final sport = ref.watch(sportDataProvider);
    final deviceInfo = ref.watch(deviceInfoProvider);
    final features = ref.watch(featureMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(device?.name ?? 'QCBand'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled),
            onPressed: _disconnect,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Battery & Device Info
            _BatteryDeviceCard(
              battery: battery,
              deviceInfo: deviceInfo,
            ),
            const SizedBox(height: 16),

            // Activity summary
            _ActivityCard(sport: sport),
            const SizedBox(height: 16),

            // Navigation cards
            Text(
              'Health Metrics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _NavCard(
                    icon: Icons.favorite,
                    label: 'Heart Rate',
                    color: AppTheme.heartRateColor,
                    onTap: () => context.go('/heart-rate'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NavCard(
                    icon: Icons.bedtime,
                    label: 'Sleep',
                    color: AppTheme.sleepColor,
                    onTap: () => context.go('/sleep'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _NavCard(
              icon: Icons.water_drop,
              label: 'Blood Oxygen (SpO2)',
              color: AppTheme.spo2Color,
              onTap: () => context.go('/spo2'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatteryDeviceCard extends StatelessWidget {
  final dynamic battery;
  final dynamic deviceInfo;

  const _BatteryDeviceCard({this.battery, this.deviceInfo});

  @override
  Widget build(BuildContext context) {
    final level = battery?.level ?? 0;
    final charging = battery?.charging ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Battery indicator
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.batteryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    charging
                        ? Icons.battery_charging_full
                        : level > 50
                            ? Icons.battery_full
                            : level > 20
                                ? Icons.battery_3_bar
                                : Icons.battery_1_bar,
                    color: level > 20 ? AppTheme.batteryColor : AppTheme.heartRateColor,
                    size: 24,
                  ),
                  Text(
                    '$level%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: level > 20 ? AppTheme.batteryColor : AppTheme.heartRateColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    charging ? 'Charging' : 'Battery',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  if (deviceInfo != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'HW: ${deviceInfo.hardware}  SW: ${deviceInfo.software}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final dynamic sport;

  const _ActivityCard({this.sport});

  @override
  Widget build(BuildContext context) {
    final steps = sport?.steps ?? 0;
    final calories = sport?.calories ?? 0.0;
    final distance = sport?.distance ?? 0;
    final activeMinutes = sport?.activeMinutes ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today\'s Activity',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    icon: Icons.directions_walk,
                    label: 'Steps',
                    value: '$steps',
                    color: AppTheme.stepsColor,
                  ),
                ),
                Expanded(
                  child: _MetricTile(
                    icon: Icons.local_fire_department,
                    label: 'Calories',
                    value: '${calories.toInt()} kcal',
                    color: AppTheme.caloriesColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    icon: Icons.straighten,
                    label: 'Distance',
                    value: '${(distance / 1000).toStringAsFixed(1)} km',
                    color: AppTheme.distanceColor,
                  ),
                ),
                Expanded(
                  child: _MetricTile(
                    icon: Icons.timer,
                    label: 'Active',
                    value: '$activeMinutes min',
                    color: AppTheme.sleepColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
