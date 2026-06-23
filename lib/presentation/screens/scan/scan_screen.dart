import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ble_device.dart';
import '../../../main.dart';
import '../../providers/providers.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with SingleTickerProviderStateMixin {
  List<BleDevice> _mockDevices = [];
  bool _mockScanning = false;
  bool _mockConnecting = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Listen for connection state changes (real BLE only)
    ref.listenManual(connectionStateProvider, (_, next) {
      if (ref.read(demoModeProvider)) return;
      next.whenData((state) async {
        if (state == 'connected') {
          await _onConnected();
        }
      });
    });

    // Auto-start demo mode for screenshots
    if (kScreenshotMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startDemoScan();
      });
    }

    // Auto-tour for video recording
    if (kVideoMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runVideoTour();
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _runVideoTour() async {
    // 1. Show empty scan screen for 2s
    await Future.delayed(const Duration(seconds: 2));

    // 2. Trigger demo scan, show devices appearing
    await _startDemoScan();
    await Future.delayed(const Duration(seconds: 3));

    // 3. Connect to first device
    if (_mockDevices.isNotEmpty) {
      await _connectDemoDevice(_mockDevices.first);
      // Dashboard auto-navigates, then continue tour from there
    }
  }

  Future<void> _onConnected() async {
    try {
      final repo = ref.read(qcbandRepositoryProvider);
      final queue = ref.read(commandQueueProvider);
      final features = await queue.enqueue(() => repo.syncTime());
      ref.read(featureMapProvider.notifier).state = features;

      final battery = await queue.enqueue(() => repo.readBattery());
      ref.read(batteryProvider.notifier).update(battery);

      final sport = await queue.enqueue(() => repo.getCurrentSport());
      ref.read(sportDataProvider.notifier).update(sport);

      final deviceInfo = await queue.enqueue(() => repo.getDeviceVersion());
      ref.read(deviceInfoProvider.notifier).state = deviceInfo;

      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }

  Future<void> _startScan() async {
    ref.read(isScanningProvider.notifier).state = true;
    try {
      await ref.read(qcbandRepositoryProvider).startScan(timeout: 15);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    }
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) ref.read(isScanningProvider.notifier).state = false;
    });
  }

  Future<void> _connectToDevice(BleDevice device) async {
    ref.read(connectedDeviceProvider.notifier).state = device;
    ref.read(isScanningProvider.notifier).state = false;
    try {
      await ref.read(qcbandRepositoryProvider).stopScan();
      await ref.read(qcbandRepositoryProvider).connect(device.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      }
    }
  }

  // -- Demo Mode --

  Future<void> _startDemoScan() async {
    setState(() => _mockScanning = true);
    final mock = ref.read(mockRepositoryProvider);
    final devices = await mock.mockScan();
    if (mounted) {
      setState(() {
        _mockDevices = devices;
        _mockScanning = false;
      });
    }
  }

  Future<void> _connectDemoDevice(BleDevice device) async {
    setState(() => _mockConnecting = true);
    ref.read(demoModeProvider.notifier).state = true;

    final mock = ref.read(mockRepositoryProvider);
    await mock.mockConnect();

    // Populate all providers with mock data
    final features = await mock.mockSyncTime();
    ref.read(featureMapProvider.notifier).state = features;
    ref.read(connectedDeviceProvider.notifier).state = device;
    ref.read(batteryProvider.notifier).update(mock.mockBattery());
    ref.read(sportDataProvider.notifier).update(mock.mockSportData());
    ref.read(deviceInfoProvider.notifier).state = mock.mockDeviceInfo();

    if (mounted) {
      setState(() => _mockConnecting = false);
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isScanning = ref.watch(isScanningProvider);
    final scanResults = ref.watch(scanResultsProvider);
    final connectionState = ref.watch(connectionStateProvider);
    final isDemo = ref.watch(demoModeProvider);

    final isConnecting = _mockConnecting ||
        (connectionState.whenOrNull(
              data: (state) => state == 'connecting',
            ) ??
            false);

    final scanning = _mockScanning || isScanning;

    // Combine real scan results with mock devices
    final realDevices = scanResults.whenOrNull(data: (d) => d) ?? [];
    final allDevices =
        isDemo || _mockDevices.isNotEmpty ? _mockDevices : realDevices;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VitalHealth'),
        titleTextStyle: const TextStyle(
          color: AppTheme.primary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 180),
            children: [
              // Intro
              Column(
                children: [
                  Text(
                    'VitalHealth Scanner',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isConnecting
                        ? 'Connecting to device...'
                        : scanning
                            ? 'Scanning for nearby devices...'
                            : 'Tap Scan or use Demo Mode to find devices',
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Pulse animation
              _ScanPulse(controller: _pulseController, active: scanning),
              const SizedBox(height: 32),

              // Devices
              if (allDevices.isNotEmpty) ...[
                Text(
                  'NEARBY DEVICES',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                ...allDevices.map(
                  (device) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DeviceCard(
                      device: device,
                      onTap: isConnecting
                          ? null
                          : () => _mockDevices.isNotEmpty
                              ? _connectDemoDevice(device)
                              : _connectToDevice(device),
                    ),
                  ),
                ),
              ] else if (!scanning) ...[
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'No devices found yet.\nMake sure your QCBand is nearby.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ],
          ),

          // Sticky bottom controls
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Demo',
                    icon: Icons.play_circle_fill_rounded,
                    color: AppTheme.secondary,
                    onPressed:
                        scanning || isConnecting ? null : _startDemoScan,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ActionButton(
                    label: scanning ? 'Scanning...' : 'Scan',
                    icon: Icons.bluetooth_rounded,
                    color: AppTheme.primary,
                    loading: scanning,
                    onPressed: scanning || isConnecting ? null : _startScan,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanPulse extends StatelessWidget {
  final AnimationController controller;
  final bool active;

  const _ScanPulse({required this.controller, required this.active});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 192,
      height: 192,
      child: Center(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                if (active) ...[
                  _ring(controller.value),
                  _ring((controller.value + 0.5) % 1.0),
                ],
                child!,
              ],
            );
          },
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.bluetooth_searching_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }

  Widget _ring(double t) {
    final size = 96 + t * 96;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.primaryContainer.withValues(alpha: (1 - t) * 0.4),
          width: 2,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.loading = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white,
          elevation: 2,
          shadowColor: color.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final BleDevice device;
  final VoidCallback? onTap;

  const _DeviceCard({required this.device, this.onTap});

  Color _rssiColor(int rssi) {
    if (rssi > -60) return AppTheme.secondary;
    if (rssi > -80) return AppTheme.onSurfaceVariant;
    return AppTheme.error;
  }

  int _rssiStrength(int rssi) {
    if (rssi > -55) return 4;
    if (rssi > -65) return 3;
    if (rssi > -80) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final strength = _rssiStrength(device.rssi);
    final color = _rssiColor(device.rssi);

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
                  color: AppTheme.primaryFixed,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.watch_rounded, color: AppTheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name.isEmpty ? 'Unknown Device' : device.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.id,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(4, (i) {
                      return Container(
                        width: 3,
                        height: 6.0 + i * 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: i < strength
                              ? AppTheme.mint
                              : AppTheme.surfaceHighest,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${device.rssi} dBm',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
