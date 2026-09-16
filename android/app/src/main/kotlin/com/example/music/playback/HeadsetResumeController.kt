package com.example.music.playback

import android.content.Context
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.util.Log
import androidx.media3.exoplayer.ExoPlayer

private const val TAG = "HeadsetResumeController"

private val WIRED_TYPES = setOf(
    AudioDeviceInfo.TYPE_WIRED_HEADSET,
    AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
)

private val BLUETOOTH_TYPES = setOf(
    AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
    AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
)

/**
 * Tracks whether playback was just paused because its output device
 * disappeared (headphones unplugged / Bluetooth disconnected - see
 * PlaybackService's own ACTION_AUDIO_BECOMING_NOISY receiver, which sets
 * [pausedDueToNoisyDisconnect]), and resumes it when a new output device
 * reappears - never a track the user deliberately paused themselves, since
 * that never sets the flag in the first place.
 *
 * Wired reinsertion resumes by default; Bluetooth reconnect only resumes
 * when [resumeOnBluetoothEnabled] is explicitly turned on - the common "car
 * radio blasts music the instant it pairs" complaint most players don't
 * address.
 */
class HeadsetResumeController(context: Context, private val player: ExoPlayer) {

    private val audioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    var resumeOnBluetoothEnabled: Boolean = false

    var pausedDueToNoisyDisconnect: Boolean = false

    private val deviceCallback = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) {
            if (!pausedDueToNoisyDisconnect) return

            val hasWired = addedDevices.any { it.type in WIRED_TYPES }
            val hasBluetooth = addedDevices.any { it.type in BLUETOOTH_TYPES }

            if (hasWired || (hasBluetooth && resumeOnBluetoothEnabled)) {
                pausedDueToNoisyDisconnect = false
                try {
                    player.play()
                } catch (error: Exception) {
                    Log.w(TAG, "resume-on-reconnect failed", error)
                }
            }
        }
    }

    fun register() {
        try {
            audioManager.registerAudioDeviceCallback(deviceCallback, null)
        } catch (error: Exception) {
            Log.w(TAG, "registerAudioDeviceCallback failed", error)
        }
    }

    fun unregister() {
        try {
            audioManager.unregisterAudioDeviceCallback(deviceCallback)
        } catch (error: Exception) {
            Log.w(TAG, "unregisterAudioDeviceCallback failed", error)
        }
    }
}
