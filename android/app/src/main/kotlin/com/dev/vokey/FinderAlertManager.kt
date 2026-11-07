package com.dev.vokey

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import java.io.File

internal data class FinderAlertConfig(
    val soundEnabled: Boolean = true,
    val vibrationEnabled: Boolean = true,
    val soundId: String = "classic_beep",
    /** Maximum player gain, 0–100. */
    val volume: Int = 80,
    val durationSeconds: Int = 5,
    val repeatEnabled: Boolean = true,
    val flashlightEnabled: Boolean = false,
    val flashPattern: String = "single",
    val rampEnabled: Boolean = true,
    /** Starting level as % of [volume]. */
    val rampStartPercent: Int = 25,
    val rampSeconds: Int = 10,
    val outputPolicy: OutputPolicy = OutputPolicy.AUTO,
    /** `<uuid>.<ext>` inside filesDir/custom_sounds when soundId is custom. */
    val customSoundFile: String? = null,
) {
    companion object {
        fun fromExtras(extras: android.os.Bundle?): FinderAlertConfig {
            fun bool(key: String, def: Boolean) = extras?.getBoolean(key, def) ?: def
            fun int(key: String, def: Int) = extras?.getInt(key, def) ?: def
            return FinderAlertConfig(
                soundEnabled = bool("sound_enabled", true),
                vibrationEnabled = bool("vibration_enabled", true),
                soundId = extras?.getString("sound_id") ?: "classic_beep",
                volume = int("alert_volume", 80).coerceIn(0, 100),
                durationSeconds = int("alert_duration_seconds", 5).coerceIn(1, 60),
                repeatEnabled = bool("repeat_enabled", true),
                flashlightEnabled = bool("flashlight_enabled", false),
                flashPattern = extras?.getString("flash_pattern") ?: "single",
                rampEnabled = bool("volume_ramp_enabled", true),
                rampStartPercent = int("volume_ramp_start_percent", 25).coerceIn(0, 100),
                rampSeconds = int("volume_ramp_seconds", 10).coerceIn(1, 60),
                outputPolicy = OutputPolicy.fromId(extras?.getString("output_policy")),
                customSoundFile = extras?.getString("custom_sound_file")
                    ?.takeIf { CustomSoundFiles.isSafeFileName(it) },
            )
        }
    }
}

/**
 * Plays bounded on-device alerts: sound (alarm stream, rising volume, chosen
 * output), vibration pulses. Never records audio and never changes the
 * device's volume settings. All calls must be on (or are posted to) the main thread.
 */
