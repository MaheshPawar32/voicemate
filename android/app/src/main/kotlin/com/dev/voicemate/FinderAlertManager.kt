package com.dev.voicemate

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator

internal data class FinderAlertConfig(
    val soundEnabled: Boolean = true,
    val vibrationEnabled: Boolean = true,
    val soundId: String = "classic_beep",
    val volume: Int = 80,
    val durationSeconds: Int = 5,
    val repeatEnabled: Boolean = true,
) {
    companion object {
        fun fromExtras(extras: android.os.Bundle?): FinderAlertConfig =
            FinderAlertConfig(
                soundEnabled = extras?.getBoolean("sound_enabled", true) ?: true,
                vibrationEnabled = extras?.getBoolean("vibration_enabled", true) ?: true,
                soundId = extras?.getString("sound_id") ?: "classic_beep",
                volume = (extras?.getInt("alert_volume", 80) ?: 80).coerceIn(0, 100),
                durationSeconds =
                    (extras?.getInt("alert_duration_seconds", 5) ?: 5).coerceIn(1, 30),
                repeatEnabled = extras?.getBoolean("repeat_enabled", true) ?: true,
            )
    }
}

/** Plays short, bounded on-device tones and haptics; it never records or streams audio. */
internal class FinderAlertManager(
    context: Context,
    private val config: FinderAlertConfig,
) {
    companion object {
        private const val REPEAT_INTERVAL_MS = 1_300L
        private const val PULSE_DURATION_MS = 650
    }

    private val handler = Handler(Looper.getMainLooper())
    private val vibrator =
        context.applicationContext.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    private var tone: ToneGenerator? = null
    private var deadlineMs = 0L
    private var lastStartedAtMs = 0L
    private var isPlaying = false

    private val cycle = object : Runnable {
        override fun run() {
            if (!isPlaying) return
            val now = SystemClock.elapsedRealtime()
            if (now >= deadlineMs) {
                stopNow()
                return
            }

            if (config.soundEnabled) {
                tone?.startTone(toneType(config.soundId), PULSE_DURATION_MS)
            }
            if (config.vibrationEnabled) vibratePulse()

            if (config.repeatEnabled && now + REPEAT_INTERVAL_MS < deadlineMs) {
                handler.postDelayed(this, REPEAT_INTERVAL_MS)
            } else {
                handler.postDelayed(stopRunnable, (deadlineMs - now).coerceAtLeast(0L))
            }
        }
    }

    private val stopRunnable = Runnable { stopNow() }

    init {
        if (config.soundEnabled && config.volume > 0) {
            tone = ToneGenerator(AudioManager.STREAM_ALARM, config.volume)
        }
    }

    fun play() {
        handler.post {
            val now = SystemClock.elapsedRealtime()
            if (now - lastStartedAtMs < 2_500L) return@post
            lastStartedAtMs = now
            stopNow()
            val hasOutput = config.soundEnabled || config.vibrationEnabled
            if (!hasOutput) return@post
            deadlineMs = now + config.durationSeconds * 1_000L
            isPlaying = true
            cycle.run()
        }
    }

    fun stop() {
        handler.post { stopNow() }
    }

    private fun stopNow() {
        isPlaying = false
        handler.removeCallbacks(cycle)
        handler.removeCallbacks(stopRunnable)
        tone?.stopTone()
        vibrator?.cancel()
    }

    private fun vibratePulse() {
        if (vibrator == null) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(
                VibrationEffect.createWaveform(longArrayOf(0, 180, 100, 180), -1),
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(longArrayOf(0, 180, 100, 180), -1)
        }
    }

    private fun toneType(soundId: String): Int = when (soundId) {
        "soft_chime" -> ToneGenerator.TONE_PROP_PROMPT
        "double_beep" -> ToneGenerator.TONE_PROP_ACK
        "alert_tone" -> ToneGenerator.TONE_PROP_NACK
        else -> ToneGenerator.TONE_PROP_BEEP
    }

    fun release() {
        stopNow()
        tone?.release()
        tone = null
    }
}
