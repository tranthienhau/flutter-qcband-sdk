class BatteryInfo {
  final int level;
  final bool charging;

  const BatteryInfo({
    required this.level,
    this.charging = false,
  });

  factory BatteryInfo.fromJson(Map<String, dynamic> json) => BatteryInfo(
        level: json['level'] as int,
        charging: json['charging'] as bool? ?? false,
      );
}
