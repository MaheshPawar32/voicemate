package com.dev.voicemate

import android.content.Context
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import android.os.Handler
import android.os.Looper

/**
 * Torch-only flashlight control. It never opens a camera session or captures images.
 * Android may revoke torch availability when another app needs the camera.
 */
internal class FlashlightManager(
    context: Context,
    private val onUnavailable: (String) -> Unit = {},
) {
    private val appContext = context.applicationContext
    private val cameraManager =
        appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    private val handler = Handler(Looper.getMainLooper())
    private var activeCameraId: String? = null
    private var stepIndex = 0
    private var isRunning = false

    private val patternSteps = object : Runnable {
        override fun run() {
            if (!isRunning) return
            val steps = currentSteps
            if (stepIndex >= steps.size) {
                turnOff()
                isRunning = false
                return
            }

            val step = steps[stepIndex]
            try {
                setTorch(step.first)
            } catch (error: Exception) {
                turnOff()
                isRunning = false
                onUnavailable(
                    error.message ?: "Android made the flashlight unavailable.",
                )
                return
            }
            stepIndex += 1
            handler.postDelayed(this, step.second.toLong())
        }
    }

    private var currentSteps: List<Pair<Boolean, Int>> = emptyList()

    fun isAvailable(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        if (appContext.checkSelfPermission(android.Manifest.permission.CAMERA) !=
            PackageManager.PERMISSION_GRANTED
        ) return false
        return findFlashCameraId() != null
    }

    fun pulse(pattern: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            throw UnsupportedOperationException("Flashlight requires Android 6.0 or later.")
        }
        if (appContext.checkSelfPermission(android.Manifest.permission.CAMERA) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            throw SecurityException("Camera permission is required to use the flashlight.")
        }
        val cameraId = findFlashCameraId()
            ?: throw IllegalStateException("This device does not have an available camera flash.")

        handler.post {
            stop()
            activeCameraId = cameraId
            currentSteps = when (pattern) {
                "double" -> listOf(
                    true to 180, false to 140, true to 180, false to 350,
                    true to 180, false to 140, true to 180, false to 500,
                )
                "sos" -> listOf(
                    true to 150, false to 130, true to 150, false to 130,
                    true to 150, false to 350,
                    true to 400, false to 180,
                    true to 400, false to 180,
                    true to 400, false to 350,
                    true to 150, false to 130, true to 150, false to 130,
                    true to 150, false to 700,
                )
                else -> listOf(true to 650, false to 250, true to 650, false to 350)
            }
            stepIndex = 0
            isRunning = true
            patternSteps.run()
        }
    }

    fun stop() {
        handler.removeCallbacks(patternSteps)
        isRunning = false
        stepIndex = 0
        turnOff()
    }

    private fun setTorch(enabled: Boolean) {
        val cameraId = activeCameraId ?: return
        cameraManager.setTorchMode(cameraId, enabled)
    }

    private fun turnOff() {
        val cameraId = activeCameraId ?: return
        try {
            cameraManager.setTorchMode(cameraId, false)
        } catch (_: Exception) {
            // The camera service may already have reclaimed the flash.
        }
    }

    private fun findFlashCameraId(): String? {
        return try {
            cameraManager.cameraIdList.firstOrNull { cameraId ->
                val characteristics = cameraManager.getCameraCharacteristics(cameraId)
                characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true &&
                    characteristics.get(CameraCharacteristics.LENS_FACING) ==
                    CameraCharacteristics.LENS_FACING_BACK
            } ?: cameraManager.cameraIdList.firstOrNull { cameraId ->
                cameraManager.getCameraCharacteristics(cameraId)
                    .get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            }
        } catch (_: Exception) {
            null
        }
    }
}
