package com.example.music.lyrics

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.exp

private const val TARGET_SAMPLE_RATE = 16000
private const val DEQUEUE_TIMEOUT_US = 10_000L

// Vocal-emphasis band: roughly covers fundamental pitch + first formants for
// both male and female voices, while cutting sub-bass (kick/bass fundamental)
// and cymbal/hi-hat sizzle above typical vocal presence. This is a cheap DSP
// nudge, not real source separation - sherpa-onnx does not ship a music
// vocal-isolation model (only a speech *denoiser*, a different task trained
// for background noise, not instrumentation). Real separation (Spleeter/UVR)
// would need its own ONNX model and is tracked as a possible future addition,
// not something to fake here.
private const val VOCAL_HIGH_PASS_HZ = 150.0
private const val VOCAL_LOW_PASS_HZ = 5000.0

/**
 * Cooperative cancellation for a single [LyricsAudioDecoder.decodeToWav]
 * call. A plain flag rather than e.g. Thread.interrupt() so one decode job
 * can be stopped without any risk of affecting a different, concurrently
 * running one (interactive generation and generate-ahead can each have a
 * decode in flight against the same shared [LyricsAudioDecoder] instance).
 */
class DecodeCancellationToken {
    @Volatile
    var cancelled: Boolean = false
}

/** Thrown to unwind [LyricsAudioDecoder.decodeToWav] when its token is cancelled. */
class DecodeCancelledException : Exception("decode cancelled")

/**
 * Decodes an arbitrary audio file (whatever MediaCodec/MediaExtractor support
 * on-device - mp3/aac/flac/opus/vorbis/wav) to a 16 kHz mono 16-bit PCM WAV
 * file, the input format the lyrics ASR pipeline (sherpa-onnx Whisper) wants.
 *
 * Runs on whatever thread calls it - the caller (LyricsChannel) is
 * responsible for keeping this off the platform channel's main thread.
 */
class LyricsAudioDecoder {

    /**
     * Returns the duration of the decoded audio in milliseconds.
     *
     * When [enhanceVocals] is set, a vocal-frequency bandpass is applied to
     * the downmixed mono signal before resampling - a cheap SNR nudge for the
     * ASR pass, not a substitute for real vocal separation.
     *
     * [cancellationToken], when given, is checked once per decode loop
     * iteration (every ~10-20ms) so switching songs mid-decode stops the
     * MediaCodec/MediaExtractor work promptly instead of burning CPU/battery
     * decoding a file nobody wants transcribed any more.
     */
    fun decodeToWav(
        sourcePath: String,
        outputPath: String,
        enhanceVocals: Boolean = true,
        cancellationToken: DecodeCancellationToken? = null,
    ): Long {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null

        try {
            extractor.setDataSource(sourcePath)

            var trackIndex = -1
            var format: MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val candidate = extractor.getTrackFormat(i)
                val mime = candidate.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("audio/")) {
                    trackIndex = i
                    format = candidate
                    break
                }
            }
            if (trackIndex < 0 || format == null) {
                throw IOException("No audio track found in $sourcePath")
            }
            extractor.selectTrack(trackIndex)

