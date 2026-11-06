package com.dev.vokey

import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import java.io.File

/**
 * Processes PCM frames from AudioCaptureManager's existing mic stream.
 * No transcript or raw audio is written to disk or emitted to Flutter.
 */
internal class OfflineCommandEngine(modelDirectory: File) : AutoCloseable {
    companion object {
        private const val SAMPLE_RATE = 16_000f
        private const val GRAMMAR = """[
            "find my phone",
            "where are you",
            "hello voice mate",
            "lock my phone",
            "lock this phone",
            "stop listening",
            "stop monitoring",
            "[unk]"
        ]"""

        internal fun intentForTranscript(transcript: String): String? {
            val text = transcript.lowercase()
                .replace(Regex("[^a-z0-9 ]"), " ")
                .trim()
                .replace(Regex("\\s+"), " ")
            return when (text) {
                "find my phone", "where are you", "hello voice mate" -> "find_phone"
                "lock my phone", "lock this phone" -> "lock_phone"
                "stop listening", "stop monitoring" -> "stop_monitoring"
                else -> null
            }
        }
    }

    private val model = Model(modelDirectory.absolutePath)
    private val recognizer = Recognizer(model, SAMPLE_RATE, GRAMMAR)

    /**
     * Returns a supported intent id only. Unmatched speech is discarded.
     */
    @Synchronized
    fun process(samples: ShortArray, length: Int): String? {
        if (length <= 0 || length > samples.size) return null
        val complete = recognizer.acceptWaveForm(samples, length)
        if (!complete) return null

        val json = JSONObject(recognizer.result)
        return intentForTranscript(json.optString("text", ""))
    }

    override fun close() {
        try {
            recognizer.close()
        } finally {
            model.close()
        }
    }
}
