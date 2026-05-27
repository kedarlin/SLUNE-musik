package com.example.music.player

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Binder
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.KeyEvent
import androidx.annotation.OptIn
import androidx.core.app.NotificationCompat
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import io.flutter.plugin.common.EventChannel
import org.json.JSONObject

class MusicPlayerService : MediaSessionService() {

    companion object {
        const val NOTIF_ID = 9991
        const val CHANNEL_ID = "music_player_channel"
    }

    private lateinit var player: ExoPlayer
    private lateinit var mediaSession: MediaSession

    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())

    private val binder = LocalBinder()

    inner class LocalBinder : Binder() {
        fun getService(): MusicPlayerService = this@MusicPlayerService
    }

    // MUST MATCH EXACT SIGNATURE
    override fun onBind(intent: Intent?): IBinder {
        super.onBind(intent)
        return binder
    }

    private fun createNotificationChannel() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel =
                    NotificationChannel(
                            CHANNEL_ID,
                            "Music Playback",
                            NotificationManager.IMPORTANCE_LOW
                    )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    @OptIn(UnstableApi::class)
    override fun onCreate() {
        super.onCreate()

        createNotificationChannel()

        player = ExoPlayer.Builder(this).build()

        mediaSession = MediaSession.Builder(this, player).setCallback(MySessionCallback()).build()

        player.addListener(PlayerCallback())

        startPositionUpdates()

        startForeground(NOTIF_ID, buildNotification())
    }

    override fun onDestroy() {
        mediaSession.release()
        player.release()
        super.onDestroy()
    }

    // MUST MATCH Media3 v1.8.0
    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession {
        return mediaSession
    }

    // =======================
    // PUBLIC API FROM FLUTTER
    // =======================
    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun load(uri: String, title: String?, id: String?, artist: String?, artwork: ByteArray?) {
        val item = MediaItem.Builder().setUri(uri).setMediaId(id ?: "").setTag(title).build()

        player.setMediaItem(item)
        player.prepare()
        player.play()
    }

    fun play() = player.play()
    fun pause() = player.pause()
    fun seek(position: Long) = player.seekTo(position)
    fun setSpeedPitch(speed: Float, pitch: Float) {
        player.playbackParameters = PlaybackParameters(speed, pitch)
    }

    fun sendCommand(cmd: String) {
        sendFlutterCommand(cmd)
    }

    fun loadPlaylist(items: List<MediaItem>, index: Int) {
        player.setMediaItems(items, index, 0)
        player.prepare()
        player.play()
    }

    // ===========================================
    // NEW SIGNATURES FOR MediaSession.Callback
    // ===========================================
    @UnstableApi
    inner class MySessionCallback : MediaSession.Callback {

        override fun onMediaButtonEvent(
                session: MediaSession,
                controllerInfo: MediaSession.ControllerInfo,
                intent: Intent
        ): Boolean {

            val keyEvent = intent.getParcelableExtra<KeyEvent>(Intent.EXTRA_KEY_EVENT)

            if (keyEvent != null) {
                when (keyEvent.keyCode) {
                    KeyEvent.KEYCODE_MEDIA_NEXT -> sendFlutterCommand("next")
                    KeyEvent.KEYCODE_MEDIA_PREVIOUS -> sendFlutterCommand("previous")
                }
            }

            return super.onMediaButtonEvent(session, controllerInfo, intent)
        }
    }

    // ===========================================
    // Player → Flutter events
    // ===========================================
    inner class PlayerCallback : Player.Listener {
        override fun onEvents(player: Player, events: Player.Events) {
            sendUpdate()
        }
    }

    private fun sendUpdate() {
        val data = JSONObject()
        data.put("position", player.currentPosition)
        data.put("duration", if (player.duration > 0) player.duration else 0)
        data.put("isPlaying", player.isPlaying)
        data.put("state", player.playbackState)
        eventSink?.success(data.toString())
    }

    private fun sendFlutterCommand(cmd: String) {
        val data = JSONObject()
        data.put("command", cmd)
        eventSink?.success(data.toString())
    }

    private fun startPositionUpdates() {
        handler.post(
                object : Runnable {
                    override fun run() {
                        sendUpdate()
                        handler.postDelayed(this, 200)
                    }
                }
        )
    }

    private fun buildNotification(): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pi = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE)

        return NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Music Player")
                .setContentText("Playing music")
                // .setSmallIcon(R.mipmap.ic_launcher)
                // .setContentIntent(pi)
                .setOngoing(true)
                .build()
    }
}
