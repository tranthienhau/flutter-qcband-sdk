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

class _ScanScreenState extends ConsumerState<ScanScreen> {
  List<BleDevice> _mockDevices = [];
  bool _mockScanning = false;
  bool _mockConnecting = false;

  @override
  void initState() {
    super.initState();
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
    final allDevices = isDemo || _mockDevices.isNotEmpty ? _mockDevices : realDevices;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QCBand Scanner'),
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: isConnecting
                ? AppTheme.heartRateColor.withValues(alpha: 0.2)
                : scanning
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.2)
                    : Colors.transparent,
            child: Row(
              children: [
                if (isConnecting) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  const Text('Connecting...'),
                ] else if (scanning) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  const Text('Scanning for devices...'),
                ] else
                  const Text('Tap Scan or use Demo Mode'),
              ],
            ),
          ),

          // Device list
          Expanded(
            child: allDevices.isEmpty && !scanning
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bluetooth_searching,
                          size: 80,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No devices found',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Make sure your QCBand bracelet is nearby\nor tap Demo Mode to preview the app',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: scanning || isConnecting
                              ? null
                              : _startDemoScan,
                          icon: const Icon(Icons.science),
                          label: const Text('Demo Mode'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.spo2Color,
                            side: const BorderSide(color: AppTheme.spo2Color),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: allDevices.length,
                    itemBuilder: (context, index) {
                      final device = allDevices[index];
                      return _DeviceCard(
                        device: device,
                        onTap: isConnecting
                            ? null
                            : () => _mockDevices.isNotEmpty
                                ? _connectDemoDevice(device)
                                : _connectToDevice(device),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'demo',
            onPressed: scanning || isConnecting ? null : _startDemoScan,
            icon: const Icon(Icons.science),
            label: const Text('Demo'),
            backgroundColor: AppTheme.spo2Color,
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'scan',
            onPressed: scanning || isConnecting ? null : _startScan,
            icon: const Icon(Icons.bluetooth_searching),
            label: Text(scanning ? 'Scanning...' : 'Scan'),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final BleDevice device;
  final VoidCallback? onTap;

  const _DeviceCard({required this.device, this.onTap});

  Color _rssiColor(int rssi) {
    if (rssi > -60) return AppTheme.spo2Color;
    if (rssi > -80) return AppTheme.stepsColor;
    return AppTheme.heartRateColor;
  }

  int _rssiStrength(int rssi) {
    if (rssi > -60) return 3;
    if (rssi > -80) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.watch,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          device.name.isEmpty ? 'Unknown Device' : device.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          device.id,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return Container(
                  width: 4,
                  height: 8.0 + (i * 4),
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: i < _rssiStrength(device.rssi)
                        ? _rssiColor(device.rssi)
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
            const SizedBox(height: 4),
            Text(
              '${device.rssi} dBm',
              style: TextStyle(
                fontSize: 11,
                color: _rssiColor(device.rssi),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
