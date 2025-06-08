package com.example.plengiai.plengi_ai

import com.example.plengiai.plengi_ai.MainApplication.Companion.eventSink
import io.flutter.plugin.common.EventChannel

class EventStreamHandler: EventChannel.StreamHandler {
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        println("EventStreamHandler: onListen called")
        eventSink = events
        println("EventStreamHandler: eventSink set")
    }

    override fun onCancel(arguments: Any?) {
        println("EventStreamHandler: onCancel called")
        eventSink = null
    }
}