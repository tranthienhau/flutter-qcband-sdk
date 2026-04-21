import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/sleep_segment.dart';
import '../../providers/providers.dart';

class SleepScreen extends ConsumerWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // dayIndex 1 = last night's sleep
    final sleepAsync = ref.watch(sleepDataProvider(1));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        title: const Text('Sleep'),
      ),
      body: sleepAsync.when(
        data: (segments) {
          if (segments.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bedtime, size: 64, color: AppTheme.sleepColor),
                  SizedBox(height: 16),
                  Text('No sleep data available'),
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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Total sleep
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.bedtime,
                          size: 40, color: AppTheme.sleepColor),
                      const SizedBox(height: 8),
                      Text(
                        '${totalMinutes ~/ 60}h ${totalMinutes % 60}m',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.sleepColor,
                        ),
                      ),
                      Text(
                        'Total Sleep',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Stacked bar chart
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sleep Stages',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),

                      // Stacked bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 32,
                          child: Row(
                            children: [
                              if (deepMinutes > 0)
                                Expanded(
                                  flex: deepMinutes,
                                  child: Container(
                                      color: AppTheme.deepSleepColor),
                                ),
                              if (lightMinutes > 0)
                                Expanded(
                                  flex: lightMinutes,
                                  child: Container(
                                      color: AppTheme.lightSleepColor),
                                ),
                              if (remMinutes > 0)
                                Expanded(
                                  flex: remMinutes,
                                  child: Container(
                                      color: AppTheme.remSleepColor),
                                ),
                              if (awakeMinutes > 0)
                                Expanded(
                                  flex: awakeMinutes,
                                  child:
                                      Container(color: AppTheme.awakeColor),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Legend + durations
                      _SleepStageTile(
                        label: 'Deep Sleep',
                        duration: deepMinutes,
                        color: AppTheme.deepSleepColor,
                        total: totalMinutes,
                      ),
                      _SleepStageTile(
                        label: 'Light Sleep',
                        duration: lightMinutes,
                        color: AppTheme.lightSleepColor,
                        total: totalMinutes,
                      ),
                      _SleepStageTile(
                        label: 'REM Sleep',
                        duration: remMinutes,
                        color: AppTheme.remSleepColor,
                        total: totalMinutes,
                      ),
                      _SleepStageTile(
                        label: 'Awake',
                        duration: awakeMinutes,
                        color: AppTheme.awakeColor,
                        total: totalMinutes,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Timeline
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Timeline',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      ...segments
                          .where((s) =>
                              s.type != SleepType.none &&
                              s.type != SleepType.unworn)
                          .map((s) => _TimelineItem(segment: s)),
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

class _SleepStageTile extends StatelessWidget {
  final String label;
  final int duration;
  final Color color;
  final int total;

  const _SleepStageTile({
    required this.label,
    required this.duration,
    required this.color,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (duration / total * 100).round() : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration:
                BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(
            '${duration ~/ 60}h ${duration % 60}m',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              '$pct%',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final SleepSegment segment;

  const _TimelineItem({required this.segment});

  Color get _color => switch (segment.type) {
        SleepType.deep => AppTheme.deepSleepColor,
        SleepType.light => AppTheme.lightSleepColor,
        SleepType.rem => AppTheme.remSleepColor,
        SleepType.awake => AppTheme.awakeColor,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: _color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            segment.startTime.isNotEmpty
                ? '${segment.startTime} - ${segment.endTime}'
                : '${segment.durationMinutes}m',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              segment.type.label,
              style: TextStyle(fontSize: 12, color: _color),
            ),
          ),
        ],
      ),
    );
  }
}
