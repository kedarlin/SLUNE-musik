package com.example.music.playback

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer

private const val TAG = "CrossfadeController"
private const val MAX_CROSSFADE_MS = 12_000
private const val RAMP_STEP_MS = 16L
private const val READY_TIMEOUT_MS = 3_000L

/**
 * Best-effort crossfade layered on top of [primary] - the single ExoPlayer
 * that stays the permanent source of truth for the queue/timeline/current
 * index (PlaybackService's and PlayerChannel's usual contract is completely
 * unaffected by this class). A disposable "shadow" ExoPlayer is created only
 * for the few seconds of an actual crossfade and is never wired to the
 * MediaSession, Flutter, or AudioEffectsController - it exists purely so
 * Android's shared audio mixer blends two simultaneous outputs together.
 *
 * When [crossfadeMs] is 0 (the default) this class does nothing and
 * [primary] behaves exactly as it did before this class existed. Manual
 * skip/previous/seek always cancel a crossfade in progress via
 * [cancelActive] (wired from PlaybackService's MediaSession.Callback), so a
 * bug here can only ever fail toward "no crossfade this time", never toward
 * broken playback - every native operation is wrapped in [guarded].
 *
 * Known, accepted limitation: the shadow player has no
 * android.media.audiofx effects attached (EQ/bass/virtualizer/reverb stay
 * on [primary] only), so the incoming track is briefly unequalized during
 * the crossfade window itself. Sharing a single audio session id between
 * both players would fix this but risks AudioEffectsController rebuilding
 * onto the wrong session mid-playback - not worth the risk for a few
 * seconds of polish.
 */
class CrossfadeController(private val context: Context, private val primary: ExoPlayer) {

    var crossfadeMs: Int = 0
        set(value) {
            field = value.coerceIn(0, MAX_CROSSFADE_MS)
            if (field <= 0) cancelActive()
        }

    private var shadow: ExoPlayer? = null
    private var ramping = false
    private var rampStartUptimeMs = 0L
    private var armedForIndex = -1
    private var suppressCancelOnPause = false
    private val handler = Handler(Looper.getMainLooper())

    private val rampRunnable = object : Runnable {
        override fun run() {
            if (!ramping) return
            val s = shadow
            if (s == null) {
                ramping = false
                return
            }
            val elapsed = SystemClock.uptimeMillis() - rampStartUptimeMs
            val t = (elapsed.toFloat() / crossfadeMs.toFloat()).coerceIn(0f, 1f)
            guarded {
                primary.volume = 1f - t
                s.volume = t
            }
            if (t >= 1f) {
                completeCrossfade(s)
            } else {
                handler.postDelayed(this, RAMP_STEP_MS)
            }
        }
    }

    /** Call periodically (e.g. every 200ms) while [primary] is playing. */
    fun onTick() {
        if (crossfadeMs <= 0 || ramping) return
        if (!primary.isPlaying || !primary.hasNextMediaItem()) return

        val duration = primary.duration
        if (duration <= 0 || duration == C.TIME_UNSET) return
        if (duration - primary.currentPosition > crossfadeMs) return
        if (armedForIndex == primary.currentMediaItemIndex) return

        val nextItem = primary.getMediaItemAt(primary.nextMediaItemIndex)
        armedForIndex = primary.currentMediaItemIndex
        startCrossfade(nextItem)
    }

    private fun startCrossfade(nextItem: MediaItem) {
        guarded {
            val s = ExoPlayer.Builder(context).build()
            s.setMediaItem(nextItem)
            s.volume = 0f
            s.prepare()
            s.playWhenReady = true
            shadow = s
            ramping = true
            rampStartUptimeMs = SystemClock.uptimeMillis()
            handler.post(rampRunnable)
        }
    }

    private fun completeCrossfade(shadowPlayer: ExoPlayer) {
        ramping = false
        val handoffPositionMs = shadowPlayer.currentPosition
        suppressCancelOnPause = true
        guarded {
            primary.pause()
            primary.seekToNextMediaItem()
            primary.seekTo(handoffPositionMs)
            primary.volume = 1f
            primary.playWhenReady = true
        }
        waitForPrimaryReadyThenReleaseShadow(shadowPlayer)
    }

    /**
     * Keeps the shadow player bridging audio at full volume until [primary]
     * is actually producing sound again at the handoff point, so there is
     * no silent gap while primary buffers the seek target it just jumped to.
     */
    private fun waitForPrimaryReadyThenReleaseShadow(shadowPlayer: ExoPlayer) {
        var finished = false
        lateinit var listener: Player.Listener
        listener = object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                if (finished) return
                if (playbackState == Player.STATE_READY && primary.isPlaying) {
                    finished = true
                    suppressCancelOnPause = false
                    primary.removeListener(listener)
                    if (shadow === shadowPlayer) releaseShadow()
                }
            }
        }
        primary.addListener(listener)
        handler.postDelayed({
            if (finished) return@postDelayed
            finished = true
            suppressCancelOnPause = false
            guarded { primary.removeListener(listener) }
            if (shadow === shadowPlayer) releaseShadow()
        }, READY_TIMEOUT_MS)
    }

    /** Manual skip/previous/seek always cancel a crossfade in flight. */
    fun cancelActive() {
        if (!ramping && shadow == null) return
        ramping = false
        handler.removeCallbacks(rampRunnable)
        guarded { primary.volume = 1f }
        releaseShadow()
        armedForIndex = -1
    }

    /** True while a manual pause should NOT cancel an in-flight handoff. */
    fun isHandlingOwnPauseResume(): Boolean = suppressCancelOnPause

    private fun releaseShadow() {
        val s = shadow ?: return
        shadow = null
        guarded { s.stop() }
        guarded { s.release() }
    }

    fun release() {
        cancelActive()
    }

    private inline fun guarded(block: () -> Unit) {
        try {
            block()
        } catch (error: Exception) {
            Log.w(TAG, "crossfade step failed, falling back to normal playback", error)
            ramping = false
            suppressCancelOnPause = false
            val s = shadow
            shadow = null
            if (s != null) {
                try {
                    s.release()
                } catch (_: Exception) {
                    // Already broken - nothing more to do.
                }
            }
            try {
                primary.volume = 1f
            } catch (_: Exception) {
                // Primary itself is in a bad state - PlaybackService's own
                // error recovery (retry/skip) handles that, not this class.
            }
        }
    }
}
