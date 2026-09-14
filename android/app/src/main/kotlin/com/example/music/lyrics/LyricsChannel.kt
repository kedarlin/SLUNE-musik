package com.example.music.lyrics

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap

private const val METHOD_CHANNEL = "muxic/lyrics"

/**
 * Bridges Flutter to the native half of lyrics generation: decoding an
 * arbitrary audio file to the 16 kHz mono WAV the ASR pipeline needs, and
 * holding a foreground-service "keep this process alive" signal while the
 * (Dart-side) sherpa-onnx isolate does VAD + Whisper.
 *
 * The actual speech recognition happens in Dart (sherpa_onnx is a Flutter/FFI
 * plugin) - this channel only covers the two things that must be native:
 * MediaCodec decode, and the foreground service Android requires for a
 * multi-minute background job.
 */
class LyricsChannel(private val context: Context) {

    private val decoder = LyricsAudioDecoder()
    private val mainHandler = Handler(Looper.getMainLooper())

    // Keyed by outputPath, which the Dart side already generates uniquely
    // per generation job - lets an in-flight decode be cancelled by exactly
    // the job that owns it, without disturbing a concurrently running one
    // (interactive generation and generate-ahead can each have a decode in
    // flight at once). ConcurrentHashMap because entries are written/read
    // from the main thread (decodeToWav/cancelDecode handlers) and removed
    // from the background decode Thread (its `finally`) - a plain HashMap
    // touched from two threads like that is a real, if rare, crash risk.
    private val activeDecodes = ConcurrentHashMap<String, DecodeCancellationToken>()

    // Reference count, not a plain flag: an interactive generation for the
    // song on screen and a background generate-ahead job for the next song
    // can each hold the (single, shared) foreground service open at once.
    // Only actually stop it once nothing is using it any more, or a job that
    // finishes first would yank the "keep alive" notification out from under
    // one still in progress.
    private var foregroundHolders = 0

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "decodeToWav" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val outputPath = call.argument<String>("outputPath")
                    val enhanceVocals = call.argument<Boolean>("enhanceVocals") ?: true
                    if (sourcePath == null || outputPath == null) {
                        result.error("BAD_ARGS", "sourcePath and outputPath are required", null)
                        return@setMethodCallHandler
                    }
                    val token = DecodeCancellationToken()
                    activeDecodes[outputPath] = token
                    // MediaCodec decode of a multi-minute file must not run on
                    // the platform channel's main-thread handler.
                    Thread {
                        try {
                            val durationMs =
                                decoder.decodeToWav(sourcePath, outputPath, enhanceVocals, token)
                            mainHandler.post { result.success(durationMs) }
                        } catch (cancelled: DecodeCancelledException) {
                            mainHandler.post { result.error("DECODE_CANCELLED", null, null) }
                        } catch (error: Exception) {
                            mainHandler.post {
                                result.error("DECODE_FAILED", error.message, null)
                            }
                        } finally {
                            activeDecodes.remove(outputPath)
                        }
                    }.start()
                }
                "cancelDecode" -> {
                    val outputPath = call.argument<String>("outputPath")
                    val token = if (outputPath != null) activeDecodes[outputPath] else null
                    if (token != null) {
                        token.cancelled = true
                    }
                    result.success(null)
                }
                "startForegroundService" -> {
                    val title = call.argument<String>("title") ?: "Generating lyrics…"
                    val intent = Intent(context, LyricsForegroundService::class.java)
                        .putExtra(LyricsForegroundService.EXTRA_TITLE, title)
                    ContextCompat.startForegroundService(context, intent)
                    foregroundHolders++
                    result.success(null)
                }
                "stopForegroundService" -> {
                    foregroundHolders = (foregroundHolders - 1).coerceAtLeast(0)
                    if (foregroundHolders == 0) {
                        context.stopService(Intent(context, LyricsForegroundService::class.java))
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
