package com.dev.voicemate

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.SystemClock

/** One AudioRecord owner for the visible, foreground-only clap test. */
internal class AudioCaptureManager(
    private val clapEnabled: Boolean = true,
    private val whistleEnabled: Boolean = true,
    clapSensitivity: String = "normal",
    whistleSensitivity: String = "normal",
) {
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
        val isWhistle: Boolean,
        val whistleCount: Int,
        val whistleFrequencyHz: Int?,
    )

    @Volatile private var isReading = false
    private var recorder: AudioRecord? = null
    private var worker: Thread? = null

    @Synchronized
    fun start(
        onMetrics: (Metrics) -> Unit,
        onError: (String) -> Unit,
        voiceEngine: OfflineCommandEngine? = null,
        onVoiceCommand: ((String) -> Unit)? = null,
    ) {
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
        val detector = ClapDetector.forSensitivity(clapSensitivity)
        val whistleDetector = WhistleDetector.forSensitivity(whistleSensitivity)
        var whistleCount = 0
        val samples = ShortArray(FRAME_SAMPLES)

        worker = Thread({
            try {
                var frameIndex = 0
                while (isReading) {
                    val readCount = audioRecord.read(samples, 0, samples.size)
                    when {
                        readCount > 0 -> {
                            val result = if (clapEnabled) {
                                detector.process(
                                    samples,
                                    readCount,
                                    SystemClock.elapsedRealtime(),
                                )
                            } else {
                                ClapDetector.FrameResult(
                                    rms = 0.0,
                                    peak = 0,
                                    noiseFloorRms = 0.0,
                                    clapDetected = false,
                                    clapCount = 0,
                                )
                            }
                            val whistle = if (whistleEnabled) {
                                whistleDetector.process(
                                    samples,
                                    readCount,
                                    SystemClock.elapsedRealtime(),
                                )
                            } else {
                                WhistleDetector.FrameResult(
                                    rms = 0.0,
                                    frequencyHz = null,
                                    detected = false,
                                    stableFrames = 0,
                                )
                            }
                            if (whistle.detected) whistleCount += 1
                            val voiceCommand = voiceEngine?.process(samples, readCount)
                            if (voiceCommand != null) onVoiceCommand?.invoke(voiceCommand)
                            frameIndex += 1
                            if (frameIndex % 5 == 0 ||
                                result.clapDetected ||
                                whistle.detected
                            ) {
                                onMetrics(
                                    Metrics(
                                        rms = result.rms,
                                        peak = result.peak,
                                        noiseFloorRms = result.noiseFloorRms,
                                        isClap = result.clapDetected,
                                        clapCount = result.clapCount,
                                        isWhistle = whistle.detected,
                                        whistleCount = whistleCount,
                                        whistleFrequencyHz = whistle.frequencyHz,
                                    ),
                                )
                            }
                        }
                        readCount == 0 -> Thread.yield()
                        readCount < 0 -> {
                            if (isReading) {
                                isReading = false
                                onError("Microphone capture stopped unexpectedly (code $readCount).")
                            }
                        }
                    }
                }
            } catch (error: SecurityException) {
                if (isReading) {
                    isReading = false
                    onError(error.message ?: "Microphone permission is no longer available.")
                }
            } catch (error: Exception) {
                if (isReading) {
                    isReading = false
                    onError(error.message ?: "Unexpected microphone capture error.")
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

        val activeWorker = worker
        if (Thread.currentThread() !== activeWorker) {
            try {
                activeWorker?.join(1_000)
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
