package com.dev.voicemate

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.app.NotificationManager
import android.provider.Settings
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHODS_CHANNEL = "com.dev.voicemate/audio_test/methods"
        private const val EVENTS_CHANNEL = "com.dev.voicemate/audio_test/events"
        private const val MONITORING_METHODS_CHANNEL =
            "com.dev.voicemate/monitoring/methods"
        private const val MONITORING_EVENTS_CHANNEL =
            "com.dev.voicemate/monitoring/events"
        private const val DEVICE_METHODS_CHANNEL =
            "com.dev.voicemate/device/methods"
        private const val REQUEST_MICROPHONE = 7401
        private const val REQUEST_NOTIFICATIONS = 7402
        private const val REQUEST_CAMERA = 7403
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var testEventSink: EventChannel.EventSink? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingNotificationResult: MethodChannel.Result? = null
    private var pendingCameraPermissionResult: MethodChannel.Result? = null
    private var captureManager: AudioCaptureManager? = null
    private var alertPreview: FinderAlertManager? = null
    private var flashlightPreview: FlashlightManager? = null
    private var activityResumed = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHODS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestMicrophonePermission" -> requestMicrophonePermission(result)
                    "startClapTest" -> startClapTest(result)
                    "stopClapTest" -> {
                        stopClapTest()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENTS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    testEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    testEventSink = null
                }
            })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MONITORING_METHODS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestNotificationPermission" -> requestNotificationPermission(result)
                "requestCameraPermission" -> requestCameraPermission(result)
                "getPermissionStatus" -> result.success(getPermissionStatus())
                "openAppSettings" -> openAppSettings(result)
                "getLockAdminStatus" -> result.success(
                    DeviceLockManager(this).isAdminActive(),
                )
                "requestLockAdminActivation" -> requestLockAdminActivation(result)
                "lockDeviceNow" -> lockDeviceNow(result)
                "installVoiceModel" -> installVoiceModel(result)
                "isVoiceModelInstalled" -> result.success(
                    VoiceModelInstaller.isInstalled(this),
                )
                "startMonitoring" -> startMonitoring(call.arguments as? Map<*, *>, result)
                "previewAlert" -> previewAlert(call.arguments as? Map<*, *>, result)
                "stopAlertPreview" -> {
                    alertPreview?.release()
                    alertPreview = null
                    flashlightPreview?.stop()
                    flashlightPreview = null
                    result.success(null)
                }
                "stopMonitoring" -> {
                    stopService(Intent(this, VoiceMonitoringService::class.java))
                    result.success(null)
                }
                "getMonitoringStatus" -> result.success(VoiceMonitoringService.isActive)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_METHODS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getBatteryInfo" -> {
                    try {
                        result.success(DeviceInfoProvider.batterySnapshot(this))
                    } catch (error: Exception) {
                        result.error(
                            "battery_info_unavailable",
                            error.message ?: "Could not read battery information.",
                            null,
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MONITORING_EVENTS_CHANNEL,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                MonitoringEventBus.attach(events)
            }

            override fun onCancel(arguments: Any?) {
                MonitoringEventBus.detach()
            }
        })
    }

    private fun requestMicrophonePermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.error(
                "permission_in_progress",
                "A microphone permission request is already active.",
                null,
            )
            return
        }
        pendingPermissionResult = result
        requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), REQUEST_MICROPHONE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_MICROPHONE) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        } else if (requestCode == REQUEST_NOTIFICATIONS) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingNotificationResult?.success(granted)
            pendingNotificationResult = null
        } else if (requestCode == REQUEST_CAMERA) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingCameraPermissionResult?.success(granted)
            pendingCameraPermissionResult = null
        }
    }

    private fun requestLockAdminActivation(result: MethodChannel.Result) {
        if (!activityResumed) {
            result.error(
                "activity_not_visible",
                "Open VoiceMate before activating the screen-lock permission.",
                null,
            )
            return
        }
        try {
            DeviceLockManager(this).requestAdminActivation(this)
            result.success(null)
        } catch (error: Exception) {
            result.error(
                "device_admin_activation_failed",
                error.message ?: "Could not open Android Device Admin activation.",
                null,
            )
        }
    }

    private fun lockDeviceNow(result: MethodChannel.Result) {
        try {
            val locked = DeviceLockManager(this).lockNow()
            if (locked) {
                result.success(true)
            } else {
                result.error(
                    "device_admin_not_active",
                    "Activate VoiceMate's lock-only Device Admin permission first.",
                    null,
                )
            }
        } catch (error: Exception) {
            result.error(
                "device_lock_failed",
                error.message ?: "Android could not lock this device.",
                null,
            )
        }
    }

    private fun requestCameraPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (pendingCameraPermissionResult != null) {
            result.error(
                "permission_in_progress",
                "A camera permission request is already active.",
                null,
            )
            return
        }
        pendingCameraPermissionResult = result
        requestPermissions(arrayOf(Manifest.permission.CAMERA), REQUEST_CAMERA)
    }

    private fun getPermissionStatus(): Map<String, Any> {
        val microphoneGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        val notificationPermissionGranted = Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        val notificationsEnabled = Build.VERSION.SDK_INT < 24 ||
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .areNotificationsEnabled()
        val cameraGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED

        return mapOf(
            "microphone_granted" to microphoneGranted,
            "notification_permission_granted" to notificationPermissionGranted,
            "notifications_enabled" to notificationsEnabled,
            "camera_granted" to cameraGranted,
            "api_level" to Build.VERSION.SDK_INT,
        )
    }

    private fun openAppSettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName"),
            )
            startActivity(intent)
            result.success(null)
        } catch (error: Exception) {
            result.error(
                "settings_unavailable",
                error.message ?: "Could not open Android app settings.",
                null,
            )
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33) {
            result.success(
                Build.VERSION.SDK_INT < 24 ||
                    (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                        .areNotificationsEnabled(),
            )
            return
        }
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            val enabled = (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .areNotificationsEnabled()
            result.success(enabled)
            return
        }
        if (pendingNotificationResult != null) {
            result.error(
                "permission_in_progress",
                "A notification permission request is already active.",
                null,
            )
            return
        }
        pendingNotificationResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_NOTIFICATIONS,
        )
    }

    private fun startMonitoring(arguments: Map<*, *>?, result: MethodChannel.Result) {
        if (!activityResumed) {
            result.error(
                "activity_not_visible",
                "Open VoiceMate before starting microphone monitoring.",
                null,
            )
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error(
                "permission_denied",
                "Microphone permission is required before monitoring can start.",
                null,
            )
            return
        }
        if (arguments?.get("flashlight_enabled") == true &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            checkSelfPermission(Manifest.permission.CAMERA) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error(
                "camera_permission_denied",
                "Camera permission is required for flashlight alerts.",
                null,
            )
            return
        }
        try {
            val intent = Intent(this, VoiceMonitoringService::class.java).apply {
                action = VoiceMonitoringService.ACTION_START
                putExtra("sound_enabled", arguments?.get("sound_enabled") as? Boolean ?: true)
                putExtra("vibration_enabled", arguments?.get("vibration_enabled") as? Boolean ?: true)
                putExtra("sound_id", arguments?.get("sound_id") as? String ?: "classic_beep")
                putExtra("alert_volume", (arguments?.get("alert_volume") as? Number)?.toInt() ?: 80)
                putExtra("alert_duration_seconds", (arguments?.get("alert_duration_seconds") as? Number)?.toInt() ?: 5)
                putExtra("repeat_enabled", arguments?.get("repeat_enabled") as? Boolean ?: true)
                putExtra("flashlight_enabled", arguments?.get("flashlight_enabled") as? Boolean ?: false)
                putExtra("flash_pattern", arguments?.get("flash_pattern") as? String ?: "single")
                putExtra("voice_enabled", arguments?.get("voice_enabled") as? Boolean ?: false)
                putExtra(
                    "voice_lock_command_enabled",
                    arguments?.get("voice_lock_command_enabled") as? Boolean ?: false,
                )
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            result.success(null)
        } catch (error: Exception) {
            result.error(
                "monitoring_start_failed",
                error.message ?: "Android could not start monitoring.",
                null,
            )
        }
    }

    private fun installVoiceModel(result: MethodChannel.Result) {
        synchronized(this) {
            if (modelInstallInProgress) {
                result.error(
                    "model_install_in_progress",
                    "The offline voice model is already being installed.",
                    null,
                )
                return
            }
            modelInstallInProgress = true
        }
        Thread({
            try {
                val directory = VoiceModelInstaller.install(this) { downloaded, total ->
                    mainHandler.post {
                        MonitoringEventBus.emit(mapOf(
                            "type" to "voice_model_progress",
                            "downloaded_bytes" to downloaded,
                            "total_bytes" to total,
                        ))
                    }
                }
                mainHandler.post {
                    modelInstallInProgress = false
                    MonitoringEventBus.emit(mapOf(
                        "type" to "voice_model_ready",
                        "model" to VoiceModelInstaller.MODEL_DIRECTORY,
                    ))
                    result.success(directory.absolutePath)
                }
            } catch (error: Exception) {
                mainHandler.post {
                    modelInstallInProgress = false
                    result.error(
                        "voice_model_install_failed",
                        error.message ?: "Could not install the offline voice model.",
                        null,
                    )
                }
            }
        }, "VoiceMateModelInstaller").start()
    }

    private fun previewAlert(arguments: Map<*, *>?, result: MethodChannel.Result) {
        if (!activityResumed) {
            result.error("activity_not_visible", "Open VoiceMate before previewing alerts.", null)
            return
        }
        try {
            alertPreview?.release()
            flashlightPreview?.stop()
            flashlightPreview = null
            val bundle = Bundle().apply {
                putBoolean("sound_enabled", arguments?.get("sound_enabled") as? Boolean ?: true)
                putBoolean("vibration_enabled", arguments?.get("vibration_enabled") as? Boolean ?: true)
                putString("sound_id", arguments?.get("sound_id") as? String ?: "classic_beep")
                putInt("alert_volume", (arguments?.get("alert_volume") as? Number)?.toInt() ?: 80)
                putInt("alert_duration_seconds", (arguments?.get("alert_duration_seconds") as? Number)?.toInt() ?: 3)
                putBoolean("repeat_enabled", arguments?.get("repeat_enabled") as? Boolean ?: false)
                putBoolean("flashlight_enabled", arguments?.get("flashlight_enabled") as? Boolean ?: false)
                putString("flash_pattern", arguments?.get("flash_pattern") as? String ?: "single")
            }
            alertPreview = FinderAlertManager(this, FinderAlertConfig.fromExtras(bundle))
            alertPreview?.play()
            if (bundle.getBoolean("flashlight_enabled", false)) {
                try {
                    flashlightPreview = FlashlightManager(this)
                    flashlightPreview?.pulse(bundle.getString("flash_pattern") ?: "single")
                } catch (flashError: Exception) {
                    MonitoringEventBus.emit(mapOf(
                        "type" to "flashlight_unavailable",
                        "message" to (flashError.message
                            ?: "Android could not use the flashlight."),
                    ))
                }
            }
            result.success(null)
        } catch (error: Exception) {
            alertPreview?.release()
            alertPreview = null
            result.error(
                "alert_preview_failed",
                error.message ?: "Could not preview the alert.",
                null,
            )
        }
    }

    private fun startClapTest(result: MethodChannel.Result) {
        if (VoiceMonitoringService.isActive) {
            result.error(
                "microphone_in_use",
                "Stop background monitoring before starting the foreground diagnostic.",
                null,
            )
            return
        }
        if (!activityResumed) {
            result.error(
                "activity_not_visible",
                "Open VoiceMate before starting the microphone test.",
                null,
            )
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error(
                "permission_denied",
                "Microphone permission is required for this test.",
                null,
            )
            return
        }
        try {
            if (captureManager?.isRunning() == true) {
                result.success(null)
                return
            }
            val manager = AudioCaptureManager()
            captureManager = manager
            manager.start(
                onMetrics = { metrics ->
                    mainHandler.post {
                        testEventSink?.success(mapOf(
                            "type" to if (metrics.isClap) "clap" else "metrics",
                            "rms" to metrics.rms,
                            "peak" to metrics.peak,
                            "noise_floor" to metrics.noiseFloorRms,
                            "is_clap" to metrics.isClap,
                            "clap_count" to metrics.clapCount,
                            "is_whistle" to metrics.isWhistle,
                            "whistle_count" to metrics.whistleCount,
                            "whistle_frequency_hz" to metrics.whistleFrequencyHz,
                        ))
                    }
                },
                onError = { message ->
                    mainHandler.post {
                        stopClapTest()
                        testEventSink?.success(mapOf(
                            "type" to "error", "message" to message))
                    }
                },
            )
            result.success(null)
        } catch (error: Exception) {
            captureManager?.stop()
            captureManager = null
            result.error(
                "audio_start_failed",
                error.message ?: "Could not start microphone capture.",
                null,
            )
        }
    }

    private fun stopClapTest() {
        captureManager?.stop()
        captureManager = null
        testEventSink?.success(mapOf("type" to "stopped"))
    }

    override fun onResume() {
        super.onResume()
        activityResumed = true
    }

    override fun onPause() {
        activityResumed = false
        stopClapTest()
        super.onPause()
    }

    override fun onDestroy() {
        stopClapTest()
        alertPreview?.release()
        alertPreview = null
        flashlightPreview?.stop()
        flashlightPreview = null
        pendingPermissionResult?.error(
            "activity_destroyed",
            "The app was closed before microphone permission was resolved.",
            null,
        )
        pendingPermissionResult = null
        pendingNotificationResult?.error(
            "activity_destroyed",
            "The app was closed before notification permission was resolved.",
            null,
        )
        pendingNotificationResult = null
        pendingCameraPermissionResult?.error(
            "activity_destroyed",
            "The app was closed before camera permission was resolved.",
            null,
        )
        pendingCameraPermissionResult = null
        super.onDestroy()
    }
}
