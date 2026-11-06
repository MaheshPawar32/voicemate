package com.dev.vokey

import kotlin.math.sqrt

/**
 * Provisional transient detector. Pure Kotlin: no microphone or Android resources.
 * Tune with real-device measurements before using this in a release feature.
 */
internal class ClapDetector(
    private val absoluteRmsFloor: Double = 1_000.0,
    private val absolutePeakFloor: Double = 5_000.0,
    private val rmsMultiplier: Double = 3.5,
    private val peakMultiplier: Double = 8.0,
    private val minCrestFactor: Double = 2.2,
    private val refractoryMs: Long = 450L,
) {
    companion object {
        fun forSensitivity(level: String): ClapDetector = when (level) {
            "low" -> ClapDetector(
                absoluteRmsFloor = 1_500.0,
                absolutePeakFloor = 7_000.0,
                rmsMultiplier = 4.2,
                peakMultiplier = 10.0,
                minCrestFactor = 2.5,
            )
            "high" -> ClapDetector(
                absoluteRmsFloor = 700.0,
                absolutePeakFloor = 3_500.0,
                rmsMultiplier = 2.5,
                peakMultiplier = 6.5,
                minCrestFactor = 1.9,
            )
            else -> ClapDetector()
        }

        /**
         * Continuous 0–100 sensitivity: 0 = the "low" preset, 50 = "normal",
         * 100 = "high". [refractoryMs] is shortened for multi-clap patterns so a
         * quick double clap is not swallowed by the refractory window.
         */
        fun forPercent(percent: Int, refractoryMs: Long = 450L): ClapDetector {
            fun lerp(low: Double, normal: Double, high: Double) =
                Sensitivity.interpolate(percent, low, normal, high)
            return ClapDetector(
                absoluteRmsFloor = lerp(1_500.0, 1_000.0, 500.0),
                absolutePeakFloor = lerp(7_000.0, 5_000.0, 2_800.0),
                rmsMultiplier = lerp(4.2, 3.5, 2.2),
                peakMultiplier = lerp(10.0, 8.0, 6.0),
                minCrestFactor = lerp(2.5, 2.2, 1.8),
                refractoryMs = refractoryMs,
            )
        }
    }
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
