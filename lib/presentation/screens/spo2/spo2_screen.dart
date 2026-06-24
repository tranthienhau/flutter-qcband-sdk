import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/blood_oxygen_reading.dart';
import '../../providers/providers.dart';
import '../../widgets/app_bottom_nav.dart';

class Spo2Screen extends ConsumerWidget {
  const Spo2Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spo2Async = ref.watch(bloodOxygenProvider(0));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/dashboard'),
        ),
        title: const Text('Blood Oxygen'),
      ),
      bottomNavigationBar: const AppBottomNav(activeIndex: 2),
      body: spo2Async.when(
        data: (readings) {
          if (readings.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.water_drop_rounded,
                      size: 64, color: AppTheme.mint),
                  const SizedBox(height: 16),
                  Text('No SpO2 data available',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Enable scheduled blood oxygen\nmeasurement on your device',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // Gauge card
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                decoration: AppTheme.cardDecoration(),
                child: Column(
                  children: [
                    SizedBox(
                      width: 220,
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
                                  fontSize: 48,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1,
                                  color: AppTheme.onSurface,
                                ),
                              ),
                              Text(
                                'SPO2',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2,
                                  color: AppTheme.tertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _statusColor(latest.spo2),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _statusLabel(latest.spo2),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(latest.spo2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your blood oxygen levels are within the healthy range.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Stats grid
              Row(
                children: [
                  Expanded(
                    child: _StatCell(label: 'MIN', value: '${minVal.round()}%'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCell(
                      label: 'AVG',
                      value: '${avg.round()}%',
                      valueColor: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCell(label: 'MAX', value: '${maxVal.round()}%'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text("Today's Readings",
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              ...readings.reversed
                  .take(20)
                  .map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ReadingCard(reading: r),
                      )),
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => ref.invalidate(bloodOxygenProvider(0)),
                  icon: const Icon(Icons.sensors_rounded),
                  label: const Text('Measure Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: AppTheme.primary.withValues(alpha: 0.4),
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
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppTheme.error),
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
    if (spo2 >= 95) return AppTheme.tertiary;
    if (spo2 >= 90) return AppTheme.awakeColor;
    return AppTheme.error;
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatCell({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppTheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  final BloodOxygenReading reading;

  const _ReadingCard({required this.reading});

  @override
  Widget build(BuildContext context) {
    final hour = reading.timestamp.hour.toString().padLeft(2, '0');
    final minute = reading.timestamp.minute.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.tertiaryContainer.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.water_drop_rounded,
                color: AppTheme.tertiary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '$hour:$minute',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: AppTheme.onSurface,
              ),
            ),
          ),
          Text(
            '${reading.spo2.round()}%',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              width: 64,
              height: 6,
              child: LinearProgressIndicator(
                value: reading.spo2 / 100,
                backgroundColor: AppTheme.surfaceHighest,
                color: reading.spo2 >= 95
                    ? AppTheme.tertiary
                    : reading.spo2 >= 90
                        ? AppTheme.awakeColor
                        : AppTheme.error,
              ),
            ),
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
      ..color = AppTheme.surfaceHighest
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Value arc (mint gradient)
    final fraction = ((value - 80) / 20).clamp(0.0, 1.0);
    final valuePaint = Paint()
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: [
          AppTheme.mintDim,
          AppTheme.mint,
          AppTheme.tertiary,
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
      Paint()..color = AppTheme.mint,
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
