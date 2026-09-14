package com.example.music.playback

import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.PresetReverb
import android.media.audiofx.Virtualizer
import android.os.Bundle
import android.util.Log
import androidx.media3.common.C

private const val TAG = "AudioEffects"

/**
 * Owns the android.media.audiofx effects - Equalizer, BassBoost, Virtualizer
 * and PresetReverb - and keeps them attached to whatever AudioTrack session
 * id ExoPlayer is currently using.
 *
 * Deliberately modular: the Dart side only ever sends primitive intents
 * ("reverb preset 3", "eq band 2 = -400 mB", "bass boost 600"). How each is
 * realised lives entirely here, so the realisation can change (e.g. reverb
 * moving to a custom DSP node if an OEM's audiofx stack rejects PresetReverb)
 * with no Dart change.
 *
 * Every effect call is wrapped: an OEM that doesn't provide a given effect
 * just leaves that control inert rather than crashing playback.
 */
class AudioEffectsController {

    private var sessionId: Int = C.AUDIO_SESSION_ID_UNSET

    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var reverb: PresetReverb? = null

    // --- Desired state: authoritative, re-applied every time effects rebuild
    //     (which happens whenever the audio session id changes). ---
    private var eqEnabled = false
    private var eqPreset: Int = PRESET_CUSTOM
    private val eqBands = HashMap<Short, Short>() // band index -> level (millibels)
    private var bassStrength = 0 // 0..1000
    private var virtStrength = 0 // 0..1000
    private var reverbPreset: Short = PresetReverb.PRESET_NONE

    fun onSessionId(id: Int) {
        if (id == C.AUDIO_SESSION_ID_UNSET || id == sessionId) {
            return
        }
        sessionId = id
        rebuild()
    }

    /** Retry hook: called again once playback is actually READY, since some
     *  OEM audio stacks won't create effects until the AudioTrack is live. */
    fun reattachIfNeeded(id: Int) {
        if (id == C.AUDIO_SESSION_ID_UNSET) {
            return
        }
        if (id != sessionId || equalizer == null && bassBoost == null &&
            virtualizer == null && reverb == null
        ) {
            sessionId = id
            rebuild()
        }
    }

    private fun rebuild() {
        releaseEffects()
        val id = sessionId
        if (id == C.AUDIO_SESSION_ID_UNSET) {
            return
        }

        equalizer = tryCreate("Equalizer") { Equalizer(EFFECT_PRIORITY, id) }
        bassBoost = tryCreate("BassBoost") { BassBoost(EFFECT_PRIORITY, id) }
        virtualizer = tryCreate("Virtualizer") { Virtualizer(EFFECT_PRIORITY, id) }
        reverb = tryCreate("PresetReverb") { PresetReverb(EFFECT_PRIORITY, id) }

        applyAll()
    }

    private inline fun <T> tryCreate(name: String, create: () -> T): T? =
        try {
            create()
        } catch (error: Exception) {
            Log.w(TAG, "$name not available on this device: ${error.message}")
            null
        }

    private inline fun guarded(block: () -> Unit) {
        try {
            block()
        } catch (error: Exception) {
            Log.w(TAG, "effect apply failed: ${error.message}")
        }
    }

    private fun applyAll() {
        equalizer?.let { eq ->
            guarded {
                if (eqPreset in 0 until eq.numberOfPresets) {
                    eq.usePreset(eqPreset.toShort())
                } else {
                    for ((band, level) in eqBands) {
                        if (band < eq.numberOfBands) {
                            eq.setBandLevel(band, level)
                        }
                    }
                }
                eq.enabled = eqEnabled
            }
        }
        bassBoost?.let { bb ->
            guarded {
                bb.setStrength(bassStrength.toShort())
                bb.enabled = bassStrength > 0
            }
        }
        virtualizer?.let { v ->
            guarded {
                v.setStrength(virtStrength.toShort())
                v.enabled = virtStrength > 0
            }
        }
        reverb?.let { rv ->
            guarded {
                rv.preset = reverbPreset
                rv.enabled = reverbPreset != PresetReverb.PRESET_NONE
            }
        }
    }

