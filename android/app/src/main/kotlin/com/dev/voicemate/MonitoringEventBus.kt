package com.dev.voicemate

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/** Delivers metadata-only monitoring status events to an attached Flutter listener. */
internal object MonitoringEventBus {
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile private var sink: EventChannel.EventSink? = null

    fun attach(eventSink: EventChannel.EventSink?) {
        sink = eventSink
    }

    fun detach() {
        sink = null
    }

    fun emit(event: Map<String, Any>) {
        mainHandler.post { sink?.success(event) }
    }
}
