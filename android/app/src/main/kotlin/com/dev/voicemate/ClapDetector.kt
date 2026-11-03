package com.dev.voicemate

import kotlin.math.sqrt

/**
 * Provisional transient detector. Pure Kotlin: no microphone or Android resources.
 * Tune with real-device measurements before using this in a release feature.
 */
internal class ClapDetector(
    private val absoluteRmsFloor: Double = 1_500.0,
    private val absolutePeakFloor: Double = 5_000.0,
    private val rmsMultiplier: Double = 3.5,
    private val peakMultiplier: Double = 8.0,
    private val minCrestFactor: Double = 2.2,
    private val refractoryMs: Long = 450L,
) {
    private var noiseFloorRms = 300.0
    private var lastClapAtMs = Long.MIN_VALUE
    private var clapCount = 0

    data class FrameResult(
        val rms: Double,
        val peak: Int,
        val noiseFloorRms: Double,
        val clapDetected: Boolean,
        val clapCount: Int,
    )

    fun process(samples: ShortArray, length: Int, nowMs: Long): FrameResult {
        if (length <= 0 || length > samples.size) {
            return FrameResult(0.0, 0, noiseFloorRms, false, clapCount)
        }

        var sumSquares = 0.0
        var peak = 0
        for (index in 0 until length) {
            val value = samples[index].toInt()
            val magnitude = kotlin.math.abs(value)
            if (magnitude > peak) peak = magnitude
            sumSquares += value.toDouble() * value.toDouble()
        }

        val rms = sqrt(sumSquares / length)
        val rmsThreshold = maxOf(absoluteRmsFloor, noiseFloorRms * rmsMultiplier)
        val peakThreshold = maxOf(absolutePeakFloor, noiseFloorRms * peakMultiplier)
        val crestFactor = peak.toDouble() / maxOf(1.0, rms)
        val candidate = rms >= rmsThreshold &&
            peak >= peakThreshold &&
            crestFactor >= minCrestFactor
        val outsideRefractory = lastClapAtMs == Long.MIN_VALUE ||
            nowMs - lastClapAtMs >= refractoryMs
        val detected = candidate && outsideRefractory

        if (detected) {
            lastClapAtMs = nowMs
            clapCount += 1
        } else if (!candidate) {
            noiseFloorRms = (noiseFloorRms * 0.98 + rms * 0.02).coerceIn(80.0, 8_000.0)
        }

        return FrameResult(rms, peak, noiseFloorRms, detected, clapCount)
    }
}
