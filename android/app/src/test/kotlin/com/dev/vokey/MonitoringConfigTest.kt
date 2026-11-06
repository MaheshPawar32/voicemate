package com.dev.vokey

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

class MonitoringConfigTest {
    private fun calendar(hour: Int, minute: Int): Calendar =
        Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

    @Test
    fun quietHoursSupportIntervalsAcrossMidnight() {
        val config = MonitoringConfig(
            quietHoursEnabled = true,
            quietStart = "22:00",
            quietEnd = "07:00",
        )
        assertTrue(config.isQuietHoursNow(calendar(23, 30)))
        assertTrue(config.isQuietHoursNow(calendar(2, 15)))
        assertFalse(config.isQuietHoursNow(calendar(7, 0)))
        assertFalse(config.isQuietHoursNow(calendar(12, 0)))
        assertFalse(config.isQuietHoursNow(calendar(21, 59)))
    }

    @Test
    fun quietHoursSupportSameDayIntervals() {
        val config = MonitoringConfig(
            quietHoursEnabled = true,
            quietStart = "13:00",
            quietEnd = "14:30",
        )
        assertTrue(config.isQuietHoursNow(calendar(13, 0)))
        assertTrue(config.isQuietHoursNow(calendar(14, 29)))
        assertFalse(config.isQuietHoursNow(calendar(14, 30)))
        assertFalse(config.isQuietHoursNow(calendar(12, 59)))
    }

    @Test
    fun disabledOrZeroLengthQuietHoursNeverMuteAlerts() {
        val disabled = MonitoringConfig(
            quietHoursEnabled = false,
            quietStart = "22:00",
            quietEnd = "07:00",
        )
        val zeroLength = MonitoringConfig(
            quietHoursEnabled = true,
            quietStart = "22:00",
            quietEnd = "22:00",
        )
        assertFalse(disabled.isQuietHoursNow(calendar(23, 0)))
        assertFalse(zeroLength.isQuietHoursNow(calendar(23, 0)))
    }
}
