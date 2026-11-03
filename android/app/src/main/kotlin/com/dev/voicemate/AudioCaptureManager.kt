package com.dev.voicemate

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.SystemClock

/** One AudioRecord owner for the visible, foreground-only clap test. */
internal class AudioCaptureManager {
    companion object {
        private const val SAMPLE_RATE = 16_000
        private const val FRAME_SAMPLES = 320 // 20 ms at 16 kHz.
    }

    data class Metrics(
        val rms: Double,
        val peak: Int,
        val noiseFloorRms: Double,
        val isClap: Boolean,
        val clapCount: Int,
    )

    @Volatile private var isReading = false
    private var recorder: AudioRecord? = null
    private var worker: Thread? = null

    @Synchronized
    fun start(onMetrics: (Metrics) -> Unit, onError: (String) -> Unit) {
        if (isReading) return

        val minBufferBytes = AudioRecord.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
        )
        require(minBufferBytes > 0) { "This device does not support the required microphone format." }

        val audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            maxOf(minBufferBytes * 2, FRAME_SAMPLES * 2 * 4),
        )
        if (audioRecord.state != AudioRecord.STATE_INITIALIZED) {
            audioRecord.release()
            throw IllegalStateException("The microphone could not be initialized.")
        }

        try {
            audioRecord.startRecording()
            check(audioRecord.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                "Android did not start microphone capture."
            }
        } catch (error: Exception) {
            audioRecord.release()
            throw IllegalStateException(error.message ?: "Could not start microphone capture.")
        }

        recorder = audioRecord
        isReading = true
        val detector = ClapDetector()
        val samples = ShortArray(FRAME_SAMPLES)

        worker = Thread({
            var frameIndex = 0
            while (isReading) {
                val readCount = audioRecord.read(samples, 0, samples.size)
                if (readCount > 0) {
                    val result = detector.process(samples, readCount, SystemClock.elapsedRealtime())
                    frameIndex += 1
                    if (frameIndex % 5 == 0 || result.clapDetected) {
                        onMetrics(Metrics(
                            rms = result.rms,
                            peak = result.peak,
                            noiseFloorRms = result.noiseFloorRms,
                            isClap = result.clapDetected,
                            clapCount = result.clapCount,
                        ))
                    }
                } else if (readCount == AudioRecord.ERROR_DEAD_OBJECT ||
                    readCount == AudioRecord.ERROR_INVALID_OPERATION ||
                    readCount == AudioRecord.ERROR_BAD_VALUE
                ) {
                    isReading = false
                    onError("Microphone capture stopped unexpectedly (code $readCount).")
                }
            }
        }, "VoiceMateClapCapture").apply {
            priority = Thread.NORM_PRIORITY
            start()
        }
    }

    @Synchronized
    fun stop() {
        isReading = false
        val activeRecorder = recorder
        try {
            if (activeRecorder?.recordingState == AudioRecord.RECORDSTATE_RECORDING) activeRecorder.stop()
        } catch (_: IllegalStateException) {
            // It may already have stopped because of a platform error.
        }

        if (Thread.currentThread() !== worker) {
            try {
                worker?.join(700)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
            }
        }

        try {
            activeRecorder?.release()
        } catch (_: IllegalStateException) {
            // Best-effort cleanup after an input failure.
        }
        recorder = null
        worker = null
    }

    fun isRunning(): Boolean = isReading
}
