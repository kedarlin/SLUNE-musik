package com.example.music.playback

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
import androidx.media3.session.CacheBitmapLoader
import androidx.media3.session.DefaultMediaNotificationProvider
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import androidx.media3.session.SessionCommand
import androidx.media3.session.SessionResult
import com.example.music.R
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

    /** Equalizer / bass boost / virtualizer / reverb - see the class doc. */
    private val audioEffects = AudioEffectsController()

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "onCreate")

        val audioAttributes = AudioAttributes.Builder()
            .setUsage(C.USAGE_MEDIA)
            .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
            .build()

        player = ExoPlayer.Builder(this, DefaultRenderersFactory(this).setEnableDecoderFallback(true))
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
                    audioEffects.onSessionId(audioSessionId)
                }
            }
        )

        mediaSession = MediaSession.Builder(this, player)
            .setCallback(PlaybackSessionCallback())
            .setBitmapLoader(CacheBitmapLoader(ArtworkBitmapLoader(this)))
            .build()

        // Media3's own default small icon is a generic bundled music note -
        // use the app icon instead. (The status bar only ever renders its
        // alpha shape as a plain tinted silhouette, per Android's own
        // notification-icon rules - that's normal OS behaviour, not a bug.)
        setMediaNotificationProvider(
            DefaultMediaNotificationProvider(this).apply {
                setSmallIcon(R.mipmap.ic_launcher)
            }
        )
    }

    /**
     * Custom MediaSession commands for the audiofx panel (Equalizer / bass
     * boost / virtualizer / reverb) - none of which have a built-in Player
     * command. Queue/playback commands all stay on the standard Player API;
     * this is additive.
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
            // here gives the normal full player command set, plus our custom
            // session commands on top.
            val builder = MediaSession.ConnectionResult.AcceptedResultBuilder(session, controller)
            val sessionCommands = builder.build().availableSessionCommands.buildUpon().apply {
                for (action in FX_COMMANDS) {
                    add(SessionCommand(action, Bundle.EMPTY))
                }
            }.build()
            return builder.setAvailableSessionCommands(sessionCommands).build()
        }

        override fun onCustomCommand(
            session: MediaSession,
            controller: MediaSession.ControllerInfo,
            customCommand: SessionCommand,
            args: Bundle,
        ): ListenableFuture<SessionResult> {
            val handled = when (customCommand.customAction) {
                CMD_FX_EQ_ENABLED -> {
                    audioEffects.setEqEnabled(args.getBoolean("enabled"))
                    true
                }
                CMD_FX_EQ_PRESET -> {
                    val bands = audioEffects.setEqPreset(
                        args.getInt("preset", AudioEffectsController.PRESET_CUSTOM)
                    )
                    return Futures.immediateFuture(
                        SessionResult(
                            SessionResult.RESULT_SUCCESS,
                            Bundle().apply { putIntArray("bands", bands) },
                        )
                    )
                }
                CMD_FX_EQ_BAND -> {
                    audioEffects.setEqBand(args.getInt("band"), args.getInt("level"))
                    true
                }
                CMD_FX_BASS_BOOST -> {
                    audioEffects.setBassBoost(args.getInt("strength"))
                    true
                }
                CMD_FX_VIRTUALIZER -> {
                    audioEffects.setVirtualizer(args.getInt("strength"))
                    true
                }
                CMD_FX_REVERB -> {
                    audioEffects.setReverb(args.getInt("preset"))
                    true
                }
                CMD_FX_CAPS -> {
                    return Futures.immediateFuture(
                        SessionResult(SessionResult.RESULT_SUCCESS, audioEffects.capabilities())
                    )
                }
                else -> false
            }
            return if (handled) {
                Futures.immediateFuture(SessionResult(SessionResult.RESULT_SUCCESS))
            } else {
                super.onCustomCommand(session, controller, customCommand, args)
            }
        }
    }

    companion object {
        const val CMD_FX_EQ_ENABLED = "muxic.fx.eqEnabled"
        const val CMD_FX_EQ_PRESET = "muxic.fx.eqPreset"
        const val CMD_FX_EQ_BAND = "muxic.fx.eqBand"
        const val CMD_FX_BASS_BOOST = "muxic.fx.bassBoost"
        const val CMD_FX_VIRTUALIZER = "muxic.fx.virtualizer"
        const val CMD_FX_REVERB = "muxic.fx.reverb"
        const val CMD_FX_CAPS = "muxic.fx.caps"

        private val FX_COMMANDS = listOf(
            CMD_FX_EQ_ENABLED,
            CMD_FX_EQ_PRESET,
            CMD_FX_EQ_BAND,
            CMD_FX_BASS_BOOST,
            CMD_FX_VIRTUALIZER,
            CMD_FX_REVERB,
            CMD_FX_CAPS,
        )
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
        audioEffects.release()
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

        override fun onPlaybackStateChanged(playbackState: Int) {
            if (playbackState == Player.STATE_READY) {
                // The AudioTrack is live now - some OEM audio stacks won't
                // create effects any earlier than this.
                audioEffects.reattachIfNeeded(player.audioSessionId)
            }
        }

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
