class SdkConstants {
  SdkConstants._();

  static const methodChannel = 'com.tranthienhau.qcband/methods';
  static const eventChannel = 'com.tranthienhau.qcband/events';

  // Method names
  static const startScan = 'startScan';
  static const stopScan = 'stopScan';
  static const connect = 'connect';
  static const disconnect = 'disconnect';
  static const syncTime = 'syncTime';
  static const readBattery = 'readBattery';
  static const getDeviceVersion = 'getDeviceVersion';
  static const getCurrentSport = 'getCurrentSport';
  static const getSleepData = 'getSleepData';
  static const getBloodOxygen = 'getBloodOxygen';
  static const startRealTimeHR = 'startRealTimeHR';
  static const stopRealTimeHR = 'stopRealTimeHR';

  // Event types
  static const eventScanResult = 'scanResult';
  static const eventConnectionState = 'connectionState';
  static const eventRealTimeHeartRate = 'realTimeHeartRate';
  static const eventBatteryUpdate = 'batteryUpdate';
  static const eventStepUpdate = 'stepUpdate';
}
