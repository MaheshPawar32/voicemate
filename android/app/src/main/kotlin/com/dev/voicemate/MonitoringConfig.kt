package com.dev.voicemate

import android.os.Bundle
import java.util.Calendar

internal data class MonitoringConfig(
    val clapEnabled: Boolean = true,
    val whistleEnabled: Boolean = true,
    val clapSensitivity: String = "normal",
    val whistleSensitivity: String = "normal",
    val autoStopMinutes: Int = 0,
    val quietHoursEnabled: Boolean = false,
    val quietStart: String = "22:00",
    val quietEnd: String = "07:00",
) {
    companion object {
        fun fromExtras(extras: Bundle?): MonitoringConfig {
            val clapSensitivity = extras?.getString("clap_sensitivity") ?: "normal"
            val whistleSensitivity = extras?.getString("whistle_sensitivity") ?: "normal"
            return MonitoringConfig(
                clapEnabled = extras?.getBoolean("clap_enabled", true) ?: true,
                whistleEnabled = extras?.getBoolean("whistle_enabled", true) ?: true,
                clapSensitivity = clapSensitivity.takeIf {
                    it == "low" || it == "normal" || it == "high"
                } ?: "normal",
                whistleSensitivity = whistleSensitivity.takeIf {
                    it == "low" || it == "normal" || it == "high"
                } ?: "normal",
                autoStopMinutes =
                    (extras?.getInt("auto_stop_minutes", 0) ?: 0).coerceIn(0, 360),
                quietHoursEnabled =
                    extras?.getBoolean("quiet_hours_enabled", false) ?: false,
                quietStart = normalizeTime(extras?.getString("quiet_start") ?: "22:00"),
                quietEnd = normalizeTime(extras?.getString("quiet_end") ?: "07:00"),
            )
        }

        private fun normalizeTime(value: String): String {
            val match = Regex("^(\\d{2}):(\\d{2})$").matchEntire(value)
                ?: return "22:00"
            val hour = match.groupValues[1].toIntOrNull() ?: return "22:00"
            val minute = match.groupValues[2].toIntOrNull() ?: return "22:00"
            if (hour !in 0..23 || minute !in 0..59) return "22:00"
            return "%02d:%02d".format(hour, minute)
        }
    }

    fun isQuietHoursNow(calendar: Calendar = Calendar.getInstance()): Boolean {
        if (!quietHoursEnabled) return false
        val start = minuteOfDay(quietStart) ?: return false
        val end = minuteOfDay(quietEnd) ?: return false
        if (start == end) return false
        val now = calendar.get(Calendar.HOUR_OF_DAY) * 60 +
            calendar.get(Calendar.MINUTE)
        return if (start < end) {
            now >= start && now < end
        } else {
            now >= start || now < end
        }
    }

    private fun minuteOfDay(value: String): Int? {
        val parts = value.split(":")
        if (parts.size != 2) return null
        val hour = parts[0].toIntOrNull() ?: return null
        val minute = parts[1].toIntOrNull() ?: return null
        if (hour !in 0..23 || minute !in 0..59) return null
        return hour * 60 + minute
    }
}
