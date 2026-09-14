package com.example.music.library

import android.app.Activity
import android.app.RecoverableSecurityException
import android.content.ContentUris
import android.content.ContentValues
import android.content.IntentSender
import android.net.Uri
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result

private const val METHOD_CHANNEL = "muxic/songs"
private const val RENAME_REQUEST_CODE = 4301

/**
 * Renames an audio file's title/display name via MediaStore.
 *
 * Every song in a typical library is media this app didn't create, so on
 * Android 10+ (scoped storage) modifying it throws a
 * RecoverableSecurityException carrying a one-time user-consent IntentSender
 * - there is no way around showing that system dialog. This class starts
 * that IntentSender and holds the pending MethodChannel [Result] until
 * MainActivity forwards the activity result back via [onActivityResult],
 * then retries the same update (which succeeds once consent is granted).
 */
class SongsChannel(private val activity: Activity) {

    private var pendingResult: Result? = null
    private var pendingSongId: Long? = null
    private var pendingNewTitle: String? = null

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "renameSong" -> {
                    val songId = call.argument<Int>("songId")?.toLong()
                    val newTitle = call.argument<String>("newTitle")?.trim()
                    if (songId == null || newTitle.isNullOrEmpty()) {
                        result.error("BAD_ARGS", "songId and newTitle are required", null)
                        return@setMethodCallHandler
                    }
                    performRename(songId, newTitle, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun performRename(songId: Long, newTitle: String, result: Result) {
        val uri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, songId)
        val values = ContentValues().apply {
            // Keep the file's actual extension - only the name portion changes.
            val currentName = currentDisplayName(uri)
            val ext = currentName?.substringAfterLast('.', "") ?: ""
            put(
                MediaStore.Audio.Media.DISPLAY_NAME,
                if (ext.isNotEmpty()) "$newTitle.$ext" else newTitle,
            )
            put(MediaStore.Audio.Media.TITLE, newTitle)
        }

        try {
            val rows = activity.contentResolver.update(uri, values, null, null)
            result.success(rows > 0)
        } catch (recoverable: RecoverableSecurityException) {
            // API 29+ only (RecoverableSecurityException itself requires Q) -
            // ask the user once via the system consent dialog, then retry.
            pendingResult = result
            pendingSongId = songId
            pendingNewTitle = newTitle
            try {
                activity.startIntentSenderForResult(
                    recoverable.userAction.actionIntent.intentSender,
                    RENAME_REQUEST_CODE,
                    null,
                    0,
                    0,
                    0,
                )
            } catch (sendFailed: IntentSender.SendIntentException) {
                clearPending()
                result.success(false)
            }
        } catch (error: Exception) {
            result.error("RENAME_FAILED", error.message, null)
        }
    }

    private fun currentDisplayName(uri: Uri): String? {
        return try {
            activity.contentResolver.query(
                uri,
                arrayOf(MediaStore.Audio.Media.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
        } catch (_: Exception) {
            null
        }
    }

    /** Forwarded from MainActivity.onActivityResult. */
    fun onActivityResult(requestCode: Int, resultCode: Int) {
        if (requestCode != RENAME_REQUEST_CODE) {
            return
        }
        val result = pendingResult
        val songId = pendingSongId
        val newTitle = pendingNewTitle
        clearPending()
        if (result == null || songId == null || newTitle == null) {
            return
        }
        if (resultCode != Activity.RESULT_OK) {
            result.success(false)
            return
        }
        // Consent was just granted for exactly this update - retry it.
        performRename(songId, newTitle, result)
    }

    private fun clearPending() {
        pendingResult = null
        pendingSongId = null
        pendingNewTitle = null
    }
}
