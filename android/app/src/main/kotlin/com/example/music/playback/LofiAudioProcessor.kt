package com.example.music.playback

import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.BaseAudioProcessor
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.exp

/**
 * Lightweight "lofi" colouring done inside the Media3 AudioProcessor chain
 * on 16-bit PCM:
 *   - a gentle high-pass to clean up rumble,
 *   - a warm low-pass to roll off the highs (the classic muffled lofi tone),
 *   - a short feedback delay for a sense of space / depth.
 *
 * Unlike android.media.audiofx.PresetReverb this needs no system audio-effect
 * session, so it works on every device regardless of the OEM effect stack
 * (the Vivo test device's AudioFlinger refuses to create PresetReverb at all).
 *
 * The processor stays in the chain once configured; [level] == 0f is a plain
 * passthrough, so leaving Lofi off costs only a buffer copy.
 */
class LofiAudioProcessor : BaseAudioProcessor() {

    /** 0f = off (dry), 1f = full effect. Safe to set from any thread. */
    @Volatile
    var level: Float = 0f

    private var channelCount = 0
    private var sampleRate = 0

    private var lpState = FloatArray(0)
    private var hpState = FloatArray(0)
    private var lpCoeff = 0f
    private var hpCoeff = 0f

    private var delayLines: Array<FloatArray> = emptyArray()
    private var delayIndex = IntArray(0)
    private var delaySamples = 0

    override fun onConfigure(
        inputAudioFormat: AudioProcessor.AudioFormat,
    ): AudioProcessor.AudioFormat {
        if (inputAudioFormat.encoding != C.ENCODING_PCM_16BIT) {
            throw AudioProcessor.UnhandledAudioFormatException(inputAudioFormat)
        }

        channelCount = inputAudioFormat.channelCount
        sampleRate = inputAudioFormat.sampleRate

        lpState = FloatArray(channelCount)
        hpState = FloatArray(channelCount)
        lpCoeff = onePoleCoeff(3200f)
        hpCoeff = onePoleCoeff(120f)

        delaySamples = (sampleRate * 0.13f).toInt().coerceAtLeast(1)
        delayLines = Array(channelCount) { FloatArray(delaySamples) }
        delayIndex = IntArray(channelCount)

        // Same PCM format out as in - this processor only colours the samples.
        return inputAudioFormat
    }

    private fun onePoleCoeff(cutoffHz: Float): Float =
        (1.0 - exp(-2.0 * PI * cutoffHz / sampleRate)).toFloat()

    override fun queueInput(inputBuffer: ByteBuffer) {
        val remaining = inputBuffer.remaining()
        if (remaining == 0) {
            return
        }

        val frameSize = 2 * channelCount
        val frames = remaining / frameSize
        val consumedBytes = frames * frameSize

        val input = inputBuffer.order(ByteOrder.LITTLE_ENDIAN)
        val output = replaceOutputBuffer(consumedBytes).order(ByteOrder.LITTLE_ENDIAN)
        val wet = level.coerceIn(0f, 1f)

        if (wet <= 0.001f) {
            val limit = input.limit()
            input.limit(input.position() + consumedBytes)
            output.put(input)
            input.limit(limit)
            output.flip()
            return
        }

        // Ease the low-pass toward "no filtering" as the effect is dialed down.
        val lpAmt = lpCoeff + (1f - lpCoeff) * (1f - wet)
        val combFeedback = 0.35f * wet
        val combMix = 0.32f * wet

        for (frame in 0 until frames) {
            for (ch in 0 until channelCount) {
                val dry = input.short.toInt() / 32768f

                hpState[ch] += hpCoeff * (dry - hpState[ch])
                var s = dry - hpState[ch]

                lpState[ch] += lpAmt * (s - lpState[ch])
                s = lpState[ch]

                val di = delayIndex[ch]
                val delayed = delayLines[ch][di]
                delayLines[ch][di] = s + delayed * combFeedback
                delayIndex[ch] = if (di + 1 >= delaySamples) 0 else di + 1
                s += delayed * combMix

                val out = dry * (1f - wet) + s * wet
                val clamped = (out * 32768f).coerceIn(-32768f, 32767f)
                output.putShort(clamped.toInt().toShort())
            }
        }

        output.flip()
    }

    override fun onFlush() {
        resetState()
    }

    override fun onReset() {
        resetState()
    }

    private fun resetState() {
        lpState.fill(0f)
        hpState.fill(0f)
        delayLines.forEach { it.fill(0f) }
        delayIndex.fill(0)
    }
}
