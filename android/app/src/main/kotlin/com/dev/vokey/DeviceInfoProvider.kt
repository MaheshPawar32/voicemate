package com.dev.vokey

import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.app.ActivityManager
import android.os.Debug
import android.content.Context

internal object DeviceInfoProvider {
    fun batterySnapshot(context: Context): Map<String, Any?> {
        val intent = context.registerReceiver(
            null,
            IntentFilter(Intent.ACTION_BATTERY_CHANGED),
        ) ?: throw IllegalStateException("Android battery information is unavailable.")

        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        val percentage = if (level >= 0 && scale > 0) {
            ((level * 100f) / scale).toInt().coerceIn(0, 100)
        } else {
            -1
        }

        val statusCode = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
        val status = when (statusCode) {
            BatteryManager.BATTERY_STATUS_CHARGING -> "charging"
            BatteryManager.BATTERY_STATUS_FULL -> "full"
            BatteryManager.BATTERY_STATUS_DISCHARGING -> "discharging"
            BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "not_charging"
            else -> "unknown"
        }

        val plugged = intent.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0)
        val pluggedSource = when {
            (plugged and BatteryManager.BATTERY_PLUGGED_AC) != 0 -> "ac"
            (plugged and BatteryManager.BATTERY_PLUGGED_USB) != 0 -> "usb"
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1 &&
                (plugged and BatteryManager.BATTERY_PLUGGED_WIRELESS) != 0 -> "wireless"
            else -> "none"
        }

        val healthCode = intent.getIntExtra(BatteryManager.EXTRA_HEALTH, -1)
        val health = when (healthCode) {
            BatteryManager.BATTERY_HEALTH_GOOD -> "good"
            BatteryManager.BATTERY_HEALTH_OVERHEAT -> "overheat"
            BatteryManager.BATTERY_HEALTH_DEAD -> "dead"
            BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "over_voltage"
            BatteryManager.BATTERY_HEALTH_UNSPECIFIED_FAILURE -> "failure"
            BatteryManager.BATTERY_HEALTH_COLD -> "cold"
            else -> "unknown"
        }

        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val activityManager =
            context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)
        val appMemoryInfo = Debug.MemoryInfo()
        Debug.getMemoryInfo(appMemoryInfo)

        val ignoresBatteryOptimizations = if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
        ) {
            powerManager.isIgnoringBatteryOptimizations(context.packageName)
        } else {
            false
        }

        return mapOf(
            "level_percent" to percentage,
            "status" to status,
            "plugged_source" to pluggedSource,
            "health" to health,
            "temperature_c" to intent.getIntExtra(
                BatteryManager.EXTRA_TEMPERATURE, -1,
            ).let { if (it >= 0) it / 10.0 else -1.0 },
            "voltage_mv" to intent.getIntExtra(BatteryManager.EXTRA_VOLTAGE, -1),
            "power_save_mode" to powerManager.isPowerSaveMode,
            "battery_optimization_ignored" to ignoresBatteryOptimizations,
            "total_ram_mb" to (memoryInfo.totalMem / (1024L * 1024L)).toInt(),
            "available_ram_mb" to (memoryInfo.availMem / (1024L * 1024L)).toInt(),
            "app_memory_pss_mb" to (appMemoryInfo.totalPss / 1024),
            "low_memory" to memoryInfo.lowMemory,
        )
    }
}
