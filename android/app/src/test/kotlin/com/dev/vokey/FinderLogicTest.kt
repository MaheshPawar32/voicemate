package com.dev.vokey

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.PI
import kotlin.math.sin

class FinderLogicTest {
    // --- Clap patterns -----------------------------------------------------

    @Test
    fun singlePatternTriggersOnEveryClap() {
        val m = ClapPatternMatcher(1)
        assertTrue(m.onClap(0))
        assertTrue(m.onClap(2_000))
    }

    @Test
    fun doublePatternNeedsTwoClapsWithinWindow() {
        val m = ClapPatternMatcher(2, maxGapMs = 1_000)
        assertFalse(m.onClap(0))
        assertEquals(1, m.progress)
        assertTrue(m.onClap(400))
        assertEquals(0, m.progress)
    }

    @Test
    fun slowClapsDoNotAccumulateIntoAPattern() {
        val m = ClapPatternMatcher(2, maxGapMs = 1_000)
        assertFalse(m.onClap(0))
        assertFalse(m.onClap(1_500)) // gap too long: restarts at 1
        assertTrue(m.onClap(1_900))
    }

    @Test
    fun triplePatternAndStaleExpiry() {
        val m = ClapPatternMatcher(3, maxGapMs = 1_000)
        assertFalse(m.onClap(0))
        assertFalse(m.onClap(300))
        m.expireIfStale(2_000)
        assertEquals(0, m.progress)
        assertFalse(m.onClap(2_100))
        assertFalse(m.onClap(2_400))
        assertTrue(m.onClap(2_700))
    }

    @Test
    fun patternIsClampedToSupportedRange() {
        assertEquals(3, ClapPatternMatcher(9).requiredClaps)
        assertEquals(1, ClapPatternMatcher(0).requiredClaps)
    }

    // --- Cooldown and snooze ----------------------------------------------

    @Test
    fun cooldownBlocksRepeatedTriggers() {
        val gate = TriggerGate(cooldownSeconds = 5)
        assertTrue(gate.tryTrigger(0))
        assertFalse(gate.tryTrigger(4_999))
        assertTrue(gate.tryTrigger(5_000))
    }

    @Test
    fun zeroCooldownAllowsBackToBack() {
        val gate = TriggerGate(0)
        assertTrue(gate.tryTrigger(0))
        assertTrue(gate.tryTrigger(1))
    }

    @Test
    fun snoozeSuppressesUntilExpiry() {
        val gate = TriggerGate(0)
        gate.snooze(nowMs = 1_000, durationMs = 30_000)
        assertTrue(gate.isSnoozed(20_000))
        assertFalse(gate.tryTrigger(30_999))
        assertTrue(gate.tryTrigger(31_000))
    }

    // --- Battery -----------------------------------------------------------

    @Test
    fun batteryAutoStopOnlyWhenDischargingAtOrBelowThreshold() {
        assertTrue(BatteryGuard.shouldAutoStop(10, charging = false, stopThreshold = 10))
        assertFalse(BatteryGuard.shouldAutoStop(11, charging = false, stopThreshold = 10))
        assertFalse(BatteryGuard.shouldAutoStop(5, charging = true, stopThreshold = 10))
        assertFalse(BatteryGuard.shouldAutoStop(1, charging = false, stopThreshold = 0))
        assertFalse(BatteryGuard.shouldAutoStop(-1, charging = false, stopThreshold = 10))
    }

    @Test
    fun batteryWarningFiresOnce() {
        assertTrue(BatteryGuard.shouldWarn(20, false, 20, alreadyWarned = false))
        assertFalse(BatteryGuard.shouldWarn(19, false, 20, alreadyWarned = true))
        assertFalse(BatteryGuard.shouldWarn(15, true, 20, alreadyWarned = false))
        assertFalse(BatteryGuard.shouldWarn(15, false, 0, alreadyWarned = false))
    }

    // --- Proximity ---------------------------------------------------------

    @Test
    fun proximityHandlesBinaryAndDistanceSensors() {
        assertTrue(ProximityLogic.isCovered(0f, 5f))
        assertFalse(ProximityLogic.isCovered(5f, 5f))
        assertTrue(ProximityLogic.isCovered(1f, 10f))
        assertFalse(ProximityLogic.isCovered(8f, 10f))
        assertFalse(ProximityLogic.isCovered(Float.NaN, 5f))
    }

