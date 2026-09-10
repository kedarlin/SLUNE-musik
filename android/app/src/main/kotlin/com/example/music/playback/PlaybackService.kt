package com.example.music.playback

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.DefaultAudioSink
import androidx.media3.session.CacheBitmapLoader
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import androidx.media3.session.SessionCommand
import androidx.media3.session.SessionResult
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

private const val TAG = "PlaybackService"

/**
 * Owns the single ExoPlayer + MediaSession for the app. Replaces the native
 * Oboe/C++ engine: ExoPlayer owns decode, buffering, the queue, gapless
 * playback, speed/pitch (Sonic), audio focus, and the media notification.
 *
 * UI (Flutter, via MainActivity/PlayerChannel) talks to this service through
 * a MediaController connected by SessionToken - never a direct service
 * binding - so this stays a normal Media3 app rather than a bespoke setup.
 */
class PlaybackService : MediaSessionService() {

    private lateinit var player: ExoPlayer
    private var mediaSession: MediaSession? = null

    /**
     * The "Lofi" effect. It lives in the ExoPlayer AudioProcessor chain (see
     * [buildRenderersFactory]) rather than android.media.audiofx, so it works
     * on every device - the Vivo test device's AudioFlinger flatly refuses to
     * create a PresetReverb. Independent of the queue: changing tracks does
     * not reset it, and it never touches queue state.
     */
    private val lofiProcessor = LofiAudioProcessor()

    /**
     * Tracked so a later equalizer / bass-boost / virtualizer pass can attach
     * android.media.audiofx effects to whatever AudioTrack is currently
     * playing. Not otherwise consumed yet.
     */
    var currentAudioSessionId: Int = C.AUDIO_SESSION_ID_UNSET
        private set

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "onCreate")

        val audioAttributes = AudioAttributes.Builder()
            .setUsage(C.USAGE_MEDIA)
            .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
            .build()

        player = ExoPlayer.Builder(this, buildRenderersFactory())
            .setLoadControl(buildLoadControl())
            .setAudioAttributes(audioAttributes, /* handleAudioFocus= */ true)
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(C.WAKE_MODE_LOCAL)
            .build()

        player.addListener(PlaybackEventListener())
        player.addAnalyticsListener(
            object : AnalyticsListener {
                override fun onAudioSessionIdChanged(
                    eventTime: AnalyticsListener.EventTime,
                    audioSessionId: Int,
                ) {
                    currentAudioSessionId = audioSessionId
                }
            }
        )

        mediaSession = MediaSession.Builder(this, player)
            .setCallback(PlaybackSessionCallback())
            .setBitmapLoader(CacheBitmapLoader(ArtworkBitmapLoader(this)))
            .build()
    }

    /**
     * Custom MediaSession commands for things with no built-in Player command
     * (currently just the Lofi level). Queue/playback commands all stay on the
     * standard Player API - this is additive, not a parallel command path.
     */
    private inner class PlaybackSessionCallback : MediaSession.Callback {
        override fun onConnect(
            session: MediaSession,
            controller: MediaSession.ControllerInfo,
        ): MediaSession.ConnectionResult {
            // Deliberately NOT super.onConnect(): MediaSession.Callback's
            // synchronous onConnect() default falls back to a deprecated
            // stub that grants Commands.EMPTY, not the real trust-aware
            // default (that lives in onConnectAsync()'s default, built via
            // this same two-arg AcceptedResultBuilder). Building it directly
            // here gives the normal full player command set, plus our one
            // custom session command on top.
            val builder = MediaSession.ConnectionResult.AcceptedResultBuilder(session, controller)
            val sessionCommands = builder.build().availableSessionCommands.buildUpon()
                .add(SessionCommand(CMD_SET_LOFI, Bundle.EMPTY))
                .build()
            return builder.setAvailableSessionCommands(sessionCommands).build()
        }

        override fun onCustomCommand(
            session: MediaSession,
            controller: MediaSession.ControllerInfo,
            customCommand: SessionCommand,
            args: Bundle,
        ): ListenableFuture<SessionResult> {
            if (customCommand.customAction == CMD_SET_LOFI) {
                lofiProcessor.level = args.getFloat(KEY_LOFI_LEVEL, 0f)
                return Futures.immediateFuture(SessionResult(SessionResult.RESULT_SUCCESS))
            }
            return super.onCustomCommand(session, controller, customCommand, args)
        }
    }

    companion object {
        const val CMD_SET_LOFI = "muxic.setLofi"
        const val KEY_LOFI_LEVEL = "level"
    }

    private fun buildRenderersFactory(): DefaultRenderersFactory {
        return object : DefaultRenderersFactory(this) {
            override fun buildAudioSink(
                context: Context,
                enableFloatOutput: Boolean,
                enableAudioOutputPlaybackParams: Boolean,
            ): AudioSink {
                // The Lofi processor sits first in the chain; Media3 appends
                // its own silence-skipping + Sonic (speed/pitch) processors
                // after it, so both keep working.
                return DefaultAudioSink.Builder(context)
                    .setEnableFloatOutput(enableFloatOutput)
                    .setEnableAudioOutputPlaybackParameters(enableAudioOutputPlaybackParams)
                    .setAudioProcessorChain(
                        DefaultAudioSink.DefaultAudioProcessorChain(lofiProcessor)
                    )
                    .build()
            }
        }.setEnableDecoderFallback(true)
    }

    private fun buildLoadControl(): DefaultLoadControl {
        // Local file playback only, so there is no network stall to hide -
        // these are ExoPlayer's own defaults, made explicit as the one place
        // to retune if a device still shows dropouts.
        return DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                /* minBufferMs= */ 50_000,
                /* maxBufferMs= */ 50_000,
                /* bufferForPlaybackMs= */ 2_500,
                /* bufferForPlaybackAfterRebufferMs= */ 5_000,
            )
            .build()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return mediaSession
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Matches the product decision made earlier in this project: swiping
        // the app away from Recents stops playback and clears the
        // notification, rather than continuing in the background.
        player.pause()
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        mediaSession?.release()
        mediaSession = null
        player.release()
        super.onDestroy()
    }

    /**
     * One corrupt or unsupported file must not end the session. On the
     * first error for an item, retry preparing once (transient decoder
     * hiccups); on a second consecutive failure, skip to the next item.
     */
    private inner class PlaybackEventListener : Player.Listener {
        private var hasRetriedCurrentItem = false

        override fun onPlayerError(error: PlaybackException) {
            Log.e(TAG, "onPlayerError: ${error.errorCodeName}", error)
            if (!hasRetriedCurrentItem) {
                hasRetriedCurrentItem = true
                player.prepare()
                return
            }

            hasRetriedCurrentItem = false
            if (player.hasNextMediaItem()) {
                player.seekToNextMediaItem()
                player.prepare()
                player.play()
            }
        }

        override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
            hasRetriedCurrentItem = false
        }
    }
}
