package com.example.music

import com.example.music.lyrics.LyricsChannel
import com.example.music.playback.PlayerChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private lateinit var playerChannel: PlayerChannel
    private lateinit var lyricsChannel: LyricsChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        playerChannel = PlayerChannel(applicationContext)
        playerChannel.attach(flutterEngine.dartExecutor.binaryMessenger)

        lyricsChannel = LyricsChannel(applicationContext)
        lyricsChannel.attach(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onDestroy() {
        // Release our MediaController connection to PlaybackService. Without
        // this, the in-process bind it holds keeps the service alive even
        // after the app is killed - PlaybackService.onTaskRemoved() already
        // calls pause()+stopSelf(), but stopSelf() cannot actually tear the
        // service down while something is still bound to it, which is why
        // playback and the notification were surviving a task swipe-away.
        if (::playerChannel.isInitialized) {
            playerChannel.release()
        }
        super.onDestroy()
    }
}