    // --- Sensitivity -------------------------------------------------------

    @Test
    fun sensitivityInterpolatesThroughPresets() {
        assertEquals(10.0, Sensitivity.interpolate(0, 10.0, 6.0, 2.0), 1e-9)
        assertEquals(6.0, Sensitivity.interpolate(50, 10.0, 6.0, 2.0), 1e-9)
        assertEquals(2.0, Sensitivity.interpolate(100, 10.0, 6.0, 2.0), 1e-9)
        assertEquals(8.0, Sensitivity.interpolate(25, 10.0, 6.0, 2.0), 1e-9)
        assertEquals(2.0, Sensitivity.interpolate(500, 10.0, 6.0, 2.0), 1e-9)
        assertEquals(50, Sensitivity.fromPreset("unknown"))
    }

    @Test
    fun higherClapSensitivityDetectsQuieterTransient() {
        // A moderate transient: peaky but quieter than a loud clap.
        val frame = ShortArray(320) { i -> if (i in 100..110) 4_000 else (if (i % 2 == 0) 300 else -300) }
        val low = ClapDetector.forPercent(0)
        val high = ClapDetector.forPercent(100)
        // Prime both with quiet frames so the noise floor settles.
        repeat(20) { n ->
            low.process(ShortArray(320), 320, n * 20L)
            high.process(ShortArray(320), 320, n * 20L)
        }
        assertFalse(low.process(frame, 320, 1_000).clapDetected)
        assertTrue(high.process(frame, 320, 1_000).clapDetected)
    }

    // --- Whistle band and duration ----------------------------------------

    private fun tone(frame: Int, hz: Int) = ShortArray(320) { i ->
        (6_000 * sin(2.0 * PI * hz * (frame * 320 + i) / 16_000.0)).toInt().toShort()
    }

    private fun framesUntilDetected(detector: WhistleDetector, hz: Int, maxFrames: Int = 60): Int? {
        for (f in 0 until maxFrames) {
            if (detector.process(tone(f, hz), 320, f * 20L).detected) return f + 1
        }
        return null
    }

    @Test
    fun whistleOutsideConfiguredBandIsIgnored() {
        val narrow = WhistleDetector.forSettings(50, minFrequencyHz = 2_500, maxFrequencyHz = 3_500)
        assertEquals(null, framesUntilDetected(narrow, 1_800))
        val wide = WhistleDetector.forSettings(50, minFrequencyHz = 1_500, maxFrequencyHz = 3_800)
        assertTrue(framesUntilDetected(wide, 1_800) != null)
    }

    @Test
    fun minimumDurationControlsRequiredFrames() {
        val short = WhistleDetector.forSettings(50, minDurationMs = 100) // 5 frames
        val long = WhistleDetector.forSettings(50, minDurationMs = 400) // 20 frames
        assertEquals(5, framesUntilDetected(short, 2_200))
        assertEquals(20, framesUntilDetected(long, 2_200))
    }

    // --- Startup warm-up ----------------------------------------------------

    @Test
    fun detectionsAreIgnoredDuringWarmUp() {
        val guard = StartupGuard(startedAtMs = 10_000)
        assertFalse(guard.isArmed(10_000))
        assertFalse(guard.isArmed(10_225)) // the observed false trigger time
        assertFalse(guard.isArmed(11_499))
        assertTrue(guard.isArmed(11_500))
    }

    @Test
    fun ownAlertNeverTriggersADetection() {
        assertTrue(SelfTriggerGuard.suppressed(alertPlaying = true, nowMs = 5_000, alertEndedAtMs = 0))
        // Short tail after the alert stops (room echo, speaker ring-down).
        assertTrue(SelfTriggerGuard.suppressed(false, nowMs = 10_500, alertEndedAtMs = 10_000))
        assertFalse(SelfTriggerGuard.suppressed(false, nowMs = 11_000, alertEndedAtMs = 10_000))
        assertFalse(SelfTriggerGuard.suppressed(false, nowMs = 5_000, alertEndedAtMs = 0))
    }
}
