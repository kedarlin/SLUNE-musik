package com.example.music.lyrics

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.example.music.R

/**
 * Keeps the app process alive (with a visible, ongoing notification, as
 * Android requires) while a Dart isolate runs vocal-activity-detection +
 * Whisper transcription for the lyrics feature. Does no work itself - the
 * actual decode/ASR happens in LyricsAudioDecoder (native) and the sherpa-onnx
 * isolate (Dart); this is purely a "please don't kill this process" signal.
 */
class LyricsForegroundService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Generating lyrics…"
        startForeground(NOTIFICATION_ID, buildNotification(title))
        return START_NOT_STICKY
    }

    private fun buildNotification(text: String): Notification {
        ensureChannel()
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Muxic")
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Lyrics generation",
                    NotificationManager.IMPORTANCE_LOW,
                )
            )
        }
    }

    companion object {
        const val EXTRA_TITLE = "title"
        private const val CHANNEL_ID = "lyrics_generation"
        private const val NOTIFICATION_ID = 4201
    }
}
