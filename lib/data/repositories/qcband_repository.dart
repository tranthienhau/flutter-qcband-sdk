import 'dart:async';
import 'package:flutter/services.dart';
import '../models/ble_device.dart';
import '../models/battery_info.dart';
import '../models/device_info.dart';
import '../models/sport_data.dart';
import '../models/heart_rate_reading.dart';
import '../models/sleep_segment.dart';
import '../models/blood_oxygen_reading.dart';
import '../../core/constants/sdk_constants.dart';

class QCBandRepository {
  static const _methodChannel = MethodChannel(SdkConstants.methodChannel);
  static const _eventChannel = EventChannel(SdkConstants.eventChannel);

  late final Stream<Map<String, dynamic>> _eventStream;

  QCBandRepository() {
    _eventStream = _eventChannel
        .receiveBroadcastStream()
        .map((e) => Map<String, dynamic>.from(e as Map))
        .asBroadcastStream();
  }

  // -- Scan --

  Future<void> startScan({int timeout = 15}) async {
    await _methodChannel.invokeMethod(
      SdkConstants.startScan,
      {'timeout': timeout},
    );
  }

  Future<void> stopScan() async {
    await _methodChannel.invokeMethod(SdkConstants.stopScan);
  }

  Stream<List<BleDevice>> get scanResults => _eventStream
      .where((e) => e['event'] == SdkConstants.eventScanResult)
      .map((e) {
    final devices = (e['devices'] as List)
        .map((d) => BleDevice.fromJson(Map<String, dynamic>.from(d as Map)))
        .toList();
    return devices;
  });

  // -- Connection --

  Future<void> connect(String peripheralId) async {
    await _methodChannel.invokeMethod(
      SdkConstants.connect,
      {'peripheralId': peripheralId},
    );
  }

  Future<void> disconnect() async {
    await _methodChannel.invokeMethod(SdkConstants.disconnect);
  }

  Stream<String> get connectionState => _eventStream
      .where((e) => e['event'] == SdkConstants.eventConnectionState)
      .map((e) => e['state'] as String);

  // -- Time Sync --

  Future<Map<String, dynamic>> syncTime() async {
    final result = await _methodChannel.invokeMethod(SdkConstants.syncTime);
    return Map<String, dynamic>.from(result as Map);
  }

  // -- Battery --

  Future<BatteryInfo> readBattery() async {
    final result = await _methodChannel.invokeMethod(SdkConstants.readBattery);
    return BatteryInfo.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Stream<BatteryInfo> get batteryUpdates => _eventStream
      .where((e) => e['event'] == SdkConstants.eventBatteryUpdate)
      .map((e) => BatteryInfo(
            level: e['level'] as int,
            charging: e['charging'] as bool,
          ));

  // -- Device Info --

  Future<DeviceInfo> getDeviceVersion() async {
    final result =
        await _methodChannel.invokeMethod(SdkConstants.getDeviceVersion);
    return DeviceInfo.fromJson(Map<String, dynamic>.from(result as Map));
  }

  // -- Sport Data --

  Future<SportData> getCurrentSport() async {
    final result =
        await _methodChannel.invokeMethod(SdkConstants.getCurrentSport);
    return SportData.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Stream<SportData> get stepUpdates => _eventStream
      .where((e) => e['event'] == SdkConstants.eventStepUpdate)
      .map((e) => SportData(
            steps: e['steps'] as int,
            calories: (e['calories'] as num).toDouble(),
            distance: e['distance'] as int,
            activeMinutes: e['activeMinutes'] as int,
          ));

  // -- Heart Rate --

  Future<void> startRealTimeHR() async {
    await _methodChannel.invokeMethod(SdkConstants.startRealTimeHR);
  }

  Future<void> stopRealTimeHR() async {
    await _methodChannel.invokeMethod(SdkConstants.stopRealTimeHR);
  }

  Stream<HeartRateReading> get realTimeHeartRate => _eventStream
      .where((e) => e['event'] == SdkConstants.eventRealTimeHeartRate)
      .map((e) => HeartRateReading(
            bpm: e['bpm'] as int,
            timestamp: DateTime.now(),
          ));

  // -- Sleep --

  Future<List<SleepSegment>> getSleepData({int dayIndex = 0}) async {
    final result = await _methodChannel.invokeMethod(
      SdkConstants.getSleepData,
      {'dayIndex': dayIndex},
    );
    return (result as List).map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      final typeIndex = (map['type'] as int).clamp(0, SleepType.values.length - 1);
      return SleepSegment(
        type: SleepType.values[typeIndex],
        durationMinutes: map['durationMinutes'] as int,
        startTime: map['startTime'] as String? ?? '',
        endTime: map['endTime'] as String? ?? '',
      );
    }).toList();
  }

  // -- Blood Oxygen --

  Future<List<BloodOxygenReading>> getBloodOxygen({int dayIndex = 0}) async {
    final result = await _methodChannel.invokeMethod(
      SdkConstants.getBloodOxygen,
      {'dayIndex': dayIndex},
    );
    return (result as List).map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      return BloodOxygenReading(
        spo2: (map['spo2'] as num).toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (map['timestamp'] as num).toInt(),
        ),
      );
    }).toList();
  }
}
