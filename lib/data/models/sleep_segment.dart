enum SleepType {
  none,
  awake,
  light,
  deep,
  rem,
  unworn;

  String get label => switch (this) {
        SleepType.none => 'None',
        SleepType.awake => 'Awake',
        SleepType.light => 'Light',
        SleepType.deep => 'Deep',
        SleepType.rem => 'REM',
        SleepType.unworn => 'Unworn',
      };
}

class SleepSegment {
  final SleepType type;
  final int durationMinutes;
  final String startTime;
  final String endTime;

  const SleepSegment({
    required this.type,
    required this.durationMinutes,
    this.startTime = '',
    this.endTime = '',
  });
}
