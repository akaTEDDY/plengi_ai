package com.example.plengiai.plengi_ai

import android.content.pm.PackageManager
import android.os.Build
import android.widget.Toast
import com.example.plengiai.plengi_ai.MainApplication.Companion.eventSink
import com.google.gson.Gson
import com.loplat.placeengine.OnPlengiListener
import com.loplat.placeengine.PlengiListener
import com.loplat.placeengine.PlengiResponse
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.loplat.placeengine.Plengi
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "plengi.ai/fromFlutter"
    private val EVENT_CHANNEL = "plengi.ai/toFlutter"
    private val LOCATION_PERMISSION_REQUEST_CODE = 10001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // MethodChannel 설정
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "searchPlace") {
                    searchPlace(result)
                } else {
                    result.notImplemented()
                }
            }

        // EventChannel 설정
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(EventStreamHandler())

        Plengi.getInstance(this@MainActivity).listener = object : PlengiListener {
            override fun listen(response: PlengiResponse?) {
                eventSink?.success(Gson().toJson(response))
            }
        }
    }

    private fun checkPermissionForTask(permissions: ArrayList<String>, requestCode: Int): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val deniedPermissions = arrayListOf<String>()
            for (permission in permissions) {
                if (checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED) {
                    deniedPermissions.add(permission)
                }
            }

            if (!deniedPermissions.isEmpty()) {
                for (deniedPermission in deniedPermissions) {
                    if (shouldShowRequestPermissionRationale(deniedPermission)) {
                        // 권한 설명이 필요한 경우
                    }
                }
                requestPermissions(deniedPermissions.toTypedArray(), requestCode)
                return false
            }
        }
        return true
    }

    private fun searchPlace(result: MethodChannel.Result) {
        val checkPermissions: ArrayList<String> =
            arrayListOf(android.Manifest.permission.ACCESS_FINE_LOCATION, android.Manifest.permission.ACCESS_COARSE_LOCATION)
        if (checkPermissionForTask(checkPermissions, LOCATION_PERMISSION_REQUEST_CODE)) {
            Plengi.getInstance(this).TEST_refreshPlace_foreground(object : OnPlengiListener {
                override fun onSuccess(response: PlengiResponse?) {
                    response.let {
                        result.success(Gson().toJson(response))
                    }
                }

                override fun onFail(response: PlengiResponse?) {
                    response.let {
                        result.success(Gson().toJson(response))
                    }
                    Toast.makeText(this@MainActivity, "현재 위치를 확인 할 수 없습니다.", Toast.LENGTH_SHORT).show()
                }
            })
        }
    }
}
