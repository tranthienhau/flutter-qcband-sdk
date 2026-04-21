import 'dart:async';
import 'dart:math';
import '../models/ble_device.dart';
import '../models/battery_info.dart';
import '../models/device_info.dart';
import '../models/sport_data.dart';
import '../models/heart_rate_reading.dart';
import '../models/sleep_segment.dart';
import '../models/blood_oxygen_reading.dart';

/// Mock repository for simulator/demo mode.
/// Returns realistic fake data so the full UI flow can be demonstrated
/// without a physical QCBand device.
class MockQCBandRepository {
  final _random = Random(42);
  Timer? _hrTimer;
  final _hrController = StreamController<HeartRateReading>.broadcast();

  // -- Scan --

  Future<List<BleDevice>> mockScan() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    return const [
      BleDevice(id: 'QC-MOCK-001', name: 'QCBand Pro X1', rssi: -52),
      BleDevice(id: 'QC-MOCK-002', name: 'QCBand Lite', rssi: -71),
      BleDevice(id: 'QC-MOCK-003', name: 'QCRing S2', rssi: -85),
    ];
  }

  // -- Connection --

  Future<void> mockConnect() async {
    await Future.delayed(const Duration(milliseconds: 800));
  }

  // -- Time Sync --

  Future<Map<String, dynamic>> mockSyncTime() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'bloodOxygen': true,
      'bloodPressure': true,
      'temperature': true,
      'newSleepProtocol': true,
      'manualHeartRate': true,
      'appManual': true,
    };
  }

  // -- Battery --

  BatteryInfo mockBattery() {
    return const BatteryInfo(level: 73, charging: false);
  }

  // -- Device Info --

  DeviceInfo mockDeviceInfo() {
    return const DeviceInfo(hardware: '2.1.4', software: '3.8.12');
  }

  // -- Sport Data --

  SportData mockSportData() {
    return const SportData(
      steps: 8247,
      calories: 342.5,
      distance: 5830,
      activeMinutes: 47,
    );
  }

  // -- Heart Rate --

  void startMockHeartRate() {
    _hrTimer?.cancel();
    int baseBpm = 72;
    _hrTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      // Simulate realistic HR with slight variation
      baseBpm += _random.nextInt(7) - 3; // -3 to +3
      baseBpm = baseBpm.clamp(58, 105);
      _hrController.add(HeartRateReading(
        bpm: baseBpm,
        timestamp: DateTime.now(),
      ));
    });
  }

  void stopMockHeartRate() {
    _hrTimer?.cancel();
    _hrTimer = null;
  }

  Stream<HeartRateReading> get mockHeartRateStream => _hrController.stream;

  // -- Sleep Data --

  List<SleepSegment> mockSleepData() {
    return const [
      SleepSegment(
        type: SleepType.light,
        durationMinutes: 28,
        startTime: '23:15',
        endTime: '23:43',
      ),
      SleepSegment(
        type: SleepType.deep,
        durationMinutes: 52,
        startTime: '23:43',
        endTime: '00:35',
      ),
      SleepSegment(
        type: SleepType.rem,
        durationMinutes: 22,
        startTime: '00:35',
        endTime: '00:57',
      ),
      SleepSegment(
        type: SleepType.light,
        durationMinutes: 35,
        startTime: '00:57',
        endTime: '01:32',
      ),
      SleepSegment(
        type: SleepType.deep,
        durationMinutes: 68,
        startTime: '01:32',
        endTime: '02:40',
      ),
      SleepSegment(
        type: SleepType.awake,
        durationMinutes: 8,
        startTime: '02:40',
        endTime: '02:48',
      ),
      SleepSegment(
        type: SleepType.rem,
        durationMinutes: 41,
        startTime: '02:48',
        endTime: '03:29',
      ),
      SleepSegment(
        type: SleepType.light,
        durationMinutes: 45,
        startTime: '03:29',
        endTime: '04:14',
      ),
      SleepSegment(
        type: SleepType.deep,
        durationMinutes: 38,
        startTime: '04:14',
        endTime: '04:52',
      ),
      SleepSegment(
        type: SleepType.rem,
        durationMinutes: 29,
        startTime: '04:52',
        endTime: '05:21',
      ),
      SleepSegment(
        type: SleepType.light,
        durationMinutes: 42,
        startTime: '05:21',
        endTime: '06:03',
      ),
      SleepSegment(
        type: SleepType.awake,
        durationMinutes: 5,
        startTime: '06:03',
        endTime: '06:08',
      ),
    ];
  }

  // -- Blood Oxygen --

  List<BloodOxygenReading> mockBloodOxygen() {
    final now = DateTime.now();
    final baseHour = now.hour;
    return List.generate(12, (i) {
      final hour = (baseHour - 11 + i).clamp(0, 23);
      return BloodOxygenReading(
        spo2: 95.0 + _random.nextInt(5).toDouble(),
        timestamp: DateTime(now.year, now.month, now.day, hour, _random.nextInt(60)),
      );
    });
  }

  void dispose() {
    _hrTimer?.cancel();
    _hrController.close();
  }
}
