import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/battery_info.dart';
import '../../data/models/ble_device.dart';
import '../../data/models/blood_oxygen_reading.dart';
import '../../data/models/device_info.dart';
import '../../data/models/heart_rate_reading.dart';
import '../../data/models/sleep_segment.dart';
import '../../data/models/sport_data.dart';
import '../../data/repositories/qcband_repository.dart';
import '../../data/repositories/mock_qcband_repository.dart';
import '../../domain/services/command_queue_service.dart';

// -- Demo Mode --

final demoModeProvider = StateProvider<bool>((ref) => false);

// -- Core --

final qcbandRepositoryProvider = Provider<QCBandRepository>((ref) {
  return QCBandRepository();
});

final mockRepositoryProvider = Provider<MockQCBandRepository>((ref) {
  final mock = MockQCBandRepository();
  ref.onDispose(() => mock.dispose());
  return mock;
});

final commandQueueProvider = Provider<CommandQueueService>((ref) {
  return CommandQueueService();
});

// -- Scan --

final scanResultsProvider = StreamProvider<List<BleDevice>>((ref) {
  final repo = ref.watch(qcbandRepositoryProvider);
  return repo.scanResults;
});

final isScanningProvider = StateProvider<bool>((ref) => false);

// -- Connection --

final connectionStateProvider = StreamProvider<String>((ref) {
  final repo = ref.watch(qcbandRepositoryProvider);
  return repo.connectionState;
});

final connectedDeviceProvider = StateProvider<BleDevice?>((ref) => null);

final featureMapProvider = StateProvider<Map<String, dynamic>>((ref) => {});

// -- Battery --

final batteryProvider = StateNotifierProvider<BatteryNotifier, BatteryInfo?>(
  (ref) => BatteryNotifier(ref),
);

class BatteryNotifier extends StateNotifier<BatteryInfo?> {
  final Ref _ref;
  StreamSubscription? _sub;

  BatteryNotifier(this._ref) : super(null) {
    if (!_ref.read(demoModeProvider)) {
      _sub = _ref.read(qcbandRepositoryProvider).batteryUpdates.listen((info) {
        state = info;
      });
    }
  }

  void update(BatteryInfo info) => state = info;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

// -- Sport / Activity --

final sportDataProvider =
    StateNotifierProvider<SportDataNotifier, SportData?>((ref) {
  return SportDataNotifier(ref);
});

class SportDataNotifier extends StateNotifier<SportData?> {
  final Ref _ref;
  StreamSubscription? _sub;

  SportDataNotifier(this._ref) : super(null) {
    if (!_ref.read(demoModeProvider)) {
      _sub = _ref.read(qcbandRepositoryProvider).stepUpdates.listen((data) {
        state = data;
      });
    }
  }

  void update(SportData data) => state = data;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

// -- Device Info --

final deviceInfoProvider = StateProvider<DeviceInfo?>((ref) => null);

// -- Real-time Heart Rate --

final heartRateStreamProvider = StreamProvider<HeartRateReading>((ref) {
  final repo = ref.watch(qcbandRepositoryProvider);
  return repo.realTimeHeartRate;
});

final heartRateHistoryProvider =
    StateNotifierProvider<HeartRateHistoryNotifier, List<HeartRateReading>>(
  (ref) => HeartRateHistoryNotifier(),
);

class HeartRateHistoryNotifier extends StateNotifier<List<HeartRateReading>> {
  HeartRateHistoryNotifier() : super([]);

  void add(HeartRateReading reading) {
    state = [...state, reading];
    // Keep last 60 readings
    if (state.length > 60) {
      state = state.sublist(state.length - 60);
    }
  }

  void clear() => state = [];
}

final isMonitoringHRProvider = StateProvider<bool>((ref) => false);

// -- Sleep --

final sleepDataProvider =
    FutureProvider.family<List<SleepSegment>, int>((ref, dayIndex) async {
  if (ref.read(demoModeProvider)) {
    return ref.read(mockRepositoryProvider).mockSleepData();
  }
  final repo = ref.read(qcbandRepositoryProvider);
  final queue = ref.read(commandQueueProvider);
  return queue.enqueue(() => repo.getSleepData(dayIndex: dayIndex));
});

// -- Blood Oxygen --

final bloodOxygenProvider = FutureProvider.family<List<BloodOxygenReading>, int>(
    (ref, dayIndex) async {
  if (ref.read(demoModeProvider)) {
    return ref.read(mockRepositoryProvider).mockBloodOxygen();
  }
  final repo = ref.read(qcbandRepositoryProvider);
  final queue = ref.read(commandQueueProvider);
  return queue.enqueue(() => repo.getBloodOxygen(dayIndex: dayIndex));
});
