package com.dev.vokey

/**
 * Pure, Android-free decision logic for the finder. Kept separate so it can be
 * unit-tested on the JVM (see FinderLogicTest).
 */

/** Linear interpolation helpers mapping a 0–100 sensitivity onto detector thresholds. */
internal object Sensitivity {
    /** Legacy string presets map onto the percentage scale. */
    fun fromPreset(preset: String): Int = when (preset) {
        "low" -> 20
        "high" -> 80
        else -> 50
    }

    /**
     * Piecewise-linear: 0 → [low], 50 → [normal], 100 → [high].
     * Higher sensitivity means *lower* thresholds, so callers pass values accordingly.
     */
    fun interpolate(percent: Int, low: Double, normal: Double, high: Double): Double {
        val p = percent.coerceIn(0, 100)
        return if (p <= 50) {
            low + (normal - low) * (p / 50.0)
        } else {
            normal + (high - normal) * ((p - 50) / 50.0)
        }
    }
}

/**
 * Groups individual clap transients into the configured single/double/triple
 * pattern. A gap longer than [maxGapMs] restarts the count, so isolated noises
 * do not accumulate into a pattern over time.
 */
internal class ClapPatternMatcher(
    requiredClaps: Int,
    private val maxGapMs: Long = 1_000L,
) {
    val requiredClaps: Int = requiredClaps.coerceIn(1, 3)
    private var count = 0
    private var lastClapMs = Long.MIN_VALUE

    val progress: Int get() = count

    /** Returns true exactly when the pattern completes. */
    fun onClap(nowMs: Long): Boolean {
        if (lastClapMs != Long.MIN_VALUE && nowMs - lastClapMs > maxGapMs) count = 0
        count += 1
        lastClapMs = nowMs
        if (count >= requiredClaps) {
            reset()
            return true
        }
        return false
    }

    /** Clears a partial pattern once the gap window has expired. */
    fun expireIfStale(nowMs: Long) {
        if (lastClapMs != Long.MIN_VALUE && nowMs - lastClapMs > maxGapMs) reset()
    }

    fun reset() {
        count = 0
        lastClapMs = Long.MIN_VALUE
    }
}

/**
 * Ignores detections for a short period after the microphone starts. The
 * detectors keep processing (and learning the room's noise floor) but cannot
 * trigger: a fresh AudioRecord's first frames and the tap on Start otherwise
 * look like a clap (observed: false "Phone found" 225 ms after start).
 */
internal class StartupGuard(private val startedAtMs: Long, private val warmupMs: Long = WARMUP_MS) {
    companion object {
        const val WARMUP_MS = 1_500L
    }

    fun isArmed(nowMs: Long): Boolean = nowMs - startedAtMs >= warmupMs
}

/**
 * Blocks detections while Vokey's own alert is sounding (plus a short tail).
 * A phone's speaker is centimetres from its microphone; the built-in beep
 * (1.76 kHz) is inside the whistle band, so without this the alert could
 * re-trigger itself whenever the alert outlasts the cooldown.
 */
internal object SelfTriggerGuard {
    const val TAIL_MS = 1_000L

    fun suppressed(alertPlaying: Boolean, nowMs: Long, alertEndedAtMs: Long): Boolean =
        alertPlaying || (alertEndedAtMs > 0 && nowMs - alertEndedAtMs < TAIL_MS)
}

/** Global cooldown between alerts, regardless of which detector fired. */
internal class TriggerGate(cooldownSeconds: Int) {
    private val cooldownMs = cooldownSeconds.coerceIn(0, 120) * 1_000L
    private var lastTriggerMs = Long.MIN_VALUE
    private var snoozedUntilMs = Long.MIN_VALUE

    fun snooze(nowMs: Long, durationMs: Long) {
        snoozedUntilMs = nowMs + durationMs
    }

    fun snoozedUntil(): Long = snoozedUntilMs

    fun isSnoozed(nowMs: Long): Boolean = nowMs < snoozedUntilMs

    /** Returns true and records the trigger when an alert is allowed now. */
    fun tryTrigger(nowMs: Long): Boolean {
        if (isSnoozed(nowMs)) return false
        if (lastTriggerMs != Long.MIN_VALUE && nowMs - lastTriggerMs < cooldownMs) return false
        lastTriggerMs = nowMs
        return true
    }
}

/** Battery-aware monitoring decisions. Thresholds of 0 disable the feature. */
internal object BatteryGuard {
    fun shouldAutoStop(levelPercent: Int, charging: Boolean, stopThreshold: Int): Boolean =
        stopThreshold > 0 && !charging && levelPercent in 0..stopThreshold

    fun shouldWarn(
        levelPercent: Int,
        charging: Boolean,
        warnThreshold: Int,
        alreadyWarned: Boolean,
    ): Boolean = warnThreshold > 0 && !charging && !alreadyWarned &&
        levelPercent in 0..warnThreshold
}

/** Proximity sensors report either a distance in cm or a binary near/far value. */
internal object ProximityLogic {
    fun isCovered(value: Float, maximumRange: Float): Boolean {
        if (value.isNaN()) return false
        // Binary sensors report 0 (near) or maximumRange (far); distance sensors
        // report centimetres. Treat anything clearly below the max as covered.
        return value < maximumRange && value < 5f
    }
}
