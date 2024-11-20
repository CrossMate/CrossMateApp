package com.example.cross_mate

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Debug

class MainActivity: FlutterActivity() {
    private val CHANNEL = "memory_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getMemoryUsage" -> {
                    result.success(getMemoryUsage())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getMemoryUsage(): Map<String, Long> {
        val runtime = Runtime.getRuntime()
        return mapOf(
            "javaHeapUsed" to (runtime.totalMemory() - runtime.freeMemory()),
            "nativeHeapUsed" to Debug.getNativeHeapAllocatedSize()
        )
    }
}
