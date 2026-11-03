package com.dev.voicemate

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.PI
import kotlin.math.sin

class ClapDetectorTest {
    private fun clapFrame(): ShortArray = ShortArray(320).also { frame ->
        for (index in 0 until 16) frame[index] = 15_000
    }

    @Test
    fun silenceDoesNotTrigger() {
        val detector = ClapDetector()
        val silence = ShortArray(320)
        repeat(50) { frame ->
            val result = detector.process(silence, silence.size, frame * 20L)
            assertFalse(result.clapDetected)
        }
        assertEquals(0, detector.process(silence, silence.size, 1_100L).clapCount)
    }

    @Test
    fun shortTransientTriggersOneClap() {
        val detector = ClapDetector()
        val silence = ShortArray(320)
        repeat(50) { frame ->
            detector.process(silence, silence.size, frame * 20L)
        }
        val result = detector.process(clapFrame(), 320, 1_100L)
        assertTrue(result.clapDetected)
        assertEquals(1, result.clapCount)
    }

    @Test
    fun refractoryWindowSuppressesRepeatedTransient() {
        val detector = ClapDetector()
        val clap = clapFrame()
        val first = detector.process(clap, clap.size, 1_000L)
        val tooSoon = detector.process(clap, clap.size, 1_200L)
        val afterWindow = detector.process(clap, clap.size, 1_500L)

        assertTrue(first.clapDetected)
        assertFalse(tooSoon.clapDetected)
        assertEquals(1, tooSoon.clapCount)
        assertTrue(afterWindow.clapDetected)
        assertEquals(2, afterWindow.clapCount)
    }

    @Test
    fun steadyToneDoesNotTriggerAsClap() {
        val detector = ClapDetector()
        val tone = ShortArray(320) { index ->
            (8_000.0 * sin(2.0 * PI * 440.0 * index / 16_000.0)).toInt().toShort()
        }
        val result = detector.process(tone, tone.size, 1_000L)
        assertFalse(result.clapDetected)
        assertEquals(0, result.clapCount)
    }

    @Test
    fun invalidFrameLengthIsIgnored() {
        val detector = ClapDetector()
        val result = detector.process(ShortArray(10), 11, 1_000L)
        assertFalse(result.clapDetected)
        assertEquals(0, result.clapCount)
    }
}
