package com.dev.vokey

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.PI
import kotlin.math.sin

class WhistleDetectorTest {
    private fun toneFrame(
        frameNumber: Int,
        frequency: Int = 2_200,
        amplitude: Int = 5_000,
    ): ShortArray = ShortArray(320) { index ->
        val sampleIndex = frameNumber * 320 + index
        (amplitude * sin(2.0 * PI * frequency * sampleIndex / 16_000.0))
            .toInt().toShort()
    }

    @Test
    fun silenceIsNotWhistle() {
        val detector = WhistleDetector()
        repeat(10) { frame ->
            val result = detector.process(ShortArray(320), 320, frame * 20L)
            assertFalse(result.detected)
            assertEquals(null, result.frequencyHz)
        }
    }

    @Test
    fun sustainedWhistleBandToneIsDetectedAfterMinimumDuration() {
        val detector = WhistleDetector()
        var detections = 0
        repeat(8) { frame ->
            val result = detector.process(toneFrame(frame), 320, frame * 20L)
            if (result.detected) detections += 1
        }
        assertEquals(1, detections)
    }

    @Test
    fun briefToneDoesNotPassDurationGate() {
        val detector = WhistleDetector()
        repeat(3) { frame ->
            assertFalse(
                detector.process(toneFrame(frame), 320, frame * 20L).detected,
            )
        }
        val silence = detector.process(ShortArray(320), 320, 100L)
        assertFalse(silence.detected)
        assertEquals(0, silence.stableFrames)
    }

    @Test
    fun lowFrequencyToneIsOutsideWhistleBand() {
        val detector = WhistleDetector()
        repeat(10) { frame ->
            val result = detector.process(
                toneFrame(frame, frequency = 500),
                320,
                frame * 20L,
            )
            assertFalse(result.detected)
        }
    }

    @Test
    fun invalidFrameIsIgnored() {
        val detector = WhistleDetector()
        val result = detector.process(ShortArray(320), 321, 0L)
        assertFalse(result.detected)
        assertEquals(0.0, result.rms, 0.0)
        assertEquals(null, result.frequencyHz)
    }
}
