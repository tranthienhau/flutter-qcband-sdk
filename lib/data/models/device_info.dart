class DeviceInfo {
  final String hardware;
  final String software;

  const DeviceInfo({
    this.hardware = '',
    this.software = '',
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
        hardware: json['hardware'] as String? ?? '',
        software: json['software'] as String? ?? '',
      );
}
