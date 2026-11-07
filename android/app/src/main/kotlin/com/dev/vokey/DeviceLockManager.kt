package com.dev.vokey

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent

internal class DeviceLockManager(private val context: Context) {
    private val devicePolicyManager =
        context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager

    private val adminComponent =
        ComponentName(context, VokeyDeviceAdminReceiver::class.java)

    fun isAdminActive(): Boolean =
        devicePolicyManager.isAdminActive(adminComponent)

    fun requestAdminActivation(activity: Activity) {
        if (isAdminActive()) return
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
            putExtra(
                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                "Vokey can lock this device when you explicitly choose the Lock Phone action. It cannot unlock the phone or bypass your PIN, pattern, password or biometrics.",
            )
        }
        activity.startActivity(intent)
    }

    /** An app may always remove its own admin; required before uninstalling. */
    fun deactivate(): Boolean {
        if (!isAdminActive()) return true
        devicePolicyManager.removeActiveAdmin(adminComponent)
        return true
    }

    fun lockNow(): Boolean {
        if (!isAdminActive()) return false
        devicePolicyManager.lockNow()
        return true
    }
}
