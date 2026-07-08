package com.example.music

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import android.util.Log
import androidx.media3.common.MediaItem
import com.example.music.player.MusicPlayerService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val METHOD = "native_audio"
    private val EVENTS = "native_audio_events"
    private val CHANNEL = "muxic/native"

    private var service: MusicPlayerService? = null
    private var bound = false

    private val conn =
            object : ServiceConnection {
                override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
                    val localBinder = binder as MusicPlayerService.LocalBinder
                    service = localBinder.getService()
                    bound = true
                }

                override fun onServiceDisconnected(name: ComponentName?) {
                    bound = false
                    service = null
                }
            }

    override fun onStart() {
        super.onStart()
        bindToService()
    }

    override fun onStop() {
        super.onStop()
        if (bound) {
            unbindService(conn)
            bound = false
        }
    }

    private fun bindToService() {
        val intent = Intent(this, MusicPlayerService::class.java)
        startService(intent) // Ensure service stays alive
        bindService(intent, conn, Context.BIND_AUTO_CREATE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ============================
        // Channel → Flutter
        // ============================
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call,
                result ->
            when (call.method) {
                "initializeAndroid" -> {
                    Log.i("MuxicEngine", "Initializing Android Context")
                    NativeBridge.nativeInitializeAndroid(applicationContext)

                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // ============================
        // EventChannel → Flutter
        // ============================
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENTS)
                .setStreamHandler(
                        object : EventChannel.StreamHandler {
                            override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                                service?.setEventSink(sink)
                            }

                            override fun onCancel(args: Any?) {
                                service?.setEventSink(null)
                            }
                        }
                )

        // ============================
        // MethodChannel → Native
        // ============================
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD).setMethodCallHandler {
                call,
                result ->
            when (call.method) {
                "load" -> {
                    val uri = call.argument<String>("uri")!!
                    val title = call.argument<String>("title")
                    val id = call.argument<String>("id")
                    val artist = call.argument<String>("artist")
                    val artwork = call.argument<ByteArray>("artwork")

                    service?.load(uri, title, id, artist, artwork)
                    result.success(null)
                }
                "play" -> {
                    service?.play()
                    result.success(null)
                }
                "pause" -> {
                    service?.pause()
                    result.success(null)
                }
                "seek" -> {
                    val pos = call.argument<Int>("position") ?: 0
                    service?.seek(pos.toLong())
                    result.success(null)
                }
                "speedPitch" -> {
                    val speed = call.argument<Double>("speed")!!.toFloat()
                    val pitch = call.argument<Double>("pitch")!!.toFloat()
                    service?.setSpeedPitch(speed, pitch)
                    result.success(null)
                }
                "next" -> {
                    service?.sendCommand("next")
                    result.success(null)
                }
                "previous" -> {
                    service?.sendCommand("previous")
                    result.success(null)
                }
                "loadPlaylist" -> {
                    val list = call.argument<List<Map<String, String>>>("items")!!
                    val index = call.argument<Int>("index")!!

                    val items =
                            list.map {
                                MediaItem.Builder()
                                        .setUri(it["uri"])
                                        .setMediaId(it["id"] ?: "")
                                        .setTag(it["title"])
                                        .build()
                            }

                    service?.loadPlaylist(items, index)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
