package com.example.plengiai.plengi_ai

import android.app.Application
import com.loplat.placeengine.Plengi
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class MainApplication: Application() {
    lateinit var flutterEngine : FlutterEngine

    override fun onCreate() {
        super.onCreate()

        Plengi.getInstance(this).listener = MyPlengiListener()
        Plengi.getInstance(this).start()

        // FlutterEngine 초기화 (예시)
        flutterEngine = FlutterEngine(this)

        // Dart 코드를 실행하도록 설정 (main() 함수가 있는 Dart 파일 지정)
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )

        // FlutterEngineCache에 FlutterEngine 인스턴스 저장
        FlutterEngineCache
            .getInstance()
            .put("flutter_engine", flutterEngine) // "my_engine_id"는 원하는 ID로 지정
    }
}