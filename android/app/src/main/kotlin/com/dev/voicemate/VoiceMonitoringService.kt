package com.dev.voicemate

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log

/**
 * Explicitly started foreground microphone service for clap-based phone finding.
 * It is never started from boot, a timer, or a background receiver.
 */
internal class VoiceMonitoringService : Service() {
    companion object {
        const val ACTION_START = "com.dev.voicemate.action.START_MONITORING"
        const val ACTION_STOP = "com.dev.voicemate.action.STOP_MONITORING"
        const val CHANNEL_ID = "voicemate_monitoring"
        const val NOTIFICATION_ID = 2401

        @Volatile
        var isActive: Boolean = false
            private set
    }

    private var captureManager: AudioCaptureManager? = null
    private var alertManager: FinderAlertManager? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        alertManager = FinderAlertManager(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopMonitoring()
                stopSelf(startId)
            }
            else -> startMonitoring()
        }
        return START_NOT_STICKY
    }

    private fun startMonitoring() {
        if (isActive) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            MonitoringEventBus.emit(mapOf(
                "type" to "service_error",
                "message" to "Microphone permission is required to start monitoring.",
            ))
            stopSelf()
            return
        }

        try {
            val notification = buildNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }

            val manager = AudioCaptureManager()
            captureManager = manager
            manager.start(
                onMetrics = { metrics ->
                    if (metrics.isClap || metrics.isWhistle) {
                        alertManager?.play()
                        val eventType = if (metrics.isClap) "clap" else "whistle"
                        MonitoringEventBus.emit(mapOf(
                            "type" to "detection",
                            "event_type" to eventType,
                            "clap_count" to metrics.clapCount,
                            "whistle_count" to metrics.whistleCount,
                            "whistle_frequency_hz" to (metrics.whistleFrequencyHz ?: 0),
                            "rms" to metrics.rms,
                            "peak" to metrics.peak,
                            "timestamp" to System.currentTimeMillis(),
                        ))
                    }
                },
                onError = { message ->
                    MonitoringEventBus.emit(mapOf(
                        "type" to "service_error",
                        "message" to message,
                    ))
                    stopSelf()
                },
            )
            isActive = true
            MonitoringEventBus.emit(mapOf("type" to "service_started"))
        } catch (error: Exception) {
            Log.e("VoiceMate", "Could not start microphone monitoring", error)
            stopMonitoring()
            MonitoringEventBus.emit(mapOf(
                "type" to "service_error",
                "message" to (error.message ?: "Could not start microphone monitoring."),
            ))
            stopSelf()
        }
    }

    private fun stopMonitoring() {
        captureManager?.stop()
        captureManager = null
        alertManager?.stop()
        isActive = false
        stopForeground(true)
        MonitoringEventBus.emit(mapOf("type" to "service_stopped"))
    }

    private fun buildNotification(): Notification {
        val stopIntent = Intent(this, VoiceMonitoringService::class.java).apply {
            action = ACTION_STOP
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
        val stopPendingIntent = PendingIntent.getService(
            this, NOTIFICATION_ID, stopIntent, flags,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this).setPriority(Notification.PRIORITY_LOW)
        }
        return builder
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("VoiceMate is monitoring")
            .setContentText("Listening for clap or whistle signals. Tap Stop to end monitoring.")
            .setCategory(Notification.CATEGORY_SERVICE)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .addAction(android.R.drawable.ic_media_pause, "Stop", stopPendingIntent)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Phone finder monitoring",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Visible status while VoiceMate listens for clap signals."
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        stopMonitoring()
        alertManager?.release()
        alertManager = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

private class FinderAlertManager(service: Service) {
    private val tone = ToneGenerator(AudioManager.STREAM_ALARM, 90)
    private val vibrator =
        service.getSystemService(Service.VIBRATOR_SERVICE) as? Vibrator
    private var lastPlayedAt = 0L

    fun play() {
        val now = SystemClock.elapsedRealtime()
        if (now - lastPlayedAt < 2_500L) return
        lastPlayedAt = now
        tone.startTone(ToneGenerator.TONE_PROP_BEEP, 1_000)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(
                VibrationEffect.createWaveform(
                    longArrayOf(0, 220, 140, 220),
                    -1,
                ),
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(longArrayOf(0, 220, 140, 220), -1)
        }
    }

    fun stop() {
        tone.stopTone()
        vibrator?.cancel()
    }

    fun release() {
        stop()
        tone.release()
    }
}