    // --- Intents from Dart -------------------------------------------------

    fun setEqEnabled(enabled: Boolean) {
        eqEnabled = enabled
        equalizer?.let { eq -> guarded { eq.enabled = enabled } }
    }

    /** Applies a device preset and returns the resulting per-band curve
     *  (millibels) so the UI sliders can follow it. Empty if unavailable. */
    fun setEqPreset(preset: Int): IntArray {
        eqPreset = preset
        eqBands.clear()
        val eq = equalizer ?: return IntArray(0)
        return try {
            if (preset in 0 until eq.numberOfPresets) {
                eq.usePreset(preset.toShort())
                eq.enabled = eqEnabled
            }
            IntArray(eq.numberOfBands.toInt()) { eq.getBandLevel(it.toShort()).toInt() }
        } catch (error: Exception) {
            Log.w(TAG, "eq preset failed: ${error.message}")
            IntArray(0)
        }
    }

    fun setEqBand(band: Int, levelMb: Int) {
        eqPreset = PRESET_CUSTOM
        eqBands[band.toShort()] = levelMb.toShort()
        val eq = equalizer ?: return
        guarded {
            if (band < eq.numberOfBands) {
                eq.setBandLevel(band.toShort(), levelMb.toShort())
                eq.enabled = eqEnabled
            }
        }
    }

    fun setBassBoost(strength: Int) {
        bassStrength = strength.coerceIn(0, 1000)
        bassBoost?.let { bb ->
            guarded {
                bb.setStrength(bassStrength.toShort())
                bb.enabled = bassStrength > 0
            }
        }
    }

    fun setVirtualizer(strength: Int) {
        virtStrength = strength.coerceIn(0, 1000)
        virtualizer?.let { v ->
            guarded {
                v.setStrength(virtStrength.toShort())
                v.enabled = virtStrength > 0
            }
        }
    }

    fun setReverb(preset: Int) {
        reverbPreset = preset.coerceIn(0, MAX_REVERB_PRESET).toShort()
        reverb?.let { rv ->
            guarded {
                rv.preset = reverbPreset
                rv.enabled = reverbPreset != PresetReverb.PRESET_NONE
            }
        }
    }

    /** Snapshot of what the current device supports, for the UI to render. */
    fun capabilities(): Bundle {
        val out = Bundle()

        val eq = equalizer
        var eqOk = false
        if (eq != null) {
            try {
                val bandCount = eq.numberOfBands.toInt()
                val freqs = IntArray(bandCount) { eq.getCenterFreq(it.toShort()) }
                val range = eq.bandLevelRange
                val presetNames = Array(eq.numberOfPresets.toInt()) {
                    eq.getPresetName(it.toShort())
                }
                out.putInt("bandCount", bandCount)
                out.putIntArray("centerFreqsMilliHz", freqs)
                out.putInt("minLevelMb", range[0].toInt())
                out.putInt("maxLevelMb", range[1].toInt())
                out.putStringArray("presetNames", presetNames)
                eqOk = true
            } catch (error: Exception) {
                Log.w(TAG, "eq caps query failed: ${error.message}")
            }
        }

        out.putBoolean("eqAvailable", eqOk)
        out.putBoolean(
            "bassBoostAvailable",
            runCatching { bassBoost?.strengthSupported == true }.getOrDefault(false),
        )
        out.putBoolean(
            "virtualizerAvailable",
            runCatching { virtualizer?.strengthSupported == true }.getOrDefault(false),
        )
        out.putBoolean("reverbAvailable", reverb != null)
        return out
    }

    fun release() {
        releaseEffects()
        sessionId = C.AUDIO_SESSION_ID_UNSET
    }

    private fun releaseEffects() {
        runCatching { equalizer?.release() }
        runCatching { bassBoost?.release() }
        runCatching { virtualizer?.release() }
        runCatching { reverb?.release() }
        equalizer = null
        bassBoost = null
        virtualizer = null
        reverb = null
    }

    companion object {
        const val PRESET_CUSTOM = -1
        private const val EFFECT_PRIORITY = 0
        private const val MAX_REVERB_PRESET = 6 // PresetReverb.PRESET_PLATE
    }
}
