package com.dev.vokey

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.min
import kotlin.math.sin

/** Pure alert decisions (JVM-testable; see AlertLogicTest). */

/**
 * Rising alert volume applied to Vokey's own player via MediaPlayer.setVolume.
 * The device's stream volume is never changed.
 */
internal object VolumeRamp {
    /**
     * @param startPercent level at t=0 as a percentage of [maxPercent]
     * @return player gain 0..1
     */
    fun gainAt(elapsedMs: Long, startPercent: Int, maxPercent: Int, rampMs: Long): Float {
        val max = maxPercent.coerceIn(0, 100) / 100f
        if (rampMs <= 0) return max
        val start = max * startPercent.coerceIn(0, 100) / 100f
        val t = (elapsedMs.coerceAtLeast(0).toFloat() / rampMs).coerceAtMost(1f)
        return start + (max - start) * t
    }
}

internal enum class OutputPolicy(val id: String) {
    AUTO("auto"),
    SPEAKER("speaker"),
    HEADPHONES("headphones");

    companion object {
        fun fromId(id: String?): OutputPolicy = entries.firstOrNull { it.id == id } ?: AUTO
    }
}

internal enum class OutputDecision { PLAY_DEFAULT, PLAY_ON_SPEAKER, PLAY_ON_HEADPHONES, SKIP_SOUND }

internal object OutputRouting {
    /**
     * AUTO: Android routes the alarm stream (most phones ring the speaker even
     * with headphones in). SPEAKER: prefer the built-in speaker.
     * HEADPHONES: play only when headphones are connected; otherwise stay
     * silent (vibration/flash still run).
     */
    fun decide(policy: OutputPolicy, headphonesConnected: Boolean): OutputDecision = when (policy) {
        OutputPolicy.AUTO -> OutputDecision.PLAY_DEFAULT
        OutputPolicy.SPEAKER -> OutputDecision.PLAY_ON_SPEAKER
        OutputPolicy.HEADPHONES ->
            if (headphonesConnected) OutputDecision.PLAY_ON_HEADPHONES else OutputDecision.SKIP_SOUND
    }
}

/** Imported sounds live as `<uuid>.<ext>` in app-private storage. */
internal object CustomSoundFiles {
    val allowedExtensions = setOf("mp3", "m4a", "aac", "ogg", "oga", "wav", "flac", "opus")
    const val MAX_BYTES = 10L * 1024 * 1024
    const val MAX_DURATION_MS = 120_000L
    const val MIN_DURATION_MS = 200L
    private val safeName = Regex("^[A-Za-z0-9_-]{1,64}\\.([a-z0-9]{2,5})$")

    /** Rejects anything that could escape the private directory. */
    fun isSafeFileName(name: String?): Boolean {
        val match = name?.let { safeName.matchEntire(it) } ?: return false
        return match.groupValues[1] in allowedExtensions
    }

    fun extensionFor(mimeType: String?, displayName: String?): String? {
        val fromMime = when (mimeType?.lowercase()) {
            "audio/mpeg", "audio/mp3" -> "mp3"
            "audio/mp4", "audio/m4a", "audio/x-m4a", "audio/aac", "audio/aacp" -> "m4a"
            "audio/ogg", "application/ogg" -> "ogg"
            "audio/opus" -> "opus"
            "audio/wav", "audio/x-wav", "audio/wave" -> "wav"
            "audio/flac", "audio/x-flac" -> "flac"
            else -> null
        }
        if (fromMime != null) return fromMime
        val ext = displayName?.substringAfterLast('.', "")?.lowercase()
        return ext?.takeIf { it in allowedExtensions }
    }

    fun validate(sizeBytes: Long, durationMs: Long): String? = when {
        sizeBytes <= 0 -> "The file is empty."
        sizeBytes > MAX_BYTES -> "The file is larger than 10 MB."
        durationMs < MIN_DURATION_MS -> "The sound is too short or could not be read."
        durationMs > MAX_DURATION_MS -> "The sound is longer than 2 minutes."
        else -> null
    }

    fun displayName(raw: String?): String {
        val base = raw?.substringBeforeLast('.')?.trim().orEmpty()
        val clean = base.replace(Regex("[\\p{Cntrl}]"), "").take(40)
        return clean.ifBlank { "Custom sound" }
    }
}

/**
 * Synthesises the built-in alert tones as 16-bit mono PCM WAV. Generated
 * locally (no bundled or downloaded audio). Each tone is one ~1.3 s cycle so
 * looping reproduces the familiar pulse rhythm.
 */
internal object ToneSynth {
    const val SAMPLE_RATE = 22_050
    val builtInIds = setOf("classic_beep", "soft_chime", "double_beep", "alert_tone")

    private data class Segment(val hzStart: Double, val hzEnd: Double, val ms: Int, val gain: Double)

    private fun segments(soundId: String): List<Segment> = when (soundId) {
        "soft_chime" -> listOf(
            Segment(1_046.5, 1_046.5, 260, .55),
            Segment(1_318.5, 1_318.5, 420, .55),
            Segment(0.0, 0.0, 620, 0.0),
        )
        "double_beep" -> listOf(
            Segment(1_400.0, 1_400.0, 140, .8),
            Segment(0.0, 0.0, 90, 0.0),
            Segment(1_400.0, 1_400.0, 140, .8),
            Segment(0.0, 0.0, 930, 0.0),
        )
        "alert_tone" -> listOf(
            Segment(800.0, 1_800.0, 500, .8),
            Segment(1_800.0, 800.0, 300, .8),
            Segment(0.0, 0.0, 500, 0.0),
        )
        else -> listOf( // classic_beep
            Segment(1_760.0, 1_760.0, 650, .75),
            Segment(0.0, 0.0, 650, 0.0),
        )
    }

    fun pcm(soundId: String): ShortArray {
        val out = ArrayList<Short>()
        var phase = 0.0
        for (s in segments(soundId)) {
            val n = SAMPLE_RATE * s.ms / 1_000
            val fade = min(n / 2, SAMPLE_RATE * 8 / 1_000) // 8 ms anti-click ramps
            for (i in 0 until n) {
                if (s.gain == 0.0) {
                    out.add(0)
                    continue
                }
                val hz = s.hzStart + (s.hzEnd - s.hzStart) * i / n
                phase += 2 * PI * hz / SAMPLE_RATE
                val env = when {
                    i < fade -> i.toDouble() / fade
                    i > n - fade -> (n - i).toDouble() / fade
                    else -> 1.0
                }
                out.add((sin(phase) * s.gain * env * Short.MAX_VALUE).toInt().toShort())
            }
        }
        return out.toShortArray()
    }

    fun wavBytes(soundId: String): ByteArray {
        val samples = pcm(soundId)
        val dataBytes = samples.size * 2
        val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN).apply {
            put("RIFF".toByteArray()); putInt(36 + dataBytes); put("WAVE".toByteArray())
            put("fmt ".toByteArray()); putInt(16); putShort(1); putShort(1)
            putInt(SAMPLE_RATE); putInt(SAMPLE_RATE * 2); putShort(2); putShort(16)
            put("data".toByteArray()); putInt(dataBytes)
        }
        val body = ByteBuffer.allocate(dataBytes).order(ByteOrder.LITTLE_ENDIAN)
        samples.forEach { body.putShort(it) }
        return ByteArrayOutputStream(44 + dataBytes).apply {
            write(header.array()); write(body.array())
        }.toByteArray()
    }
}
