package com.example.music

import com.example.music.playback.PlayerChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private lateinit var playerChannel: PlayerChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        playerChannel = PlayerChannel(applicationContext)
        playerChannel.attach(flutterEngine.dartExecutor.binaryMessenger)
    }
}