            var sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channelCount = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)

            val mime = format.getString(MediaFormat.KEY_MIME)!!
            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            // Mono PCM16 at the source's native sample rate - resampled to
            // 16 kHz in a single pass once decoding is complete.
            val monoOut = ByteArrayOutputStream()

            val bufferInfo = MediaCodec.BufferInfo()
            var sawInputEos = false
            var sawOutputEos = false

            while (!sawOutputEos) {
                if (cancellationToken?.cancelled == true) {
                    throw DecodeCancelledException()
                }
                if (!sawInputEos) {
                    val inIndex = codec.dequeueInputBuffer(DEQUEUE_TIMEOUT_US)
                    if (inIndex >= 0) {
                        val inBuffer = codec.getInputBuffer(inIndex)!!
                        val sampleSize = extractor.readSampleData(inBuffer, 0)
                        if (sampleSize < 0) {
                            codec.queueInputBuffer(
                                inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM
                            )
                            sawInputEos = true
                        } else {
                            codec.queueInputBuffer(
                                inIndex, 0, sampleSize, extractor.sampleTime, 0
                            )
                            extractor.advance()
                        }
                    }
                }

                val outIndex = codec.dequeueOutputBuffer(bufferInfo, DEQUEUE_TIMEOUT_US)
                if (outIndex >= 0) {
                    if (bufferInfo.size > 0) {
                        val outBuffer = codec.getOutputBuffer(outIndex)!!
                        outBuffer.position(bufferInfo.offset)
                        outBuffer.limit(bufferInfo.offset + bufferInfo.size)
                        val chunk = ByteArray(bufferInfo.size)
                        outBuffer.get(chunk)
                        monoOut.write(toMonoPcm16Bytes(chunk, channelCount))
                    }
                    codec.releaseOutputBuffer(outIndex, false)
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        sawOutputEos = true
                    }
                } else if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    // The decoder's actual output format can differ from the
                    // extractor's declared input format - trust this one.
                    val actual = codec.outputFormat
                    sampleRate = actual.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    channelCount = actual.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                }
                // INFO_TRY_AGAIN_LATER: just loop again.
            }

            val monoBytes = monoOut.toByteArray()
            var monoPcm16 = bytesToShorts(monoBytes)
            if (enhanceVocals) {
                monoPcm16 = applyVocalBandpass(monoPcm16, sampleRate)
            }
            val resampled = resampleLinear(monoPcm16, sampleRate, TARGET_SAMPLE_RATE)

            writeWav(outputPath, resampled, TARGET_SAMPLE_RATE)

            return (resampled.size.toLong() * 1000L) / TARGET_SAMPLE_RATE
        } finally {
            try {
                codec?.stop()
            } catch (_: Exception) {
                // Already stopped/never started past configure - not fatal.
            }
            codec?.release()
            extractor.release()
        }
    }

    /** Downmixes interleaved little-endian PCM16 [chunk] with [channelCount]
     *  channels to mono, returned as little-endian PCM16 bytes. */
    private fun toMonoPcm16Bytes(chunk: ByteArray, channelCount: Int): ByteArray {
        if (channelCount <= 1) {
            return chunk
        }

        val input = ByteBuffer.wrap(chunk).order(ByteOrder.LITTLE_ENDIAN)
        val totalSamples = chunk.size / 2
        val frameCount = totalSamples / channelCount
        val output = ByteBuffer.allocate(frameCount * 2).order(ByteOrder.LITTLE_ENDIAN)

        for (frame in 0 until frameCount) {
            var sum = 0
            for (ch in 0 until channelCount) {
                sum += input.short.toInt()
            }
            output.putShort((sum / channelCount).toShort())
        }
        return output.array()
    }

    /**
     * One-pole high-pass (implemented as input minus its own tracked
     * low-pass) followed by a one-pole low-pass, both exponential - the same
     * simple, well-understood filter shape used elsewhere in this app's audio
     * code. Cuts sub-bass and cymbal/hi-hat energy, leaving the vocal
     * fundamental + formant range relatively louder for the ASR pass.
     */
    private fun applyVocalBandpass(input: ShortArray, sampleRate: Int): ShortArray {
        if (input.isEmpty()) {
            return input
        }

        val hpCoeff = oneMinusExpCoefficient(VOCAL_HIGH_PASS_HZ, sampleRate)
        val lpCoeff = oneMinusExpCoefficient(VOCAL_LOW_PASS_HZ, sampleRate)

        val output = ShortArray(input.size)
        var hpTracker = 0.0
        var lpState = 0.0

        for (i in input.indices) {
            val x = input[i].toDouble()

            hpTracker += hpCoeff * (x - hpTracker)
            val afterHighPass = x - hpTracker

            lpState += lpCoeff * (afterHighPass - lpState)

            output[i] = lpState.toInt().coerceIn(-32768, 32767).toShort()
        }
        return output
    }

    private fun oneMinusExpCoefficient(cutoffHz: Double, sampleRate: Int): Double =
        1.0 - exp(-2.0 * PI * cutoffHz / sampleRate)

    private fun bytesToShorts(bytes: ByteArray): ShortArray {
        val buffer = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        val shorts = ShortArray(bytes.size / 2)
        for (i in shorts.indices) {
            shorts[i] = buffer.short
        }
        return shorts
    }

    /** Simple linear-interpolation resampler. Not audiophile grade, but ASR
     *  models are tolerant of it and it needs no extra native dependency. */
    private fun resampleLinear(input: ShortArray, fromRate: Int, toRate: Int): ShortArray {
        if (fromRate == toRate || input.isEmpty()) {
            return input
        }

        val ratio = fromRate.toDouble() / toRate.toDouble()
        val outLength = (input.size / ratio).toInt().coerceAtLeast(0)
        val output = ShortArray(outLength)

        for (i in 0 until outLength) {
            val srcPos = i * ratio
            val srcIndex = srcPos.toInt()
            val frac = srcPos - srcIndex
            val s0 = input[srcIndex]
            val s1 = if (srcIndex + 1 < input.size) input[srcIndex + 1] else s0
            output[i] = (s0 + (s1 - s0) * frac).toInt().toShort()
        }
        return output
    }

    private fun writeWav(path: String, pcm16: ShortArray, sampleRate: Int) {
        val dataSize = pcm16.size * 2
        val byteRate = sampleRate * 2 // mono, 16-bit

        File(path).outputStream().use { out ->
            val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
            header.put("RIFF".toByteArray(Charsets.US_ASCII))
            header.putInt(36 + dataSize)
            header.put("WAVE".toByteArray(Charsets.US_ASCII))
            header.put("fmt ".toByteArray(Charsets.US_ASCII))
            header.putInt(16)
            header.putShort(1.toShort()) // PCM
            header.putShort(1.toShort()) // mono
            header.putInt(sampleRate)
            header.putInt(byteRate)
            header.putShort(2.toShort()) // block align
            header.putShort(16.toShort()) // bits per sample
            header.put("data".toByteArray(Charsets.US_ASCII))
            header.putInt(dataSize)
            out.write(header.array())

            val body = ByteBuffer.allocate(dataSize).order(ByteOrder.LITTLE_ENDIAN)
            body.asShortBuffer().put(pcm16)
            out.write(body.array())
        }
    }
}