internal class FinderAlertManager(
    context: Context,
    private val config: FinderAlertConfig,
    private val onSoundUnavailable: (String) -> Unit = {},
) {
    companion object {
        private const val TAG = "Vokey"
        private const val VIBRATION_INTERVAL_MS = 1_300L
        private const val RAMP_TICK_MS = 150L
        private const val RETRIGGER_GUARD_MS = 2_500L

        fun customSoundDir(context: Context) = File(context.filesDir, "custom_sounds")

        /** Built-in tones are synthesised once into app-private cache. */
        fun builtInToneFile(context: Context, soundId: String): File {
            val id = if (soundId in ToneSynth.builtInIds) soundId else "classic_beep"
            val dir = File(context.cacheDir, "tones").apply { mkdirs() }
            val file = File(dir, "$id-v1.wav")
            if (!file.isFile || file.length() < 1_000) file.writeBytes(ToneSynth.wavBytes(id))
            return file
        }
    }

    private val appContext = context.applicationContext
    private val handler = Handler(Looper.getMainLooper())
    private val audioManager = appContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val vibrator = appContext.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    private var player: MediaPlayer? = null
    private var focusRequest: AudioFocusRequest? = null
    private var deviceCallbackRegistered = false
    private var startedAtMs = 0L
    private var lastStartedAtMs = 0L
    private var playing = false

    val isPlaying: Boolean get() = playing

    private val alarmAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    private val stopRunnable = Runnable { stopNow() }

    private val vibrationCycle = object : Runnable {
        override fun run() {
            if (!playing || !config.vibrationEnabled) return
            vibratePulse()
            if (config.repeatEnabled) handler.postDelayed(this, VIBRATION_INTERVAL_MS)
        }
    }

    private val rampTick = object : Runnable {
        override fun run() {
            val p = player ?: return
            val elapsed = SystemClock.elapsedRealtime() - startedAtMs
            val gain = currentGain(elapsed)
            try {
                p.setVolume(gain, gain)
            } catch (_: IllegalStateException) {
                return
            }
            if (config.rampEnabled && elapsed < config.rampSeconds * 1_000L) {
                handler.postDelayed(this, RAMP_TICK_MS)
            }
        }
    }

    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        // A call or another alarm took audio focus: go quiet rather than
        // ringing over it. Vibration/flash continue until the alert ends.
        if (change == AudioManager.AUDIOFOCUS_LOSS ||
            change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT
        ) {
            handler.post { releasePlayer() }
        }
    }

    private val deviceCallback = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>?) = reroute()
        override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) = reroute()
    }

    private fun currentGain(elapsedMs: Long): Float = if (config.rampEnabled) {
        VolumeRamp.gainAt(elapsedMs, config.rampStartPercent, config.volume, config.rampSeconds * 1_000L)
    } else {
        config.volume / 100f
    }

    fun play() {
        handler.post {
            val now = SystemClock.elapsedRealtime()
            if (now - lastStartedAtMs < RETRIGGER_GUARD_MS) return@post
            lastStartedAtMs = now
            stopNow()
            if (!config.soundEnabled && !config.vibrationEnabled) return@post
            playing = true
            startedAtMs = now
            if (config.soundEnabled && config.volume > 0) startSound()
            if (config.vibrationEnabled) vibrationCycle.run()
            handler.postDelayed(stopRunnable, config.durationSeconds * 1_000L)
        }
    }

    fun stop() {
        handler.post { stopNow() }
    }

    fun release() {
        stopNow()
    }

    private fun headphoneDevices(): List<AudioDeviceInfo> =
        audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).filter {
            it.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
                it.type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                it.type == AudioDeviceInfo.TYPE_USB_HEADSET ||
                it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                (Build.VERSION.SDK_INT >= 31 && it.type == AudioDeviceInfo.TYPE_BLE_HEADSET)
        }

    private fun speakerDevice(): AudioDeviceInfo? =
        audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            .firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }

    private fun soundSource(): File? {
        val custom = config.customSoundFile
        if (config.soundId.startsWith("custom:") && custom != null) {
            val file = File(customSoundDir(appContext), custom)
            if (file.isFile) return file
            onSoundUnavailable("custom_sound_missing")
        }
        return try {
            builtInToneFile(appContext, config.soundId)
        } catch (error: Exception) {
            Log.w(TAG, "Tone synthesis failed: ${error.javaClass.simpleName}")
            null
        }
    }

    private fun startSound() {
        val decision = OutputRouting.decide(config.outputPolicy, headphoneDevices().isNotEmpty())
        if (decision == OutputDecision.SKIP_SOUND) {
            onSoundUnavailable("no_headphones")
            return
        }
        val source = soundSource() ?: return
        if (!requestFocus()) {
            onSoundUnavailable("audio_focus_denied")
            return
        }
        try {
            val p = MediaPlayer()
            p.setAudioAttributes(alarmAttributes)
            p.setDataSource(source.absolutePath)
            p.isLooping = config.repeatEnabled
            p.prepare()
            applyRoute(p, decision)
            val gain = currentGain(0)
            p.setVolume(gain, gain)
            p.setOnCompletionListener { if (!config.repeatEnabled) releasePlayer() }
            p.setOnErrorListener { _, _, _ ->
                handler.post { releasePlayer() }
                true
            }
            p.start()
            player = p
            if (config.rampEnabled) handler.postDelayed(rampTick, RAMP_TICK_MS)
            if (!deviceCallbackRegistered) {
                audioManager.registerAudioDeviceCallback(deviceCallback, handler)
                deviceCallbackRegistered = true
            }
        } catch (error: Exception) {
            Log.w(TAG, "Alert playback failed: ${error.javaClass.simpleName}")
            releasePlayer()
            onSoundUnavailable("playback_failed")
        }
    }

    /** MediaPlayer.setPreferredDevice exists from API 28; older devices use Android's routing. */
    private fun applyRoute(p: MediaPlayer, decision: OutputDecision) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return
        val device = when (decision) {
            OutputDecision.PLAY_ON_SPEAKER -> speakerDevice()
            OutputDecision.PLAY_ON_HEADPHONES -> headphoneDevices().firstOrNull()
            else -> null
        }
        p.setPreferredDevice(device)
    }

    /** Headphones plugged/unplugged while ringing. */
    private fun reroute() {
        val p = player ?: return
        when (val decision = OutputRouting.decide(config.outputPolicy, headphoneDevices().isNotEmpty())) {
            OutputDecision.SKIP_SOUND -> {
                // Headphones-only and they were just removed: never fall back to the speaker.
                releasePlayer()
                onSoundUnavailable("no_headphones")
            }
            else -> try {
                applyRoute(p, decision)
            } catch (_: IllegalStateException) {
                // Player already finished.
            }
        }
    }

    private fun requestFocus(): Boolean {
        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(alarmAttributes)
                .setOnAudioFocusChangeListener(focusListener, handler)
                .build()
            focusRequest = request
            audioManager.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                focusListener, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT,
            )
        }
        return granted == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    private fun abandonFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
            focusRequest = null
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(focusListener)
        }
    }

    private fun releasePlayer() {
        handler.removeCallbacks(rampTick)
        player?.let {
            try {
                if (it.isPlaying) it.stop()
            } catch (_: IllegalStateException) {
                // Already stopped.
            }
            it.release()
        }
        player = null
        if (deviceCallbackRegistered) {
            audioManager.unregisterAudioDeviceCallback(deviceCallback)
            deviceCallbackRegistered = false
        }
        abandonFocus()
    }

    private fun stopNow() {
        playing = false
        handler.removeCallbacks(stopRunnable)
        handler.removeCallbacks(vibrationCycle)
        releasePlayer()
        vibrator?.cancel()
    }

    private fun vibratePulse() {
        val v = vibrator ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            v.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 180, 100, 180), -1))
        } else {
            @Suppress("DEPRECATION")
            v.vibrate(longArrayOf(0, 180, 100, 180), -1)
        }
    }
}
