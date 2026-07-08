package com.example.music

object NativeBridge {
    init {
        System.loadLibrary("muxic_engine")
    }

    external fun nativeInitializeAndroid(context: android.content.Context)
}
