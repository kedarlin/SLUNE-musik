package com.example.music.playback

import android.content.ComponentName
import android.content.ContentUris
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Build
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
import androidx.media3.session.SessionResult
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

    private val audioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
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
            "setEqEnabled" -> sendFx(result, PlaybackService.CMD_FX_EQ_ENABLED) {
                putBoolean("enabled", (args?.get("enabled") as? Boolean) ?: false)
            }
            "setEqPreset" -> {
                val preset = (args?.get("preset") as? Int) ?: -1
                val current = controller
                if (current == null) {
                    result.success(emptyList<Int>())
                } else {
                    val future = current.sendCustomCommand(
                        SessionCommand(PlaybackService.CMD_FX_EQ_PRESET, Bundle.EMPTY),
                        Bundle().apply { putInt("preset", preset) },
                    )
                    Futures.addCallback(
                        future,
                        object : FutureCallback<SessionResult> {
                            override fun onSuccess(value: SessionResult) {
                                result.success(
                                    value.extras.getIntArray("bands")?.toList()
                                        ?: emptyList<Int>()
                                )
                            }

                            override fun onFailure(t: Throwable) {
                                result.success(emptyList<Int>())
                            }
                        },
                        MoreExecutors.directExecutor(),
                    )
                }
            }
            "setEqBand" -> sendFx(result, PlaybackService.CMD_FX_EQ_BAND) {
                putInt("band", (args?.get("band") as? Int) ?: 0)
                putInt("level", (args?.get("level") as? Int) ?: 0)
            }
            "setBassBoost" -> sendFx(result, PlaybackService.CMD_FX_BASS_BOOST) {
                putInt("strength", (args?.get("strength") as? Int) ?: 0)
            }
            "setVirtualizer" -> sendFx(result, PlaybackService.CMD_FX_VIRTUALIZER) {
                putInt("strength", (args?.get("strength") as? Int) ?: 0)
            }
            "setReverb" -> sendFx(result, PlaybackService.CMD_FX_REVERB) {
                putInt("preset", (args?.get("preset") as? Int) ?: 0)
            }
            "getFxCaps" -> getFxCaps(result)
            "getOutputBucket" -> result.success(currentOutputBucket())
            "getFormatInfo" -> {
                val sourcePath = args?.get("sourcePath") as? String
                result.success(
                    if (sourcePath != null) getFormatInfo(sourcePath) else emptyMap<String, Any?>()
                )
            }
            "getHiResSupport" -> {
                val sourcePath = args?.get("sourcePath") as? String
                result.success(if (sourcePath != null) getHiResSupport(sourcePath) else "unknown")
            }
            "setHiRes" -> sendFx(result, PlaybackService.CMD_SET_HI_RES) {
                putBoolean("enabled", (args?.get("enabled") as? Boolean) ?: false)
            }
            "setSeekButtons" -> sendFx(result, PlaybackService.CMD_SET_SEEK_BUTTONS) {
                putBoolean("enabled", (args?.get("enabled") as? Boolean) ?: false)
            }
            "setCrossfade" -> sendFx(result, PlaybackService.CMD_SET_CROSSFADE) {
                putInt("ms", (args?.get("ms") as? Int) ?: 0)
            }
            "setResumeOnBluetooth" -> sendFx(result, PlaybackService.CMD_SET_RESUME_ON_BLUETOOTH) {
                putBoolean("enabled", (args?.get("enabled") as? Boolean) ?: false)
            }
            "setPreamp" -> sendFx(result, PlaybackService.CMD_FX_PREAMP) {
                putInt("mb", (args?.get("mb") as? Int) ?: 0)
            }
            "setMono" -> sendFx(result, PlaybackService.CMD_SET_MONO) {
                putBoolean("enabled", (args?.get("enabled") as? Boolean) ?: false)
            }
            else -> result.notImplemented()
        }
    }

    /** Fire-and-forget custom command to the audiofx layer. */
    private fun sendFx(result: Result, action: String, args: Bundle.() -> Unit) {
        val current = controller
        val bundle = Bundle().apply(args)
        val send: (MediaController) -> Unit = { c ->
            c.sendCustomCommand(SessionCommand(action, Bundle.EMPTY), bundle)
        }
        if (current != null) {
            send(current)
        } else {
            pendingCommands.add(send)
        }
        result.success(null)
    }

    private fun getFxCaps(result: Result) {
        val current = controller
        if (current == null) {
            result.success(null)
            return
        }
        val future = current.sendCustomCommand(
            SessionCommand(PlaybackService.CMD_FX_CAPS, Bundle.EMPTY),
            Bundle.EMPTY,
        )
        Futures.addCallback(
            future,
            object : FutureCallback<SessionResult> {
                override fun onSuccess(value: SessionResult) {
                    val b = value.extras
                    result.success(
                        mapOf(
                            "eqAvailable" to b.getBoolean("eqAvailable"),
                            "bandCount" to b.getInt("bandCount"),
                            "centerFreqsMilliHz" to
                                (b.getIntArray("centerFreqsMilliHz")?.toList() ?: emptyList<Int>()),
                            "minLevelMb" to b.getInt("minLevelMb"),
                            "maxLevelMb" to b.getInt("maxLevelMb"),
                            "presetNames" to
                                (b.getStringArray("presetNames")?.toList() ?: emptyList<String>()),
                            "bassBoostAvailable" to b.getBoolean("bassBoostAvailable"),
                            "virtualizerAvailable" to b.getBoolean("virtualizerAvailable"),
                            "reverbAvailable" to b.getBoolean("reverbAvailable"),
                        )
                    )
                }

                override fun onFailure(t: Throwable) {
                    result.success(null)
                }
            },
            MoreExecutors.directExecutor(),
        )
    }

    /**
     * Best-effort "what kind of output is this probably playing through"
     * bucket, used by MusicControllerBloc to switch between per-device EQ
     * profiles. Android doesn't expose a direct "which device is this
     * specific app's audio actually routed to" query without an active
     * AudioTrack reference, so this uses the same priority heuristic the OS
     * itself generally follows: a wired connection wins over Bluetooth,
     * which wins over the built-in speaker.
     */
    private fun currentOutputBucket(): String {
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        val hasWired = devices.any {
            it.type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                it.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES
        }
        if (hasWired) return "wired"
        val hasBluetooth = devices.any {
            it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO
        }
        if (hasBluetooth) return "bluetooth"
        return "speaker"
    }

    /**
     * Reads container-level format info (no decode) for the Hi-Res/Lossless
     * settings row - sample rate/channel count/bitrate come straight from
     * the track's own MediaFormat; bit depth only comes back non-null for
     * lossless containers (FLAC/WAV) that actually carry a KEY_PCM_ENCODING,
     * since lossy codecs (MP3/AAC/OGG) have no fixed bit depth to report.
     */
    private fun getFormatInfo(sourcePath: String): Map<String, Any?> {
        val extractor = MediaExtractor()
        return try {
            extractor.setDataSource(sourcePath)
            var result: Map<String, Any?> = emptyMap()
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (!mime.startsWith("audio/")) continue

                result = mapOf(
                    "mimeType" to mime,
                    "sampleRateHz" to format.getIntegerOrNull(MediaFormat.KEY_SAMPLE_RATE),
                    "channelCount" to format.getIntegerOrNull(MediaFormat.KEY_CHANNEL_COUNT),
                    "bitrateBps" to format.getIntegerOrNull(MediaFormat.KEY_BIT_RATE),
                    "bitDepth" to pcmEncodingToBitDepth(format),
                )
                break
            }
            result
        } catch (error: Exception) {
            Log.w(TAG, "getFormatInfo failed for $sourcePath", error)
            emptyMap()
        } finally {
            extractor.release()
        }
    }

    private fun MediaFormat.getIntegerOrNull(key: String): Int? =
        if (containsKey(key)) getInteger(key) else null

    private fun pcmEncodingToBitDepth(format: MediaFormat): Int? {
        val encoding = format.getIntegerOrNull(MediaFormat.KEY_PCM_ENCODING) ?: return null
        return when (encoding) {
            AudioFormat.ENCODING_PCM_16BIT -> 16
            AudioFormat.ENCODING_PCM_24BIT_PACKED -> 24
            AudioFormat.ENCODING_PCM_32BIT -> 32
            AudioFormat.ENCODING_PCM_FLOAT -> 32
            else -> null
        }
    }

    /**
     * Honest, per-file/per-device direct-output status via the real
     * AudioManager.getDirectPlaybackSupport() (API 29+) - reports what the
     * OS actually grants rather than assuming Hi-Res mode guarantees a
     * bit-perfect path (Android has no documented universal API to force
     * that the way desktop OSes do).
     */
    private fun getHiResSupport(sourcePath: String): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return "unknown"
        val info = getFormatInfo(sourcePath)
        val sampleRate = info["sampleRateHz"] as? Int ?: return "unknown"
        val channelCount = info["channelCount"] as? Int ?: return "unknown"
        return try {
            val channelMask =
                if (channelCount == 1) AudioFormat.CHANNEL_OUT_MONO else AudioFormat.CHANNEL_OUT_STEREO
            val audioFormat = AudioFormat.Builder()
                .setSampleRate(sampleRate)
                .setChannelMask(channelMask)
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .build()
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
            val support = AudioManager.getDirectPlaybackSupport(audioFormat, attributes)
            if (support != AudioManager.DIRECT_PLAYBACK_NOT_SUPPORTED) "direct" else "mixed"
        } catch (error: Exception) {
            Log.w(TAG, "getDirectPlaybackSupport failed for $sourcePath", error)
            "unknown"
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
