package com.dev.vokey

import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorManager
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build

/** Read-only hardware/route facts for Permission Health and Monitoring Centre. */
internal object DeviceCapabilities {
    fun snapshot(context: Context): Map<String, Any?> {
        val pm = context.packageManager
        val sensors = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        return mapOf(
            "schema_version" to 1,
            "api_level" to Build.VERSION.SDK_INT,
            "has_microphone" to pm.hasSystemFeature(PackageManager.FEATURE_MICROPHONE),
            "has_flash" to pm.hasSystemFeature(PackageManager.FEATURE_CAMERA_FLASH),
            "has_proximity" to (sensors?.getDefaultSensor(Sensor.TYPE_PROXIMITY) != null),
            "audio_route" to audioRoute(context),
            "foreground_service_declared" to true,
        )
    }

    /**
     * Best-effort current media output route. Manufacturers report devices
     * differently, so the UI labels this "reported by Android".
     */
    fun audioRoute(context: Context): String {
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            ?: return "unknown"
        val types = audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS).map { it.type }.toSet()
        return when {
            types.any { it == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP || it == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                (Build.VERSION.SDK_INT >= 31 && (it == AudioDeviceInfo.TYPE_BLE_HEADSET || it == AudioDeviceInfo.TYPE_BLE_SPEAKER)) } -> "bluetooth"
            types.any { it == AudioDeviceInfo.TYPE_WIRED_HEADPHONES || it == AudioDeviceInfo.TYPE_WIRED_HEADSET } -> "wired"
            types.any { it == AudioDeviceInfo.TYPE_USB_HEADSET || it == AudioDeviceInfo.TYPE_USB_DEVICE } -> "usb"
            else -> "speaker"
        }
    }
}
