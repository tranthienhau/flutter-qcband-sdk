import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/heart_rate_reading.dart';
import '../../../main.dart';
import '../../providers/providers.dart';

class HeartRateScreen extends ConsumerStatefulWidget {
  const HeartRateScreen({super.key});

  @override
  ConsumerState<HeartRateScreen> createState() => _HeartRateScreenState();
}

class _HeartRateScreenState extends ConsumerState<HeartRateScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  StreamSubscription? _hrSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    if (kScreenshotMode || kVideoMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(demoModeProvider.notifier).state = true;
        _startMonitoring();
      });
    }
  }

  @override
  void dispose() {
    _stopMonitoring();
    _pulseController.dispose();
    _hrSub?.cancel();
    super.dispose();
  }

  Future<void> _startMonitoring() async {
    ref.read(heartRateHistoryProvider.notifier).clear();
    ref.read(isMonitoringHRProvider.notifier).state = true;

    final isDemo = ref.read(demoModeProvider);

    if (isDemo) {
      final mock = ref.read(mockRepositoryProvider);
      mock.startMockHeartRate();
      _hrSub = mock.mockHeartRateStream.listen((hr) {
        ref.read(heartRateHistoryProvider.notifier).add(hr);
        _pulseController.forward(from: 0);
      });
    } else {
      _hrSub =
          ref.read(qcbandRepositoryProvider).realTimeHeartRate.listen((hr) {
        ref.read(heartRateHistoryProvider.notifier).add(hr);
        _pulseController.forward(from: 0);
      });

      try {
        final queue = ref.read(commandQueueProvider);
        final repo = ref.read(qcbandRepositoryProvider);
        await queue.enqueue(() => repo.startRealTimeHR());
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start HR: $e')),
          );
        }
        _stopMonitoring();
      }
    }
  }

  Future<void> _stopMonitoring() async {
    _hrSub?.cancel();
    _hrSub = null;
    ref.read(isMonitoringHRProvider.notifier).state = false;
    _pulseController.stop();

    final isDemo = ref.read(demoModeProvider);
    if (isDemo) {
      ref.read(mockRepositoryProvider).stopMockHeartRate();
    } else {
      try {
        final queue = ref.read(commandQueueProvider);
        final repo = ref.read(qcbandRepositoryProvider);
        await queue.enqueue(() => repo.stopRealTimeHR());
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMonitoring = ref.watch(isMonitoringHRProvider);
    final history = ref.watch(heartRateHistoryProvider);
    final latestBpm = history.isNotEmpty ? history.last.bpm : 0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _stopMonitoring();
            context.go('/dashboard');
          },
        ),
        title: const Text('Heart Rate'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),

          // BPM display with pulse animation
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale =
                  1.0 + (0.1 * math.sin(_pulseController.value * math.pi));
              return Transform.scale(
                scale: isMonitoring ? scale : 1.0,
                child: child,
              );
            },
            child: Column(
              children: [
                Icon(
                  Icons.favorite,
                  size: 64,
                  color: isMonitoring && latestBpm > 0
                      ? AppTheme.heartRateColor
                      : AppTheme.heartRateColor.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 8),
                Text(
                  latestBpm > 0 ? '$latestBpm' : '--',
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.heartRateColor,
                  ),
                ),
                const Text(
                  'BPM',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppTheme.heartRateColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Stats row
          if (history.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatChip(
                    label: 'Min',
                    value: '${history.map((e) => e.bpm).reduce(math.min)}',
                    color: AppTheme.sleepColor,
                  ),
                  _StatChip(
                    label: 'Avg',
                    value:
                        '${(history.map((e) => e.bpm).reduce((a, b) => a + b) / history.length).round()}',
                    color: AppTheme.stepsColor,
                  ),
                  _StatChip(
                    label: 'Max',
                    value: '${history.map((e) => e.bpm).reduce(math.max)}',
                    color: AppTheme.heartRateColor,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Chart
          Expanded(
            child: history.length < 2
                ? Center(
                    child: Text(
                      isMonitoring
                          ? 'Waiting for heart rate data...'
                          : 'Tap Start to begin monitoring',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _HeartRateChartPainter(readings: history),
                    ),
                  ),
          ),

          // Start/Stop button
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isMonitoring ? _stopMonitoring : _startMonitoring,
                icon: Icon(isMonitoring ? Icons.stop : Icons.play_arrow),
                label: Text(
                    isMonitoring ? 'Stop Monitoring' : 'Start Monitoring'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMonitoring
                      ? AppTheme.heartRateColor
                      : Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _HeartRateChartPainter extends CustomPainter {
  final List<HeartRateReading> readings;

  _HeartRateChartPainter({required this.readings});

  @override
  void paint(Canvas canvas, Size size) {
    if (readings.length < 2) return;

    final bpmValues = readings.map((e) => e.bpm.toDouble()).toList();
    final minBpm = (bpmValues.reduce(math.min) - 10).clamp(40.0, 200.0);
    final maxBpm = (bpmValues.reduce(math.max) + 10).clamp(60.0, 220.0);
    final range = maxBpm - minBpm;

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 0.5;

    for (var i = 0; i < 5; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Line chart
    final linePaint = Paint()
      ..color = AppTheme.heartRateColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.heartRateColor.withValues(alpha: 0.3),
          AppTheme.heartRateColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < bpmValues.length; i++) {
      final x = size.width * i / (bpmValues.length - 1);
      final y = size.height - (bpmValues[i] - minBpm) / range * size.height;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Latest point dot
    if (bpmValues.isNotEmpty) {
      final lastX = size.width;
      final lastY =
          size.height - (bpmValues.last - minBpm) / range * size.height;
      canvas.drawCircle(
        Offset(lastX, lastY),
        5,
        Paint()..color = AppTheme.heartRateColor,
      );
      canvas.drawCircle(
        Offset(lastX, lastY),
        3,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeartRateChartPainter old) =>
      old.readings.length != readings.length;
}
