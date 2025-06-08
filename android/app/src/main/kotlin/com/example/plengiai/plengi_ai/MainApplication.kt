package com.example.plengiai.plengi_ai

import android.app.Application
import com.loplat.placeengine.Plengi
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainApplication: Application() {
    companion object {
        var eventSink: EventChannel.EventSink? = null
    }

    override fun onCreate() {
        super.onCreate()

        // Plengi 초기화는 별도의 코루틴에서 비동기적으로 수행
        CoroutineScope(Dispatchers.IO).launch {
            Plengi.getInstance(this@MainApplication).start()
        }
    }
}