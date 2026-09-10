package com.example.music.playback

import android.content.ComponentName
import android.content.ContentUris
import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.Timeline
import androidx.media3.session.MediaController
import androidx.media3.session.SessionCommand
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.FutureCallback
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.MoreExecutors
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result

private const val TAG = "PlayerChannel"
private const val METHOD_CHANNEL = "muxic/player"
private const val EVENT_CHANNEL = "muxic/player_events"
private const val POSITION_POLL_MS = 200L

/**
 * Bridges Flutter to the MediaController connected to PlaybackService.
 * Never touches PlaybackService directly - all commands go through the
 * standard Media3 MediaController/SessionToken connection, same as any other
 * Media3 client would.
 *
 * Every MethodChannel call resolves (success or error) on every path, and
 * commands issued before the controller finishes connecting are queued and
 * replayed once it does, so the Dart side never sees a hung Future.
 */
class PlayerChannel(context: Context) {

    private val handler = Handler(Looper.getMainLooper())
    private var controller: MediaController? = null
    private var eventSink: EventChannel.EventSink? = null
    private val pendingCommands = mutableListOf<(MediaController) -> Unit>()

    private val positionPoller = object : Runnable {
        override fun run() {
            emitState()
            handler.postDelayed(this, POSITION_POLL_MS)
        }
    }

