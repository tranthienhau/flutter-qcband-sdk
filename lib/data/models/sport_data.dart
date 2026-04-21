class SportData {
  final int steps;
  final double calories;
  final int distance;
  final int activeMinutes;

  const SportData({
    this.steps = 0,
    this.calories = 0.0,
    this.distance = 0,
    this.activeMinutes = 0,
  });

  factory SportData.fromJson(Map<String, dynamic> json) => SportData(
        steps: json['steps'] as int? ?? 0,
        calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
        distance: json['distance'] as int? ?? 0,
        activeMinutes: json['activeMinutes'] as int? ?? 0,
      );
}
