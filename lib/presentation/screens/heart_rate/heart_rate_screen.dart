import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/heart_rate_reading.dart';
import '../../../data/repositories/mock_qcband_repository.dart';
import '../../../main.dart';
import '../../providers/providers.dart';
import '../../widgets/app_bottom_nav.dart';

class HeartRateScreen extends ConsumerStatefulWidget {
  const HeartRateScreen({super.key});

  @override
  ConsumerState<HeartRateScreen> createState() => _HeartRateScreenState();
}

class _HeartRateScreenState extends ConsumerState<HeartRateScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  StreamSubscription? _hrSub;
  MockQCBandRepository? _mock;

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
    // Do not touch `ref` here: dispose can run after the ProviderScope element
    // is torn down (e.g. navigating away), which throws. Clean up locally.
    _hrSub?.cancel();
    _mock?.stopMockHeartRate();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startMonitoring() async {
    ref.read(heartRateHistoryProvider.notifier).clear();
    ref.read(isMonitoringHRProvider.notifier).state = true;

    final isDemo = ref.read(demoModeProvider);

    if (isDemo) {
      final mock = ref.read(mockRepositoryProvider);
      _mock = mock;
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

    final minBpm =
        history.isNotEmpty ? history.map((e) => e.bpm).reduce(math.min) : 0;
    final maxBpm =
        history.isNotEmpty ? history.map((e) => e.bpm).reduce(math.max) : 0;
    final avgBpm = history.isNotEmpty
        ? (history.map((e) => e.bpm).reduce((a, b) => a + b) / history.length)
            .round()
        : 0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            _stopMonitoring();
            context.go('/dashboard');
          },
        ),
        title: const Text('Heart Rate'),
      ),
      bottomNavigationBar: const AppBottomNav(activeIndex: 1),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // BPM hero
          Column(
            children: [
              const SizedBox(height: 8),
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
                child: Icon(
                  Icons.favorite_rounded,
                  size: 64,
                  color: isMonitoring && latestBpm > 0
                      ? AppTheme.tertiaryContainer
                      : AppTheme.tertiaryContainer.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                latestBpm > 0 ? '$latestBpm' : '--',
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.5,
                  color: AppTheme.onSurface,
                ),
              ),
              Text(
                'BPM',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.0,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Stat cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'MIN',
                  value: minBpm > 0 ? '$minBpm' : '--',
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  label: 'AVG',
                  value: avgBpm > 0 ? '$avgBpm' : '--',
                  color: AppTheme.primary,
                  highlighted: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  label: 'MAX',
                  value: maxBpm > 0 ? '$maxBpm' : '--',
                  color: AppTheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Live graph card
          Container(
            height: 220,
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIVE ACTIVITY',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: history.length < 2
                      ? Center(
                          child: Text(
                            isMonitoring
                                ? 'Waiting for heart rate data...'
                                : 'Tap Start to begin monitoring',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : CustomPaint(
                          size: Size.infinite,
                          painter: _HeartRateChartPainter(readings: history),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Control button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: isMonitoring ? _stopMonitoring : _startMonitoring,
              icon: Icon(isMonitoring
                  ? Icons.stop_circle_rounded
                  : Icons.play_arrow_rounded),
              label: Text(isMonitoring ? 'Stop Monitoring' : 'Start Monitoring'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isMonitoring ? AppTheme.error : AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: (isMonitoring ? AppTheme.error : AppTheme.primary)
                    .withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Sensor connected via Bluetooth Smart',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool highlighted;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted
              ? AppTheme.primary.withValues(alpha: 0.25)
              : AppTheme.outlineVariant.withValues(alpha: 0.3),
          width: highlighted ? 1.5 : 1,
        ),
        boxShadow: const [AppTheme.cardShadow],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
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
      ..color = AppTheme.outlineVariant.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;

    for (var i = 0; i < 5; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Line chart
    final linePaint = Paint()
      ..color = AppTheme.tertiary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.tertiaryContainer.withValues(alpha: 0.25),
          AppTheme.tertiaryContainer.withValues(alpha: 0.0),
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
        Paint()..color = AppTheme.tertiary,
      );
      canvas.drawCircle(
        Offset(lastX, lastY),
        2.5,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeartRateChartPainter old) =>
      old.readings.length != readings.length;
}
