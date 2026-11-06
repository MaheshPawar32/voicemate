package com.dev.vokey

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.service.quicksettings.TileService

/**
 * Pushes the authoritative monitoring state to the Quick Settings tile and
 * home-screen widgets. Called on every state change; nothing polls.
 */
internal object VokeyStateBroadcaster {
    fun publish(context: Context) {
        val app = context.applicationContext
        try {
            TileService.requestListeningState(app, ComponentName(app, MonitoringTileService::class.java))
        } catch (_: Exception) {
            // Tile not added by the user, or SystemUI unavailable.
        }
        val manager = AppWidgetManager.getInstance(app) ?: return
        val ids = manager.getAppWidgetIds(ComponentName(app, VokeyWidgetProvider::class.java))
        if (ids.isNotEmpty()) VokeyWidgetProvider.render(app, manager, ids)
    }
}
