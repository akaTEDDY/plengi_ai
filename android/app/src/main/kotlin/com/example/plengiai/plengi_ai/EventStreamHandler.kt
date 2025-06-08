package com.example.plengiai.plengi_ai

import com.example.plengiai.plengi_ai.MainApplication.Companion.eventSink
import io.flutter.plugin.common.EventChannel

class EventStreamHandler: EventChannel.StreamHandler {
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}