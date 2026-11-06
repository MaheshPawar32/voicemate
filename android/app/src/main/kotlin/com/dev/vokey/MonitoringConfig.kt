package com.dev.vokey

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
    /** 0–100. Derived from the legacy preset when the caller sends none. */
    val clapSensitivityPercent: Int = Sensitivity.fromPreset(clapSensitivity),
    val whistleSensitivityPercent: Int = Sensitivity.fromPreset(whistleSensitivity),
    /** 1 = single, 2 = double, 3 = triple clap. */
    val clapPattern: Int = 1,
    val cooldownSeconds: Int = 5,
    val whistleMinHz: Int = 1_500,
    val whistleMaxHz: Int = 3_800,
    val whistleMinDurationMs: Int = 120,
    val pocketModeEnabled: Boolean = false,
    /** 0 disables. */
    val batteryWarningPercent: Int = 0,
    /** 0 disables. */
    val batteryStopPercent: Int = 0,
) {
    companion object {
        fun fromExtras(extras: Bundle?): MonitoringConfig {
            val clapSensitivity = extras?.getString("clap_sensitivity") ?: "normal"
            val whistleSensitivity = extras?.getString("whistle_sensitivity") ?: "normal"
            val rawMin = (extras?.getInt("whistle_min_hz", 1_500) ?: 1_500).coerceIn(800, 6_000)
            val rawMax = (extras?.getInt("whistle_max_hz", 3_800) ?: 3_800).coerceIn(1_000, 7_000)
            val minHz = minOf(rawMin, rawMax - 200)
            val maxHz = maxOf(rawMax, minHz + 200)
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
                clapSensitivityPercent = percentOr(
                    extras, "clap_sensitivity_pct", Sensitivity.fromPreset(clapSensitivity),
                ),
                whistleSensitivityPercent = percentOr(
                    extras, "whistle_sensitivity_pct", Sensitivity.fromPreset(whistleSensitivity),
                ),
                clapPattern = (extras?.getInt("clap_pattern", 1) ?: 1).coerceIn(1, 3),
                cooldownSeconds = (extras?.getInt("cooldown_seconds", 5) ?: 5).coerceIn(0, 120),
                whistleMinHz = minHz,
                whistleMaxHz = maxHz,
                whistleMinDurationMs =
                    (extras?.getInt("whistle_min_duration_ms", 120) ?: 120).coerceIn(60, 2_000),
                pocketModeEnabled = extras?.getBoolean("pocket_mode_enabled", false) ?: false,
                batteryWarningPercent =
                    (extras?.getInt("battery_warning_percent", 0) ?: 0).coerceIn(0, 50),
                batteryStopPercent =
                    (extras?.getInt("battery_stop_percent", 0) ?: 0).coerceIn(0, 50),
            )
        }

        private fun percentOr(extras: Bundle?, key: String, fallback: Int): Int {
            val value = extras?.getInt(key, -1) ?: -1
            return if (value in 0..100) value else fallback
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
