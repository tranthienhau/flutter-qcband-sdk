package com.tranthienhau.qcband

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Timer
import java.util.TimerTask

/**
 * Flutter plugin wrapping the QCBand Android SDK (qc_sdk_2.0.12.aar).
 *
 * Mirrors the iOS QCBandPlugin - same MethodChannel/EventChannel contract.
 * Uses QCBandCommandQueue for sequential command execution.
 *
 * NOTE: The Android SDK JAR/AAR APIs are similar but not identical to iOS.
 * This plugin maps to the same Flutter interface so Dart code is platform-agnostic.
 *
 * Reference: docs/Qwatch 2/Android/QRing_SDK_20240923_2.0.12/sdk_ring.pdf
 */
class QCBandPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val METHOD_CHANNEL = "com.tranthienhau.qcband/methods"
        private const val EVENT_CHANNEL = "com.tranthienhau.qcband/events"
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var context: Context? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val commandQueue = QCBandCommandQueue.shared
    private var hrHoldTimer: Timer? = null

    // Android SDK references (initialized when SDK is available)
    // private var bleManager: QCBleCentralManager? = null
    // private var sdkManager: QCSDKManager? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext

        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(this)

        setupSDKCallbacks()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        hrHoldTimer?.cancel()
        context = null
    }

    private fun setupSDKCallbacks() {
        // Register SDK callbacks that push events to Flutter EventSink.
        // Android SDK equivalent of iOS QCSDKManager block callbacks:
        //
        // QCSDKManager.getInstance().setOnRealTimeHeartRateListener { hr ->
        //     sendEvent(mapOf("event" to "realTimeHeartRate", "bpm" to hr))
        // }
        //
        // QCSDKManager.getInstance().setOnBatteryInfoListener { battery, charging ->
        //     sendEvent(mapOf("event" to "batteryUpdate", "level" to battery, "charging" to charging))
        // }
        //
        // QCSDKManager.getInstance().setOnStepInfoListener { step, calorie, distance ->
        //     sendEvent(mapOf(
        //         "event" to "stepUpdate",
        //         "steps" to step, "calories" to calorie.toDouble(),
        //         "distance" to distance, "activeMinutes" to 0
        //     ))
        // }
    }

    // -- StreamHandler --

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun sendEvent(data: Map<String, Any>) {
        mainHandler.post { eventSink?.success(data) }
    }

    // -- MethodCallHandler --

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startScan" -> handleStartScan(call, result)
            "stopScan" -> handleStopScan(result)
            "connect" -> handleConnect(call, result)
            "disconnect" -> handleDisconnect(result)
            "syncTime" -> handleSyncTime(result)
            "readBattery" -> handleReadBattery(result)
            "getDeviceVersion" -> handleGetDeviceVersion(result)
            "getCurrentSport" -> handleGetCurrentSport(result)
            "getSleepData" -> handleGetSleepData(call, result)
            "getBloodOxygen" -> handleGetBloodOxygen(call, result)
            "startRealTimeHR" -> handleStartRealTimeHR(result)
            "stopRealTimeHR" -> handleStopRealTimeHR(result)
            else -> result.notImplemented()
        }
    }

    // -- Scan --

    private fun handleStartScan(call: MethodCall, result: MethodChannel.Result) {
        // Android SDK scan:
        // bleManager = QCBleCentralManager.getInstance(context)
        // bleManager?.scanWithServices(arrayOf(SERVICE_UUID_1, SERVICE_UUID_2))
        // bleManager?.setOnScanListener { peripherals ->
        //     val devices = peripherals.map { p ->
        //         mapOf("id" to p.address, "name" to (p.name ?: "Unknown"), "rssi" to p.rssi)
        //     }
        //     sendEvent(mapOf("event" to "scanResult", "devices" to devices))
        // }
        result.success(null)
    }

    private fun handleStopScan(result: MethodChannel.Result) {
        // bleManager?.stopScan()
        result.success(null)
    }

    // -- Connection --

    private fun handleConnect(call: MethodCall, result: MethodChannel.Result) {
        val peripheralId = call.argument<String>("peripheralId") ?: run {
            result.error("INVALID_ARG", "peripheralId required", null)
            return
        }

        sendEvent(mapOf("event" to "connectionState", "state" to "connecting"))

        // Android SDK connect:
        // bleManager?.connect(peripheralId, 6) // 6s timeout
        // bleManager?.setOnConnectionListener(object : ConnectionListener {
        //     override fun onConnected(peripheral: BluetoothDevice) {
        //         sendEvent(mapOf("event" to "connectionState", "state" to "connected"))
        //     }
        //     override fun onDisconnected(peripheral: BluetoothDevice) {
        //         hrHoldTimer?.cancel()
        //         sendEvent(mapOf("event" to "connectionState", "state" to "disconnected"))
        //     }
        //     override fun onFailed(peripheral: BluetoothDevice) {
        //         sendEvent(mapOf("event" to "connectionState", "state" to "failed"))
        //     }
        // })

        result.success(null)
    }

    private fun handleDisconnect(result: MethodChannel.Result) {
        hrHoldTimer?.cancel()
        hrHoldTimer = null
        commandQueue.cancelAll()
        // bleManager?.disconnect()
        result.success(null)
    }

    // -- Time Sync --

    private fun handleSyncTime(result: MethodChannel.Result) {
        commandQueue.enqueue<Map<String, Any>>(
            command = { completion ->
                // QCSDKCmdCreator.setTime(Date()) { featureMap ->
                //     val features = mutableMapOf<String, Any>()
                //     featureMap["QCBandFeatureBloodOxygen"]?.let { features["bloodOxygen"] = it == "1" }
                //     featureMap["QCBandFeatureBloodPressure"]?.let { features["bloodPressure"] = it == "1" }
                //     featureMap["QCBandFeatureTemperature"]?.let { features["temperature"] = it == "1" }
                //     completion(features, null)
                // }

                // Placeholder - return empty features until SDK is wired
                completion(emptyMap(), null)
            },
            onResult = { features, error ->
                if (error != null) {
                    result.error("SYNC_FAILED", error.message, null)
                } else {
                    result.success(features)
                }
            }
        )
    }

    // -- Battery --

    private fun handleReadBattery(result: MethodChannel.Result) {
        commandQueue.enqueue<Map<String, Any>>(
            command = { completion ->
                // QCSDKCmdCreator.readBattery { battery, charging ->
                //     completion(mapOf("level" to battery, "charging" to charging), null)
                // }
                completion(mapOf("level" to 0, "charging" to false), null)
            },
            onResult = { data, error ->
                if (error != null) result.error("BATTERY_FAILED", error.message, null)
                else result.success(data)
            }
        )
    }

    // -- Device Version --

    private fun handleGetDeviceVersion(result: MethodChannel.Result) {
        commandQueue.enqueue<Map<String, Any>>(
            command = { completion ->
                // QCSDKCmdCreator.getDeviceVersion { hw, sw ->
                //     completion(mapOf("hardware" to hw, "software" to sw), null)
                // }
                completion(mapOf("hardware" to "", "software" to ""), null)
            },
            onResult = { data, error ->
                if (error != null) result.error("VERSION_FAILED", error.message, null)
                else result.success(data)
            }
        )
    }

    // -- Sport Data --

    private fun handleGetCurrentSport(result: MethodChannel.Result) {
        commandQueue.enqueue<Map<String, Any>>(
            command = { completion ->
                // QCSDKCmdCreator.getCurrentSport { sport ->
                //     completion(mapOf(
                //         "steps" to sport.totalStepCount,
                //         "calories" to sport.calories,
                //         "distance" to sport.distance,
                //         "activeMinutes" to sport.activeTime
                //     ), null)
                // }
                completion(mapOf("steps" to 0, "calories" to 0.0, "distance" to 0, "activeMinutes" to 0), null)
            },
            onResult = { data, error ->
                if (error != null) result.error("SPORT_FAILED", error.message, null)
                else result.success(data)
            }
        )
    }

    // -- Sleep Data --

    private fun handleGetSleepData(call: MethodCall, result: MethodChannel.Result) {
        val dayIndex = call.argument<Int>("dayIndex") ?: 0

        commandQueue.enqueue<List<Map<String, Any>>>(
            command = { completion ->
                // QCSDKCmdCreator.getSleepDetailDataByDay(dayIndex) { sleeps ->
                //     val segments = sleeps.map { sleep ->
                //         mapOf(
                //             "type" to sleep.type,
                //             "durationMinutes" to sleep.total,
                //             "startTime" to (sleep.happenDate ?: ""),
                //             "endTime" to (sleep.endTime ?: "")
                //         )
                //     }
                //     completion(segments, null)
                // }
                completion(emptyList(), null)
            },
            onResult = { data, error ->
                if (error != null) result.error("SLEEP_FAILED", error.message, null)
                else result.success(data)
            }
        )
    }

    // -- Blood Oxygen --

    private fun handleGetBloodOxygen(call: MethodCall, result: MethodChannel.Result) {
        val dayIndex = call.argument<Int>("dayIndex") ?: 0

        commandQueue.enqueue<List<Map<String, Any>>>(
            command = { completion ->
                // QCSDKCmdCreator.getBloodOxygenDataByDayIndex(dayIndex) { data, err ->
                //     val readings = data.map { bo ->
                //         mapOf(
                //             "spo2" to bo.soa2,
                //             "timestamp" to bo.date.time
                //         )
                //     }
                //     completion(readings, null)
                // }
                completion(emptyList(), null)
            },
            onResult = { data, error ->
                if (error != null) result.error("SPO2_FAILED", error.message, null)
                else result.success(data)
            }
        )
    }

    // -- Real-Time Heart Rate --

    private fun handleStartRealTimeHR(result: MethodChannel.Result) {
        commandQueue.enqueue<Boolean>(
            command = { completion ->
                // QCSDKCmdCreator.beginRealTimeHeartRate({
                //     completion(true, null)
                // }, {
                //     completion(null, Exception("startRealTimeHR failed"))
                // })
                completion(true, null)
            },
            onResult = { _, error ->
                if (error != null) {
                    result.error("HR_START_FAILED", error.message, null)
                    return@enqueue
                }

                // Start hold timer (20s interval) on native side
                hrHoldTimer?.cancel()
                hrHoldTimer = Timer().apply {
                    scheduleAtFixedRate(object : TimerTask() {
                        override fun run() {
                            // QCSDKCmdCreator.continueRealTimeHeartRate({}, {})
                        }
                    }, 20000, 20000)
                }

                result.success(null)
            }
        )
    }

    private fun handleStopRealTimeHR(result: MethodChannel.Result) {
        hrHoldTimer?.cancel()
        hrHoldTimer = null

        commandQueue.enqueue<Boolean>(
            command = { completion ->
                // QCSDKCmdCreator.endRealTimeHeartRate({
                //     completion(true, null)
                // }, {
                //     completion(null, Exception("stopRealTimeHR failed"))
                // })
                completion(true, null)
            },
            onResult = { _, error ->
                if (error != null) result.error("HR_STOP_FAILED", error.message, null)
                else result.success(null)
            }
        )
    }
}
