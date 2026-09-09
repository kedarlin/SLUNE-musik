package com.example.music

import android.util.Log
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Extends AudioServiceActivity (not FlutterActivity) so audio_service can
 * reuse this activity's Flutter engine for the media session.
 */
class MainActivity : AudioServiceActivity() {

    private val CHANNEL = "muxic/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call,
                result ->
            when (call.method) {
                "initializeAndroid" -> {
                    Log.i("MuxicEngine", "Initializing Android Context")
                    NativeBridge.nativeInitializeAndroid(applicationContext)

                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