    init {
        val sessionToken =
            SessionToken(context, ComponentName(context, PlaybackService::class.java))
        val future = MediaController.Builder(context, sessionToken).buildAsync()

        Log.d(TAG, "connecting MediaController via $sessionToken")
        Futures.addCallback(
            future,
            object : FutureCallback<MediaController> {
                override fun onSuccess(result: MediaController) {
                    Log.d(TAG, "MediaController connected")
                    controller = result
                    result.addListener(PlayerEventListener())
                    pendingCommands.forEach { it(result) }
                    pendingCommands.clear()
                    handler.post(positionPoller)
                }

                override fun onFailure(t: Throwable) {
                    Log.e(TAG, "MediaController connect FAILED", t)
                    eventSink?.error("CONTROLLER_CONNECT_FAILED", t.message, null)
                }
            },
            MoreExecutors.directExecutor(),
        )
    }

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            handleMethodCall(call.method, call.arguments as? Map<*, *>, result)
        }

        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    eventSink = sink
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }

    private fun withController(result: Result, block: (MediaController) -> Unit) {
        val current = controller
        if (current != null) {
            block(current)
            result.success(null)
        } else {
            pendingCommands.add(block)
            result.success(null)
        }
    }

    private fun handleMethodCall(method: String, args: Map<*, *>?, result: Result) {
        Log.d(TAG, "handleMethodCall: $method controller=${controller != null}")
        when (method) {
            "setQueue" -> withController(result) { c ->
                @Suppress("UNCHECKED_CAST")
                val items = (args?.get("items") as? List<Map<*, *>>) ?: emptyList()
                val startIndex = (args?.get("startIndex") as? Int) ?: 0
                val playWhenReady = (args?.get("playWhenReady") as? Boolean) ?: true

                c.setMediaItems(items.map(::toMediaItem), startIndex, 0L)
                c.prepare()
                c.playWhenReady = playWhenReady
            }
            "play" -> withController(result) { it.play() }
            "pause" -> withController(result) { it.pause() }
            "stop" -> withController(result) { it.stop() }
            "seekTo" -> withController(result) { c ->
                c.seekTo((args?.get("positionMs") as? Int)?.toLong() ?: 0L)
            }
            "next" -> withController(result) { c -> if (c.hasNextMediaItem()) c.seekToNextMediaItem() }
            "previous" -> withController(result) { c ->
                if (c.hasPreviousMediaItem()) c.seekToPreviousMediaItem()
            }
            "jumpTo" -> withController(result) { c ->
                val index = (args?.get("index") as? Int) ?: return@withController
                if (index in 0 until c.mediaItemCount) c.seekTo(index, 0L)
            }
            "setSpeed" -> withController(result) { c ->
                val speed = (args?.get("speed") as? Double)?.toFloat() ?: 1.0f
                c.playbackParameters = PlaybackParameters(speed, c.playbackParameters.pitch)
            }
            "setPitch" -> withController(result) { c ->
                val pitch = (args?.get("pitch") as? Double)?.toFloat() ?: 1.0f
                c.playbackParameters = PlaybackParameters(c.playbackParameters.speed, pitch)
            }
            "setShuffle" -> withController(result) { c ->
                c.shuffleModeEnabled = (args?.get("enabled") as? Boolean) ?: false
            }
            "setRepeat" -> withController(result) { c ->
                // Media3's REPEAT_MODE_OFF/ONE/ALL are already 0/1/2, matching
                // the Dart-side RepeatMode enum index directly.
                c.repeatMode = (args?.get("mode") as? Int) ?: Player.REPEAT_MODE_OFF
            }
            "addNext" -> withController(result) { c ->
                val item = (args?.get("item") as? Map<*, *>) ?: return@withController
                val insertAt = (c.currentMediaItemIndex + 1).coerceIn(0, c.mediaItemCount)
                c.addMediaItem(insertAt, toMediaItem(item))
            }
            "addLater" -> withController(result) { c ->
                val item = (args?.get("item") as? Map<*, *>) ?: return@withController
                c.addMediaItem(toMediaItem(item))
            }
            "reorderKeepingCurrent" -> withController(result) { c ->
                @Suppress("UNCHECKED_CAST")
                val rawItems = (args?.get("items") as? List<Map<*, *>>) ?: emptyList()
                val newIndex = (args?.get("currentIndex") as? Int) ?: 0
                val items = rawItems.map(::toMediaItem)
                val curPos = c.currentMediaItemIndex
                val currentId = c.currentMediaItem?.mediaId

                if (items.isEmpty() ||
                    newIndex !in items.indices ||
                    curPos !in 0 until c.mediaItemCount ||
                    currentId == null ||
                    currentId != items[newIndex].mediaId
                ) {
                    // Can't line the current track up with the new list -
                    // fall back to a full reset (this does restart it).
                    val safeIndex = newIndex.coerceIn(0, (items.size - 1).coerceAtLeast(0))
                    c.setMediaItems(items, safeIndex, 0L)
                    c.prepare()
                    return@withController
                }

                // Swap everything except the currently-playing item, which is
                // never inside a replaced range, so it keeps playing without a
                // reprepare even though its index shifts. Tail before head so
                // the head replacement's indices stay simple.
                c.replaceMediaItems(curPos + 1, c.mediaItemCount, items.subList(newIndex + 1, items.size))
                c.replaceMediaItems(0, curPos, items.subList(0, newIndex))
            }
            "moveItem" -> withController(result) { c ->
                val from = (args?.get("from") as? Int) ?: return@withController
                val to = (args?.get("to") as? Int) ?: return@withController
                c.moveMediaItem(from, to)
            }
            "removeItem" -> withController(result) { c ->
                val index = (args?.get("index") as? Int) ?: return@withController
                if (index in 0 until c.mediaItemCount) c.removeMediaItem(index)
            }
            "clearQueue" -> withController(result) { it.clearMediaItems() }
            "setLofi" -> withController(result) { c ->
                val level = (args?.get("level") as? Double)?.toFloat() ?: 0f
                val commandArgs = Bundle().apply {
                    putFloat(PlaybackService.KEY_LOFI_LEVEL, level)
                }
                c.sendCustomCommand(
                    SessionCommand(PlaybackService.CMD_SET_LOFI, Bundle.EMPTY),
                    commandArgs,
                )
            }
            else -> result.notImplemented()
        }
    }

    private fun toMediaItem(map: Map<*, *>): MediaItem {
        val songId = (map["id"] as? Int)?.toLong()

        // The song's own MediaStore URI - ArtworkBitmapLoader resolves the
        // cover from it via ContentResolver.loadThumbnail() / the embedded
        // picture. (The old content://media/external/audio/albumart/<id> path
        // was removed on Android 10+, which is why the notification showed no
        // art.)
        val artworkUri = songId?.let {
            ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, it)
        }

        val metadata = MediaMetadata.Builder()
            .setTitle(map["title"] as? String)
            .setArtist(map["artist"] as? String)
            .setAlbumTitle(map["album"] as? String)
            .setArtworkUri(artworkUri)
            .build()

        return MediaItem.Builder()
            .setMediaId(songId?.toString() ?: "")
            .setUri(map["uri"] as? String)
            .setMediaMetadata(metadata)
            .build()
    }

    private fun emitState() {
        val c = controller ?: return
        val sink = eventSink ?: return

        sink.success(
            mapOf(
                "position" to c.currentPosition.toInt(),
                "duration" to c.duration.coerceAtLeast(0L).toInt(),
                "isPlaying" to c.isPlaying,
                "currentIndex" to c.currentMediaItemIndex,
                "hasNext" to c.hasNextMediaItem(),
                "hasPrevious" to c.hasPreviousMediaItem(),
            )
        )
    }

    private inner class PlayerEventListener : Player.Listener {
        override fun onIsPlayingChanged(isPlaying: Boolean) = emitState()
        override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) = emitState()
        override fun onPlaybackStateChanged(playbackState: Int) = emitState()
        override fun onTimelineChanged(timeline: Timeline, reason: Int) =
            emitState()

        override fun onPlayerError(error: PlaybackException) {
            eventSink?.error("PLAYER_ERROR", error.message, error.errorCodeName)
        }
    }

    fun release() {
        handler.removeCallbacks(positionPoller)
        controller?.release()
        controller = null
    }
}
