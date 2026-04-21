class BleDevice {
  final String id;
  final String name;
  final int rssi;

  const BleDevice({
    required this.id,
    required this.name,
    this.rssi = -100,
  });

  factory BleDevice.fromJson(Map<String, dynamic> json) => BleDevice(
        id: json['id'] as String,
        name: json['name'] as String,
        rssi: json['rssi'] as int? ?? -100,
      );
}
