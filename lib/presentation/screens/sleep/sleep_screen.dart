import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/sleep_segment.dart';
import '../../providers/providers.dart';
import '../../widgets/app_bottom_nav.dart';

class SleepScreen extends ConsumerWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // dayIndex 1 = last night's sleep
    final sleepAsync = ref.watch(sleepDataProvider(1));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/dashboard'),
        ),
        title: const Text('Sleep'),
        actions: const [
          Icon(Icons.calendar_today_rounded, color: AppTheme.onSurfaceVariant),
          SizedBox(width: 16),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(activeIndex: 3),
      body: sleepAsync.when(
        data: (segments) {
          if (segments.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bedtime_rounded,
                      size: 64, color: AppTheme.primary),
                  const SizedBox(height: 16),
                  Text('No sleep data available',
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            );
          }

          final totalMinutes =
              segments.fold<int>(0, (sum, s) => sum + s.durationMinutes);
          final deepMinutes = segments
              .where((s) => s.type == SleepType.deep)
              .fold<int>(0, (sum, s) => sum + s.durationMinutes);
          final lightMinutes = segments
              .where((s) => s.type == SleepType.light)
              .fold<int>(0, (sum, s) => sum + s.durationMinutes);
          final remMinutes = segments
              .where((s) => s.type == SleepType.rem)
              .fold<int>(0, (sum, s) => sum + s.durationMinutes);
          final awakeMinutes = segments
              .where((s) => s.type == SleepType.awake)
              .fold<int>(0, (sum, s) => sum + s.durationMinutes);

          final asleep = totalMinutes - awakeMinutes;
          final efficiency =
              totalMinutes > 0 ? (asleep / totalMinutes * 100).round() : 0;
          final quality = efficiency >= 85
              ? 'Good'
              : efficiency >= 70
                  ? 'Fair'
                  : 'Poor';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // Hero ring
              Center(
                child: SizedBox(
                  width: 192,
                  height: 192,
                  child: CustomPaint(
                    painter: _SleepRingPainter(
                      fraction: totalMinutes > 0 ? asleep / totalMinutes : 0,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bedtime_rounded,
                              color: AppTheme.primary, size: 28),
                          const SizedBox(height: 4),
                          Text(
                            '${totalMinutes ~/ 60}h ${totalMinutes % 60}m',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.onSurface,
                            ),
                          ),
                          Text(
                            'Total Sleep',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Efficiency / Quality
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MiniStat(
                    label: 'EFFICIENCY',
                    value: '$efficiency%',
                    color: AppTheme.secondary,
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    color: AppTheme.outlineVariant,
                  ),
                  _MiniStat(
                    label: 'QUALITY',
                    value: quality,
                    color: AppTheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Sleep stages
              Text('SLEEP STAGES',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: AppTheme.onSurfaceVariant,
                  )),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.cardDecoration(),
                child: Column(
                  children: [
                    // Stacked bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox(
                        height: 24,
                        child: Row(
                          children: [
                            if (deepMinutes > 0)
                              Expanded(
                                  flex: deepMinutes,
                                  child: Container(
                                      color: AppTheme.deepSleepColor)),
                            if (lightMinutes > 0)
                              Expanded(
                                  flex: lightMinutes,
                                  child: Container(
                                      color: AppTheme.lightSleepColor)),
                            if (remMinutes > 0)
                              Expanded(
                                  flex: remMinutes,
                                  child: Container(
                                      color: AppTheme.remSleepColor)),
                            if (awakeMinutes > 0)
                              Expanded(
                                  flex: awakeMinutes,
                                  child:
                                      Container(color: AppTheme.awakeColor)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Legend grid (2 columns)
                    Row(
                      children: [
                        Expanded(
                          child: _LegendItem(
                            color: AppTheme.deepSleepColor,
                            label: 'Deep Sleep',
                            minutes: deepMinutes,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _LegendItem(
                            color: AppTheme.lightSleepColor,
                            label: 'Light Sleep',
                            minutes: lightMinutes,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _LegendItem(
                            color: AppTheme.remSleepColor,
                            label: 'REM Sleep',
                            minutes: remMinutes,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _LegendItem(
                            color: AppTheme.awakeColor,
                            label: 'Awake',
                            minutes: awakeMinutes,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Timeline
              Text('TIMELINE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: AppTheme.onSurfaceVariant,
                  )),
              const SizedBox(height: 12),
              Container(
                decoration: AppTheme.cardDecoration(),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final (i, s) in segments
                        .where((s) =>
                            s.type != SleepType.none &&
                            s.type != SleepType.unworn)
                        .indexed) ...[
                      if (i > 0)
                        Divider(
                            height: 1,
                            color: AppTheme.outlineVariant
                                .withValues(alpha: 0.4)),
                      _TimelineRow(segment: s),
                    ],
                  ],
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
                onPressed: () => ref.invalidate(sleepDataProvider(1)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int minutes;

  const _LegendItem(
      {required this.color, required this.label, required this.minutes});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 15, color: AppTheme.onSurface),
          ),
        ),
        Text(
          '${minutes ~/ 60}h ${minutes % 60}m',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final SleepSegment segment;

  const _TimelineRow({required this.segment});

  Color get _color => switch (segment.type) {
        SleepType.deep => AppTheme.deepSleepColor,
        SleepType.light => AppTheme.lightSleepColor,
        SleepType.rem => AppTheme.remSleepColor,
        SleepType.awake => AppTheme.awakeColor,
        _ => AppTheme.outline,
      };

  IconData get _icon => switch (segment.type) {
        SleepType.deep => Icons.bedtime_rounded,
        SleepType.light => Icons.brightness_low_rounded,
        SleepType.rem => Icons.psychology_rounded,
        SleepType.awake => Icons.wb_sunny_rounded,
        _ => Icons.circle,
      };

  @override
  Widget build(BuildContext context) {
    final hasRange = segment.startTime.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, color: _color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasRange
                      ? '${segment.startTime} - ${segment.endTime}'
                      : '${segment.durationMinutes} min',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Duration: ${segment.durationMinutes} min',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              segment.type.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SleepRingPainter extends CustomPainter {
  final double fraction;

  _SleepRingPainter({required this.fraction});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const stroke = 8.0;

    final bgPaint = Paint()
      ..color = AppTheme.outlineVariant.withValues(alpha: 0.3)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final sweep = 2 * math.pi * fraction.clamp(0.0, 1.0);
    final fgPaint = Paint()
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [AppTheme.primary, AppTheme.mint, AppTheme.primary],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SleepRingPainter old) =>
      old.fraction != fraction;
}
