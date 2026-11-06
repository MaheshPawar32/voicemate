package com.dev.vokey

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ClapSensitivityTest {
    @Test
    fun highSensitivityDetectsQuieterTransientThanNormalOrLow() {
        val samples = ShortArray(320)
        samples[80] = 15_000

        val high = ClapDetector.forSensitivity("high")
        val normal = ClapDetector.forSensitivity("normal")
        val low = ClapDetector.forSensitivity("low")

        assertTrue(high.process(samples, samples.size, 0L).clapDetected)
        assertFalse(normal.process(samples, samples.size, 0L).clapDetected)
        assertFalse(low.process(samples, samples.size, 0L).clapDetected)
    }
}
