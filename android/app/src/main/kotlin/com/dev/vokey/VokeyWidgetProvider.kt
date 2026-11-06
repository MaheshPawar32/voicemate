package com.dev.vokey

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews

/** Home-screen widget showing monitoring status with Stop / Open actions. */
class VokeyWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        render(context, manager, ids)
    }

    companion object {
        fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val active = VoiceMonitoringService.isActive
            val views = RemoteViews(context.packageName, R.layout.vokey_widget)
            views.setTextViewText(
                R.id.widget_status,
                if (active) "Listening" else "Not listening",
            )
            views.setTextViewText(
                R.id.widget_modes,
                if (active) VoiceMonitoringService.activeModesLabel() else "Tap Open to start the finder",
            )
            if (active) {
                val elapsed = System.currentTimeMillis() - VoiceMonitoringService.startedAtMs()
                views.setChronometer(
                    R.id.widget_timer, SystemClock.elapsedRealtime() - elapsed, null, true,
                )
                views.setViewVisibility(R.id.widget_timer, View.VISIBLE)
                views.setViewVisibility(R.id.widget_stop, View.VISIBLE)
            } else {
                views.setChronometer(R.id.widget_timer, SystemClock.elapsedRealtime(), null, false)
                views.setViewVisibility(R.id.widget_timer, View.GONE)
                views.setViewVisibility(R.id.widget_stop, View.GONE)
            }
            val open = PendingIntent.getActivity(
                context, 20,
                Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    .putExtra(MainActivity.EXTRA_LAUNCH_SOURCE, "widget"),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            val stop = PendingIntent.getBroadcast(
                context, 21,
                Intent(context, VokeyControlReceiver::class.java)
                    .setAction(VokeyControlReceiver.ACTION_WIDGET_STOP),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            views.setOnClickPendingIntent(R.id.widget_root, open)
            views.setOnClickPendingIntent(R.id.widget_open, open)
            views.setOnClickPendingIntent(R.id.widget_stop, stop)
            manager.updateAppWidget(ids, views)
        }
    }
}

/**
 * Handles widget Stop. Stale intents (monitoring already stopped, e.g. after
 * process death) only refresh the widget — they never start anything.
 */
class VokeyControlReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_WIDGET_STOP = "com.dev.vokey.action.WIDGET_STOP"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_WIDGET_STOP) return
        if (VoiceMonitoringService.isActive) {
            context.startService(
                Intent(context, VoiceMonitoringService::class.java)
                    .setAction(VoiceMonitoringService.ACTION_STOP),
            )
        } else {
            VokeyStateBroadcaster.publish(context)
        }
    }
}
