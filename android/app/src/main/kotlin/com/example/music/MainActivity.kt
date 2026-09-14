package com.example.music

import android.content.Intent
import com.example.music.library.SongsChannel
import com.example.music.lyrics.LyricsChannel
import com.example.music.playback.PlayerChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private lateinit var playerChannel: PlayerChannel
    private lateinit var lyricsChannel: LyricsChannel
    private lateinit var songsChannel: SongsChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        playerChannel = PlayerChannel(applicationContext)
        playerChannel.attach(flutterEngine.dartExecutor.binaryMessenger)

        lyricsChannel = LyricsChannel(applicationContext)
        lyricsChannel.attach(flutterEngine.dartExecutor.binaryMessenger)

        songsChannel = SongsChannel(this)
        songsChannel.attach(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        // Completes the rename consent flow SongsChannel starts when the OS
        // requires per-file permission (RecoverableSecurityException).
        if (::songsChannel.isInitialized) {
            songsChannel.onActivityResult(requestCode, resultCode)
        }
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
