package com.example.music.playback

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.audio.ChannelMixingAudioProcessor
import androidx.media3.common.audio.ChannelMixingMatrix
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.DefaultAudioSink
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

    private lateinit var crossfade: CrossfadeController
    private val crossfadeHandler = Handler(Looper.getMainLooper())
    private val crossfadeTicker = object : Runnable {
        override fun run() {
            crossfade.onTick()
            crossfadeHandler.postDelayed(this, 200L)
        }
    }

    private lateinit var headsetResume: HeadsetResumeController

    /**
     * Own receiver rather than ExoPlayer's built-in
     * setHandleAudioBecomingNoisy(true), so [headsetResume] can know exactly
     * when a pause was caused by the output device disappearing (as opposed
     * to the user pausing deliberately) and resume only that case.
     */
    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != AudioManager.ACTION_AUDIO_BECOMING_NOISY) return
            player.pause()
            headsetResume.pausedDueToNoisyDisconnect = true
        }
    }

    /**
     * Read fresh by [buildRenderersFactory]'s buildAudioSink() every time the
     * renderers are (re)built - a mono toggle takes effect via
     * [setMonoEnabled]'s stop()+prepare() cycle, which rebuilds the audio
     * sink from scratch, rather than mutating any processor live while
     * ExoPlayer's internal playback thread might be using it.
     */
    @Volatile
    private var monoEnabled: Boolean = false

    /** Read fresh by [buildRenderersFactory] the same way as [monoEnabled]. */
    @Volatile
    private var hiResEnabled: Boolean = false

    private lateinit var notificationProvider: NotificationButtonProvider

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
            .setWakeMode(C.WAKE_MODE_LOCAL)
            .build()

        headsetResume = HeadsetResumeController(this, player)
        headsetResume.register()
        ContextCompat.registerReceiver(
            this,
            noisyReceiver,
            IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )

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

        crossfade = CrossfadeController(this, player)
        crossfadeHandler.post(crossfadeTicker)

        mediaSession = MediaSession.Builder(this, player)
            .setCallback(PlaybackSessionCallback())
            .setBitmapLoader(CacheBitmapLoader(ArtworkBitmapLoader(this)))
            .build()

        // Media3's own default small icon is a generic bundled music note -
        // use the app icon instead. (The status bar only ever renders its
        // alpha shape as a plain tinted silhouette, per Android's own
        // notification-icon rules - that's normal OS behaviour, not a bug.)
        notificationProvider = NotificationButtonProvider(this).apply {
            setSmallIcon(R.mipmap.ic_launcher)
        }
        setMediaNotificationProvider(notificationProvider)
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

        /**
         * Any manual seek/skip cancels an in-flight crossfade (hard cut
         * instead), before letting the command proceed as normal - a
         * crossfade should only ever happen on a natural end-of-track
         * transition. [CrossfadeController.completeCrossfade] also drives
         * primary through a pause/seek/play sequence of its own; that one
         * must NOT be treated as a manual interruption, which is exactly
         * what [CrossfadeController.isHandlingOwnPauseResume] guards.
         */
        override fun onPlayerCommandRequest(
            session: MediaSession,
            controller: MediaSession.ControllerInfo,
            playerCommand: Int,
        ): Int {
            if (!crossfade.isHandlingOwnPauseResume() && playerCommand in SEEK_COMMANDS) {
                crossfade.cancelActive()
            }
            return super.onPlayerCommandRequest(session, controller, playerCommand)
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
                CMD_SET_CROSSFADE -> {
                    crossfade.crossfadeMs = args.getInt("ms", 0)
                    true
                }
                CMD_SET_RESUME_ON_BLUETOOTH -> {
                    headsetResume.resumeOnBluetoothEnabled = args.getBoolean("enabled")
                    true
                }
                CMD_FX_PREAMP -> {
                    audioEffects.setPreamp(args.getInt("mb", 0))
                    true
                }
                CMD_SET_MONO -> {
                    setMonoEnabled(args.getBoolean("enabled"))
                    true
                }
                CMD_SET_HI_RES -> {
                    setHiResEnabled(args.getBoolean("enabled"))
                    true
                }
                CMD_SET_SEEK_BUTTONS -> {
                    notificationProvider.seekButtonsEnabled = args.getBoolean("enabled")
                    true
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
        const val CMD_SET_CROSSFADE = "muxic.crossfade.set"
        const val CMD_SET_RESUME_ON_BLUETOOTH = "muxic.headset.resumeOnBluetooth"
        const val CMD_FX_PREAMP = "muxic.fx.preamp"
        const val CMD_SET_MONO = "muxic.output.mono"
        const val CMD_SET_HI_RES = "muxic.output.hiRes"
        const val CMD_SET_SEEK_BUTTONS = "muxic.notification.seekButtons"

        private val FX_COMMANDS = listOf(
            CMD_FX_EQ_ENABLED,
            CMD_FX_EQ_PRESET,
            CMD_FX_EQ_BAND,
            CMD_FX_BASS_BOOST,
            CMD_FX_VIRTUALIZER,
            CMD_FX_REVERB,
            CMD_FX_CAPS,
            CMD_SET_CROSSFADE,
            CMD_SET_RESUME_ON_BLUETOOTH,
            CMD_FX_PREAMP,
            CMD_SET_MONO,
            CMD_SET_HI_RES,
            CMD_SET_SEEK_BUTTONS,
        )

        /** Manual seek/skip commands that should cancel an in-flight crossfade. */
        private val SEEK_COMMANDS = setOf(
            Player.COMMAND_SEEK_TO_DEFAULT_POSITION,
            Player.COMMAND_SEEK_IN_CURRENT_MEDIA_ITEM,
            Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM,
            Player.COMMAND_SEEK_TO_PREVIOUS,
            Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM,
            Player.COMMAND_SEEK_TO_NEXT,
            Player.COMMAND_SEEK_TO_MEDIA_ITEM,
        )
    }

    /**
     * The buildAudioSink() seam CLAUDE.md documents for exactly this kind of
     * DSP addition. [monoEnabled] is read fresh here (not baked in at
     * construction), so a mono toggle takes effect the next time renderers
     * are (re)built - i.e. via [setMonoEnabled]'s stop()+prepare() cycle,
     * never by mutating a processor instance ExoPlayer's internal playback
     * thread might currently be using.
     */
    private fun buildRenderersFactory(): DefaultRenderersFactory {
        return object : DefaultRenderersFactory(this) {
            override fun buildAudioSink(
                audioSinkContext: android.content.Context,
                enableFloatOutput: Boolean,
                enableAudioTrackPlaybackParams: Boolean,
            ): AudioSink {
                val builder = DefaultAudioSink.Builder(audioSinkContext)
                    .setEnableFloatOutput(enableFloatOutput)
                    .setEnableAudioTrackPlaybackParams(enableAudioTrackPlaybackParams)
                if (monoEnabled) {
                    val monoMatrix = ChannelMixingMatrix(
                        /* inputChannelCount= */ 2,
                        /* outputChannelCount= */ 2,
                        floatArrayOf(0.5f, 0.5f, 0.5f, 0.5f),
                    )
                    val processor = ChannelMixingAudioProcessor()
                    processor.putChannelMixingMatrix(monoMatrix)
                    builder.setAudioProcessors(arrayOf(processor))
                }
                return builder.build()
            }
        }.setEnableDecoderFallback(true).setEnableAudioFloatOutput(hiResEnabled)
    }

    /**
     * Sums left+right into both output channels (not a true single-channel
     * stream) when [enabled] - matches Android's own "Mono audio"
     * accessibility behaviour, so a single earbud or a one-speaker dock
     * still gets the full mix. Takes effect via a brief stop()+prepare()
     * cycle rather than live, since the audio sink's processor chain is
     * only safely reconfigurable while playback is fully stopped.
     */
    fun setMonoEnabled(enabled: Boolean) {
        if (monoEnabled == enabled) return
        monoEnabled = enabled
        reconfigureAudioSink()
    }

    /**
     * Float PCM output plus EQ/bass/virtualizer/reverb bypass (see
     * AudioEffectsController.setBypassForHiRes) - the best Media3 lets an
     * app request toward "bit-perfect": there is no documented, universal
     * API to force the OS mixer to give exclusive/unmixed output, so this
     * does everything requestable and leaves final direct-output status to
     * be reported honestly via getDirectPlaybackSupport rather than assumed.
     */
    fun setHiResEnabled(enabled: Boolean) {
        if (hiResEnabled == enabled) return
        hiResEnabled = enabled
        audioEffects.setBypassForHiRes(enabled)
        reconfigureAudioSink()
    }

    private fun reconfigureAudioSink() {
        val positionMs = player.currentPosition
        val wasPlaying = player.isPlaying
        player.stop()
        player.prepare()
        player.seekTo(positionMs)
        player.playWhenReady = wasPlaying
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
        crossfadeHandler.removeCallbacks(crossfadeTicker)
        crossfade.release()
        headsetResume.unregister()
        try {
            unregisterReceiver(noisyReceiver)
        } catch (error: IllegalArgumentException) {
            // Already unregistered - not fatal.
        }
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

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            // A real pause (not our own transient pause mid-handoff, see
            // CrossfadeController.completeCrossfade) always cancels a
            // crossfade in flight rather than leaving the shadow player
            // audible on its own while the user thinks they paused.
            if (!isPlaying && !crossfade.isHandlingOwnPauseResume()) {
                crossfade.cancelActive()
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
