import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/blood_oxygen_reading.dart';
import '../../providers/providers.dart';

class Spo2Screen extends ConsumerWidget {
  const Spo2Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spo2Async = ref.watch(bloodOxygenProvider(0));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        title: const Text('Blood Oxygen'),
      ),
      body: spo2Async.when(
        data: (readings) {
          if (readings.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.water_drop, size: 64, color: AppTheme.spo2Color),
                  SizedBox(height: 16),
                  Text('No SpO2 data available'),
                  SizedBox(height: 8),
                  Text(
                    'Enable scheduled blood oxygen\nmeasurement on your device',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final latest = readings.last;
          final avg = readings.map((r) => r.spo2).reduce((a, b) => a + b) /
              readings.length;
          final minVal = readings.map((r) => r.spo2).reduce(math.min);
          final maxVal = readings.map((r) => r.spo2).reduce(math.max);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Gauge card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: CustomPaint(
                          painter: _SpO2GaugePainter(value: latest.spo2),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${latest.spo2.round()}%',
                                  style: const TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.spo2Color,
                                  ),
                                ),
                                const Text(
                                  'SpO2',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppTheme.spo2Color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusLabel(latest.spo2),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(latest.spo2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Stats
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatColumn(
                          label: 'Min', value: '${minVal.round()}%'),
                      Container(width: 1, height: 40, color: Colors.white12),
                      _StatColumn(
                          label: 'Avg', value: '${avg.round()}%'),
                      Container(width: 1, height: 40, color: Colors.white12),
                      _StatColumn(
                          label: 'Max', value: '${maxVal.round()}%'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Readings list
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Today's Readings",
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      ...readings.reversed.take(20).map(
                            (r) => _ReadingRow(reading: r),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(bloodOxygenProvider(0)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(double spo2) {
    if (spo2 >= 95) return 'Normal';
    if (spo2 >= 90) return 'Low';
    return 'Very Low';
  }

  Color _statusColor(double spo2) {
    if (spo2 >= 95) return AppTheme.spo2Color;
    if (spo2 >= 90) return AppTheme.stepsColor;
    return AppTheme.heartRateColor;
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.spo2Color,
          ),
        ),
      ],
    );
  }
}

class _ReadingRow extends StatelessWidget {
  final BloodOxygenReading reading;

  const _ReadingRow({required this.reading});

  @override
  Widget build(BuildContext context) {
    final hour = reading.timestamp.hour.toString().padLeft(2, '0');
    final minute = reading.timestamp.minute.toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            '$hour:$minute',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: reading.spo2 / 100,
                backgroundColor: Colors.white10,
                color: reading.spo2 >= 95
                    ? AppTheme.spo2Color
                    : reading.spo2 >= 90
                        ? AppTheme.stepsColor
                        : AppTheme.heartRateColor,
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${reading.spo2.round()}%',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SpO2GaugePainter extends CustomPainter {
  final double value;

  _SpO2GaugePainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;
    const startAngle = 2.4; // ~137 degrees
    const sweepAngle = 4.3; // ~246 degrees arc

    // Background arc
    final bgPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Value arc
    final fraction = ((value - 80) / 20).clamp(0.0, 1.0);
    final valuePaint = Paint()
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: const [
          AppTheme.heartRateColor,
          AppTheme.stepsColor,
          AppTheme.spo2Color,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * fraction,
      false,
      valuePaint,
    );

    // End dot
    final endAngle = startAngle + sweepAngle * fraction;
    final dotX = center.dx + radius * math.cos(endAngle);
    final dotY = center.dy + radius * math.sin(endAngle);
    canvas.drawCircle(
      Offset(dotX, dotY),
      8,
      Paint()..color = AppTheme.spo2Color,
    );
    canvas.drawCircle(
      Offset(dotX, dotY),
      4,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _SpO2GaugePainter old) => old.value != value;
}
