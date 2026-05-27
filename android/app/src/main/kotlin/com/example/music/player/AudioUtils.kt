package com.example.music.nativeaudio

object AudioUtils {
    fun decodeToPCM(path: String): ByteArray {
        // TODO: Use MediaExtractor + MediaCodec
        return ByteArray(0)
    }

    fun timeStretchAndReverb(pcm: ByteArray, speed: Float, reverbAmount: Float): ByteArray {
        // TODO: Integrate Sonic or SoundTouch
        return pcm
    }
}
