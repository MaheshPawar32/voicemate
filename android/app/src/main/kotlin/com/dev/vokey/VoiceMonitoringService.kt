package com.dev.vokey

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.util.Log

/**
 * Explicitly started foreground microphone service for phone finding.
 * It is never started from boot, a timer, a background receiver or an ad callback,
 * and it returns START_NOT_STICKY so it is not resurrected after process death.
 */
internal class VoiceMonitoringService : Service() {
    companion object {
        const val ACTION_START = "com.dev.vokey.action.START_MONITORING"
        const val ACTION_STOP = "com.dev.vokey.action.STOP_MONITORING"
        const val ACTION_STOP_ALERT = "com.dev.vokey.action.STOP_ALERT"
        const val ACTION_SNOOZE = "com.dev.vokey.action.SNOOZE_ALERT"
        const val CHANNEL_ID = "vokey_monitoring"
        const val ALERT_CHANNEL_ID = "vokey_found_alerts"
        const val NOTIFICATION_ID = 2401
        const val ALERT_NOTIFICATION_ID = 2402
        const val SNOOZE_MS = 30_000L
        private const val TAG = "Vokey"

        /** Authoritative snapshot read by Flutter, the tile and the widget. */
        @Volatile var isActive: Boolean = false
            private set
        @Volatile private var startedAtWallMs: Long = 0L
        @Volatile private var activeConfig: MonitoringConfig? = null
        @Volatile private var voiceActive = false
        @Volatile private var alertActive = false
        @Volatile private var snoozedUntilWallMs = 0L
        @Volatile private var pocketCovered = false
        @Volatile private var pocketAvailable = true
        @Volatile private var lastDetectionType: String? = null
        @Volatile private var lastDetectionAtMs = 0L
        @Volatile private var batteryPercent = -1

        fun startedAtMs(): Long = if (isActive) startedAtWallMs else 0L

        fun activeModesLabel(): String {
            val config = activeConfig ?: return ""
            return listOfNotNull(
                "Clap".takeIf { config.clapEnabled },
                "Whistle".takeIf { config.whistleEnabled },
                "Voice".takeIf { voiceActive },
            ).joinToString(" · ")
        }

        fun statusMap(): Map<String, Any?> {
            val config = activeConfig
            return mapOf(
                "schema_version" to 1,
                "active" to isActive,
                "started_at_ms" to if (isActive) startedAtWallMs else null,
                "clap_enabled" to (isActive && config?.clapEnabled == true),
                "whistle_enabled" to (isActive && config?.whistleEnabled == true),
                "voice_enabled" to (isActive && voiceActive),
                "clap_pattern" to (config?.clapPattern ?: 1),
                "pocket_mode_enabled" to (isActive && config?.pocketModeEnabled == true),
                "pocket_available" to pocketAvailable,
                "pocket_covered" to pocketCovered,
                "alert_active" to alertActive,
                "snoozed_until_ms" to snoozedUntilWallMs.takeIf { it > System.currentTimeMillis() },
                "last_detection_type" to lastDetectionType,
                "last_detection_at_ms" to lastDetectionAtMs.takeIf { it > 0 },
                "battery_percent" to batteryPercent,
                "auto_stop_minutes" to (config?.autoStopMinutes ?: 0),
            )
        }
    }

    private var captureManager: AudioCaptureManager? = null
    private var alertManager: FinderAlertManager? = null
    private var alertConfig = FinderAlertConfig()
    private var monitoringConfig = MonitoringConfig()
    private var flashlightManager: FlashlightManager? = null
    private var voiceEngine: OfflineCommandEngine? = null
    private var voiceEnabled = false
    private var voiceLockCommandEnabled = false
    private var patternMatcher = ClapPatternMatcher(1)
    private var gate = TriggerGate(5)
    private var batteryWarned = false
    private var batteryReceiverRegistered = false
    private var sensorManager: SensorManager? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val autoStopRunnable = Runnable {
        if (isActive) shutdown(reason = "duration_limit", autoStopped = true)
    }

    private val alertEndRunnable = Runnable { clearAlertState(emit = true) }

