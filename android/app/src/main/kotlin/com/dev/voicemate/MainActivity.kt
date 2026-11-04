package com.dev.voicemate

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
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
        private const val REQUEST_MICROPHONE = 7401
        private const val REQUEST_NOTIFICATIONS = 7402
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var testEventSink: EventChannel.EventSink? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingNotificationResult: MethodChannel.Result? = null
    private var captureManager: AudioCaptureManager? = null
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
                "startMonitoring" -> startMonitoring(result)
                "stopMonitoring" -> {
                    stopService(Intent(this, VoiceMonitoringService::class.java))
                    result.success(null)
                }
                "getMonitoringStatus" -> result.success(VoiceMonitoringService.isActive)
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
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
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

    private fun startMonitoring(result: MethodChannel.Result) {
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
        try {
            val intent = Intent(this, VoiceMonitoringService::class.java).apply {
                action = VoiceMonitoringService.ACTION_START
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
        super.onDestroy()
    }
}
