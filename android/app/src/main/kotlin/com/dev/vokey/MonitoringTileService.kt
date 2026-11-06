package com.dev.vokey

import android.app.PendingIntent
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/**
 * Quick Settings tile. Active → tap stops monitoring immediately.
 * Inactive → tap opens Vokey, where the user starts the finder from a visible
 * Activity (Android does not allow a tile to silently start microphone capture).
 */
class MonitoringTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        render()
    }

    override fun onClick() {
        super.onClick()
        if (VoiceMonitoringService.isActive) {
            // The app holds a foreground service, so this start is permitted.
            startService(
                Intent(this, VoiceMonitoringService::class.java)
                    .setAction(VoiceMonitoringService.ACTION_STOP),
            )
            qsTile?.apply {
                state = Tile.STATE_INACTIVE
                updateTile()
            }
        } else {
            openApp()
        }
    }

    private fun openApp() {
        val intent = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra(MainActivity.EXTRA_LAUNCH_SOURCE, "tile")
        if (Build.VERSION.SDK_INT >= 34) {
            startActivityAndCollapse(
                PendingIntent.getActivity(
                    this, 10, intent,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                ),
            )
        } else {
            @Suppress("DEPRECATION", "StartActivityAndCollapseDeprecated")
            startActivityAndCollapse(intent)
        }
    }

    private fun render() {
        val tile = qsTile ?: return
        val active = VoiceMonitoringService.isActive
        tile.icon = Icon.createWithResource(this, R.drawable.ic_stat_vokey)
        tile.label = "Vokey"
        tile.state = if (active) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = if (active) "Listening · tap to stop" else "Tap to open"
        }
        tile.contentDescription = if (active) {
            "Vokey is listening. Tap to stop monitoring."
        } else {
            "Vokey is not listening. Tap to open Vokey."
        }
        tile.updateTile()
    }
}
