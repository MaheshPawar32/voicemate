package com.dev.voicemate

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sqrt

/**
 * Detects sustained, prominent tonal energy in a whistle-like frequency band.
 * It is a signal classifier, not a guarantee that a tone was made by a human.
 */
internal class WhistleDetector(
    private val sampleRate: Int = 16_000,
    private val minRms: Double = 550.0,
    private val minProminence: Double = 7.0,
    private val minPeakPower: Double = 1_000_000_000.0,
    private val minStableFrames: Int = 6,
    private val refractoryMs: Long = 2_500L,
) {
    companion object {
        fun forSensitivity(level: String): WhistleDetector = when (level) {
            "low" -> WhistleDetector(
                minRms = 750.0,
                minProminence = 9.0,
                minPeakPower = 2_000_000_000.0,
                minStableFrames = 7,
            )
            "high" -> WhistleDetector(
                minRms = 350.0,
                minProminence = 5.0,
                minPeakPower = 300_000_000.0,
                minStableFrames = 5,
            )
            else -> WhistleDetector()
        }
    }
    data class FrameResult(
        val rms: Double,
        val frequencyHz: Int?,
        val detected: Boolean,
        val stableFrames: Int,
    )

    private var candidateFrequency = 0
    private var stableFrames = 0
    private var lastDetectedAtMs = Long.MIN_VALUE

    fun process(samples: ShortArray, length: Int, nowMs: Long): FrameResult {
        if (length <= 0 || length > samples.size) {
            resetCandidate()
            return FrameResult(0.0, null, false, stableFrames)
        }

        var sumSquares = 0.0
        for (index in 0 until length) {
            val value = samples[index].toDouble()
            sumSquares += value * value
        }
        val rms = sqrt(sumSquares / length)
        if (rms < minRms) {
            resetCandidate()
            return FrameResult(rms, null, false, stableFrames)
        }

        var peakFrequency: Int? = null
        var peakPower = 0.0
        var totalPower = 0.0
        var bins = 0
        for (frequency in 1_500..3_800 step 100) {
            val power = goertzelPower(samples, length, frequency)
            totalPower += power
            bins += 1
            if (power > peakPower) {
                peakPower = power
                peakFrequency = frequency
            }
        }

        val averagePower = totalPower / max(1, bins)
        val prominence = peakPower / max(1.0, averagePower)
        val candidate = peakFrequency != null &&
            peakPower >= minPeakPower &&
            prominence >= minProminence

        if (!candidate) {
            resetCandidate()
            return FrameResult(rms, peakFrequency, false, stableFrames)
        }

        val frequency = peakFrequency ?: return FrameResult(rms, null, false, 0)
        if (candidateFrequency == 0 ||
            kotlin.math.abs(frequency - candidateFrequency) > 200
        ) {
            candidateFrequency = frequency
            stableFrames = 1
        } else {
            stableFrames += 1
            candidateFrequency = frequency
        }

        val outsideRefractory = lastDetectedAtMs == Long.MIN_VALUE ||
            nowMs - lastDetectedAtMs >= refractoryMs
        val detected = stableFrames >= minStableFrames &&
            outsideRefractory &&
            stableFrames == minStableFrames
        if (detected) lastDetectedAtMs = nowMs

        return FrameResult(rms, frequency, detected, stableFrames)
    }

    private fun goertzelPower(samples: ShortArray, length: Int, frequency: Int): Double {
        val omega = 2.0 * PI * frequency / sampleRate
        val coefficient = 2.0 * cos(omega)
        var previous = 0.0
        var previousPrevious = 0.0
        for (index in 0 until length) {
            val current = samples[index].toDouble() +
                coefficient * previous - previousPrevious
            previousPrevious = previous
            previous = current
        }
        return max(
            0.0,
            previous * previous +
                previousPrevious * previousPrevious -
                coefficient * previous * previousPrevious,
        )
    }

    private fun resetCandidate() {
        candidateFrequency = 0
        stableFrames = 0
    }
}