    private val batteryReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            intent ?: return
            val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
            val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
            if (level < 0 || scale <= 0) return
            val percent = (level * 100 / scale).coerceIn(0, 100)
            batteryPercent = percent
            val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
            val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                status == BatteryManager.BATTERY_STATUS_FULL
            if (charging) batteryWarned = false
            if (BatteryGuard.shouldAutoStop(percent, charging, monitoringConfig.batteryStopPercent)) {
                shutdown(reason = "battery_low", autoStopped = true)
                return
            }
            if (BatteryGuard.shouldWarn(
                    percent, charging, monitoringConfig.batteryWarningPercent, batteryWarned,
                )
            ) {
                batteryWarned = true
                MonitoringEventBus.emit(mapOf(
                    "type" to "battery_low_warning",
                    "battery_percent" to percent,
                    "timestamp" to System.currentTimeMillis(),
                ))
            }
        }
    }

    private val proximityListener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent?) {
            val sensor = event?.sensor ?: return
            val covered = ProximityLogic.isCovered(event.values.firstOrNull() ?: Float.NaN, sensor.maximumRange)
            if (covered != pocketCovered) {
                pocketCovered = covered
                MonitoringEventBus.emit(mapOf("type" to "pocket_state", "covered" to covered))
            }
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                // Emergency/notification Stop: tears down mic, alert, torch, vibration.
                if (isActive) {
                    shutdown(reason = "user_stop", autoStopped = false)
                } else {
                    stopSelf(startId)
                }
            }
            ACTION_STOP_ALERT -> stopAlert()
            ACTION_SNOOZE -> snooze()
            else -> {
                alertConfig = FinderAlertConfig.fromExtras(intent?.extras)
                monitoringConfig = MonitoringConfig.fromExtras(intent?.extras)
                voiceEnabled = intent?.getBooleanExtra("voice_enabled", false) == true
                voiceLockCommandEnabled =
                    intent?.getBooleanExtra("voice_lock_command_enabled", false) == true
                startMonitoring()
            }
        }
        return START_NOT_STICKY
    }

    private fun startMonitoring() {
        if (isActive) return
        // startForeground must be called promptly after startForegroundService;
        // validate permissions first so we never post a misleading notification.
        if (checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            failStart("Microphone permission is required to start monitoring.")
            return
        }
        val notificationPermissionGranted = Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        val notificationsEnabled =
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).areNotificationsEnabled()
        // (areNotificationsEnabled is API 24, our minSdk.)
        if (!notificationPermissionGranted || !notificationsEnabled) {
            failStart("Enable Vokey notifications so the active monitoring notification and Stop action remain visible.")
            return
        }

        try {
            alertManager?.release()
            alertManager = FinderAlertManager(this, alertConfig) { reason ->
                MonitoringEventBus.emit(mapOf("type" to "alert_sound_unavailable", "reason" to reason))
            }
            flashlightManager?.stop()
            flashlightManager = if (alertConfig.flashlightEnabled) {
                FlashlightManager(this) { message -> emitFlashlightUnavailable(message) }
            } else {
                null
            }
            patternMatcher = ClapPatternMatcher(monitoringConfig.clapPattern)
            gate = TriggerGate(monitoringConfig.cooldownSeconds)
            batteryWarned = false

            val notification = buildMonitoringNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }

            if (voiceEnabled) {
                if (!VoiceModelInstaller.isInstalled(this)) {
                    throw IllegalStateException(
                        "Install the offline English voice model in Voice Commands before enabling voice detection.",
                    )
                }
                voiceEngine = OfflineCommandEngine(VoiceModelInstaller.modelDirectory(this))
            }

            val clapDetector = if (monitoringConfig.clapEnabled) {
                ClapDetector.forPercent(
                    monitoringConfig.clapSensitivityPercent,
                    refractoryMs = if (monitoringConfig.clapPattern > 1) 220L else 450L,
                )
            } else {
                null
            }
            val whistleDetector = if (monitoringConfig.whistleEnabled) {
                WhistleDetector.forSettings(
                    monitoringConfig.whistleSensitivityPercent,
                    monitoringConfig.whistleMinHz,
                    monitoringConfig.whistleMaxHz,
                    monitoringConfig.whistleMinDurationMs,
                )
            } else {
                null
            }

            isActive = true
            startedAtWallMs = System.currentTimeMillis()
            activeConfig = monitoringConfig
            voiceActive = voiceEnabled
            snoozedUntilWallMs = 0L
            lastDetectionType = null
            lastDetectionAtMs = 0L

            val manager = AudioCaptureManager(clapDetector, whistleDetector)
            captureManager = manager
            manager.start(
                onVoiceCommand = { command -> mainHandler.post { handleVoiceCommand(command) } },
                voiceEngine = voiceEngine,
                onMetrics = { metrics -> mainHandler.post { handleMetrics(metrics) } },
                onError = { message ->
                    mainHandler.post {
                        MonitoringEventBus.emit(mapOf("type" to "service_error", "message" to message))
                        shutdown(reason = "capture_error", autoStopped = false)
                    }
                },
            )

            startBatteryMonitoring()
            startPocketMode()
            if (monitoringConfig.autoStopMinutes > 0) {
                mainHandler.removeCallbacks(autoStopRunnable)
                mainHandler.postDelayed(autoStopRunnable, monitoringConfig.autoStopMinutes * 60_000L)
            }
            MonitoringEventBus.emit(mapOf(
                "type" to "service_started",
                "started_at_ms" to startedAtWallMs,
                "auto_stop_minutes" to monitoringConfig.autoStopMinutes,
            ))
            VokeyStateBroadcaster.publish(this)
        } catch (error: Exception) {
            Log.e(TAG, "Could not start microphone monitoring: ${error.javaClass.simpleName}")
            releaseAll()
            MonitoringEventBus.emit(mapOf(
                "type" to "service_error",
                "message" to (error.message ?: "Could not start microphone monitoring."),
            ))
            stopSelf()
        }
    }

    private fun failStart(message: String) {
        MonitoringEventBus.emit(mapOf("type" to "service_error", "message" to message))
        stopSelf()
    }

    /** Runs on the main thread. */
    private fun handleMetrics(metrics: AudioCaptureManager.Metrics) {
        if (!isActive) return
        if (MonitoringEventBus.hasListener()) {
            MonitoringEventBus.emit(mapOf(
                "type" to "level",
                "rms" to metrics.rms,
                "peak" to metrics.peak,
                "noise_floor" to metrics.noiseFloorRms,
            ))
        }
        val now = SystemClock.elapsedRealtime()
        patternMatcher.expireIfStale(now)
        var eventType: String? = null
        if (metrics.isClap) {
            val complete = patternMatcher.onClap(now)
            MonitoringEventBus.emit(mapOf(
                "type" to "clap_progress",
                "count" to if (complete) patternMatcher.requiredClaps else patternMatcher.progress,
                "required" to patternMatcher.requiredClaps,
            ))
            if (complete) eventType = "clap"
        }
        if (eventType == null && metrics.isWhistle) eventType = "whistle"
        if (eventType != null) {
            onTrigger(eventType, mapOf(
                "clap_pattern" to patternMatcher.requiredClaps,
                "whistle_frequency_hz" to (metrics.whistleFrequencyHz ?: 0),
                "rms" to metrics.rms,
                "peak" to metrics.peak,
            ))
        }
    }

    /** Common path for clap, whistle and voice "find my phone". */
    private fun onTrigger(eventType: String, metadata: Map<String, Any>) {
        val now = SystemClock.elapsedRealtime()
        if (!gate.tryTrigger(now)) return // cooldown or snooze — not an event
        val quietHours = monitoringConfig.isQuietHoursNow()
        val inPocket = monitoringConfig.pocketModeEnabled && pocketCovered
        val suppressedReason = when {
            quietHours -> "quiet_hours"
            inPocket -> "pocket_mode"
            else -> null
        }
        lastDetectionType = eventType
        lastDetectionAtMs = System.currentTimeMillis()
        if (suppressedReason == null) startAlert(eventType)
        MonitoringEventBus.emit(mapOf(
            "type" to "detection",
            "event_type" to eventType,
            "alert_played" to (suppressedReason == null),
            "suppressed_reason" to (suppressedReason ?: ""),
            "quiet_hours" to quietHours,
            "timestamp" to lastDetectionAtMs,
        ) + metadata)
        VokeyStateBroadcaster.publish(this)
    }

    private fun startAlert(eventType: String) {
        alertManager?.play()
        if (alertConfig.flashlightEnabled) {
            try {
                flashlightManager?.pulse(alertConfig.flashPattern)
            } catch (error: Exception) {
                emitFlashlightUnavailable(error.message ?: "Android could not use the flashlight.")
            }
        }
        alertActive = true
        mainHandler.removeCallbacks(alertEndRunnable)
        mainHandler.postDelayed(alertEndRunnable, alertConfig.durationSeconds * 1_000L + 500L)
        postFoundNotification(eventType)
    }

    private fun stopAlert() {
        alertManager?.stop()
        flashlightManager?.stop()
        clearAlertState(emit = true)
    }

    private fun snooze() {
        val now = SystemClock.elapsedRealtime()
        gate.snooze(now, SNOOZE_MS)
        snoozedUntilWallMs = System.currentTimeMillis() + SNOOZE_MS
        alertManager?.stop()
        flashlightManager?.stop()
        clearAlertState(emit = false)
        MonitoringEventBus.emit(mapOf(
            "type" to "alert_snoozed",
            "snoozed_until_ms" to snoozedUntilWallMs,
        ))
        VokeyStateBroadcaster.publish(this)
    }

    private fun clearAlertState(emit: Boolean) {
        mainHandler.removeCallbacks(alertEndRunnable)
        val wasActive = alertActive
        alertActive = false
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).cancel(ALERT_NOTIFICATION_ID)
        if (emit && wasActive) MonitoringEventBus.emit(mapOf("type" to "alert_stopped"))
    }

    private fun handleVoiceCommand(command: String) {
        when (command) {
            "find_phone" -> onTrigger("voice", mapOf("command" to "find_phone"))
            "lock_phone" -> {
                if (!voiceLockCommandEnabled) {
                    MonitoringEventBus.emit(mapOf(
                        "type" to "voice_command_ignored",
                        "reason" to "voice_lock_not_enabled",
                    ))
                    return
                }
                val locked = try {
                    DeviceLockManager(this).lockNow()
                } catch (_: Exception) {
                    false
                }
                MonitoringEventBus.emit(mapOf(
                    "type" to if (locked) "voice_command" else "voice_command_ignored",
                    "command" to "lock_phone",
                    "reason" to if (locked) "locked" else "device_admin_not_active",
                    "timestamp" to System.currentTimeMillis(),
                ))
            }
            "stop_monitoring" -> {
                MonitoringEventBus.emit(mapOf(
                    "type" to "voice_command",
                    "command" to "stop_monitoring",
                    "timestamp" to System.currentTimeMillis(),
                ))
                shutdown(reason = "voice_stop", autoStopped = false)
            }
        }
    }

    private fun startBatteryMonitoring() {
        if (monitoringConfig.batteryWarningPercent <= 0 && monitoringConfig.batteryStopPercent <= 0) {
            return
        }
        // ACTION_BATTERY_CHANGED is a sticky system broadcast; registering is cheap
        // and avoids polling or wake locks.
        registerReceiver(batteryReceiver, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        batteryReceiverRegistered = true
    }

    private fun startPocketMode() {
        pocketCovered = false
        if (!monitoringConfig.pocketModeEnabled) return
        val manager = getSystemService(SENSOR_SERVICE) as? SensorManager
        val sensor = manager?.getDefaultSensor(Sensor.TYPE_PROXIMITY)
        if (manager == null || sensor == null) {
            pocketAvailable = false
            MonitoringEventBus.emit(mapOf("type" to "pocket_mode_unavailable"))
            return
        }
        pocketAvailable = true
        sensorManager = manager
        manager.registerListener(proximityListener, sensor, SensorManager.SENSOR_DELAY_NORMAL)
    }

    /** Single teardown path for every stop source. */
    private fun shutdown(reason: String, autoStopped: Boolean) {
        val durationMs = if (isActive) System.currentTimeMillis() - startedAtWallMs else 0L
        val wasRunning = isActive
        releaseAll()
        if (wasRunning) {
            MonitoringEventBus.emit(mapOf(
                "type" to if (autoStopped) "service_auto_stopped" else "service_stopped",
                "reason" to reason,
                "duration_ms" to durationMs,
                "timestamp" to System.currentTimeMillis(),
            ))
        }
        VokeyStateBroadcaster.publish(this)
        stopSelf()
    }

    private fun releaseAll() {
        mainHandler.removeCallbacks(autoStopRunnable)
        captureManager?.stop()
        captureManager = null
        try {
            voiceEngine?.close()
        } catch (_: Exception) {
            // Native model already released.
        }
        voiceEngine = null
        alertManager?.release()
        alertManager = null
        flashlightManager?.stop()
        flashlightManager = null
        clearAlertState(emit = false)
        if (batteryReceiverRegistered) {
            try {
                unregisterReceiver(batteryReceiver)
            } catch (_: IllegalArgumentException) {
                // Already unregistered.
            }
            batteryReceiverRegistered = false
        }
        sensorManager?.unregisterListener(proximityListener)
        sensorManager = null
        isActive = false
        activeConfig = null
        voiceActive = false
        pocketCovered = false
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    private fun emitFlashlightUnavailable(message: String) {
        MonitoringEventBus.emit(mapOf("type" to "flashlight_unavailable", "message" to message))
    }

    private fun servicePendingIntent(action: String, requestCode: Int): PendingIntent =
        PendingIntent.getService(
            this,
            requestCode,
            Intent(this, VoiceMonitoringService::class.java).setAction(action),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun openAppPendingIntent(): PendingIntent =
        PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun buildMonitoringNotification(): Notification {
        val modes = mutableListOf<String>()
        if (monitoringConfig.clapEnabled) {
            modes.add(when (monitoringConfig.clapPattern) {
                2 -> "double claps"
                3 -> "triple claps"
                else -> "claps"
            })
        }
        if (monitoringConfig.whistleEnabled) modes.add("whistles")
        if (voiceEnabled) modes.add("voice commands")
        val extras = buildString {
            if (monitoringConfig.autoStopMinutes > 0) {
                append(" · auto-stop in ${monitoringConfig.autoStopMinutes} min")
            }
            if (monitoringConfig.quietHoursEnabled) {
                append(" · alerts muted ${monitoringConfig.quietStart}–${monitoringConfig.quietEnd}")
            }
        }
        return notificationBuilder(CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_vokey)
            .setContentTitle("Vokey is listening")
            .setContentText("Listening for " + modes.joinToString(", ") + extras)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setContentIntent(openAppPendingIntent())
            .addAction(
                Notification.Action.Builder(null, "Stop", servicePendingIntent(ACTION_STOP, 1)).build(),
            )
            .build()
    }

    private fun postFoundNotification(eventType: String) {
        val title = when (eventType) {
            "clap" -> "Phone found — clap detected"
            "whistle" -> "Phone found — whistle detected"
            else -> "Phone found — voice command"
        }
        val notification = notificationBuilder(ALERT_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_vokey)
            .setContentTitle(title)
            .setContentText("Tap Stop alert when you have your phone.")
            .setCategory(Notification.CATEGORY_ALARM)
            .setContentIntent(openAppPendingIntent())
            .setAutoCancel(true)
            .apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    setTimeoutAfter(alertConfig.durationSeconds * 1_000L + 1_000L)
                }
            }
            .addAction(
                Notification.Action.Builder(null, "Stop alert", servicePendingIntent(ACTION_STOP_ALERT, 2)).build(),
            )
            .addAction(
                Notification.Action.Builder(null, "Snooze 30s", servicePendingIntent(ACTION_SNOOZE, 3)).build(),
            )
            .addAction(
                Notification.Action.Builder(null, "Stop listening", servicePendingIntent(ACTION_STOP, 4)).build(),
            )
            .build()
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .notify(ALERT_NOTIFICATION_ID, notification)
    }

    @Suppress("DEPRECATION")
    private fun notificationBuilder(channelId: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            Notification.Builder(this).setPriority(
                if (channelId == ALERT_CHANNEL_ID) Notification.PRIORITY_HIGH else Notification.PRIORITY_LOW,
            )
        }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID, "Phone finder monitoring", NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Visible status while Vokey listens for claps, whistles and voice commands."
                setShowBadge(false)
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                ALERT_CHANNEL_ID, "Phone found alerts", NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Shown when Vokey detects your clap, whistle or voice, with Stop and Snooze actions."
                // The finder alert itself plays the sound; the notification stays silent.
                setSound(null, null)
                enableVibration(false)
            },
        )
    }

    override fun onDestroy() {
        if (isActive) {
            shutdown(reason = "service_destroyed", autoStopped = false)
        } else {
            releaseAll()
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
