package com.example.music.library

import android.app.Activity
import android.app.RecoverableSecurityException
import android.content.ContentUris
import android.content.ContentValues
import android.content.IntentSender
import android.net.Uri
import android.provider.MediaStore
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result

private const val TAG = "SongsChannel"
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
 *
 * Logs every step at Debug level (filter logcat on tag "SongsChannel") -
 * renaming media that this app doesn't own is exactly the kind of thing
 * that behaves differently across OEM MediaProvider implementations, and a
 * silent "it didn't work" is much easier to diagnose with a trail than by
 * guessing.
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
                    Log.d(TAG, "renameSong called: songId=$songId newTitle=\"$newTitle\"")
                    if (songId == null || newTitle.isNullOrEmpty()) {
                        Log.w(TAG, "renameSong BAD_ARGS")
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
        val currentName = queryColumn(uri, MediaStore.Audio.Media.DISPLAY_NAME)
        val ext = currentName?.substringAfterLast('.', "") ?: ""
        val newDisplayName = if (ext.isNotEmpty()) "$newTitle.$ext" else newTitle

        Log.d(
            TAG,
            "performRename uri=$uri currentDisplayName=\"$currentName\" " +
                "-> newDisplayName=\"$newDisplayName\", newTitle=\"$newTitle\"",
        )

        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, newDisplayName)
            put(MediaStore.Audio.Media.TITLE, newTitle)
        }

        try {
            val rows = activity.contentResolver.update(uri, values, null, null)
            Log.d(TAG, "contentResolver.update rows=$rows")
            if (rows <= 0) {
                // No exception, but nothing matched/changed - some OEM
                // MediaProvider builds do this instead of throwing when a
                // write is silently refused.
                Log.w(TAG, "update() reported 0 rows changed - treating as failure")
                result.success(false)
                return
            }

            // Some OEM MediaProvider builds re-extract metadata from the file
            // right after a DISPLAY_NAME change (effectively an implicit
            // rescan), which can silently overwrite the TITLE we just set
            // with whatever tag is actually embedded in the file. Verify,
            // and if it got reverted, force it back once more.
            val verifiedTitle = queryColumn(uri, MediaStore.Audio.Media.TITLE)
            Log.d(TAG, "verify: title is now \"$verifiedTitle\" (wanted \"$newTitle\")")
            if (verifiedTitle != newTitle) {
                Log.w(TAG, "title reverted after update - retrying TITLE-only write")
                val retryRows = activity.contentResolver.update(
                    uri,
                    ContentValues().apply { put(MediaStore.Audio.Media.TITLE, newTitle) },
                    null,
                    null,
                )
                Log.d(
                    TAG,
                    "retry rows=$retryRows, title now \"${queryColumn(uri, MediaStore.Audio.Media.TITLE)}\"",
                )
            }
            result.success(true)
        } catch (recoverable: RecoverableSecurityException) {
            Log.d(TAG, "RecoverableSecurityException - requesting user consent")
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
                Log.e(TAG, "startIntentSenderForResult failed", sendFailed)
                clearPending()
                result.success(false)
            }
        } catch (error: Exception) {
            Log.e(TAG, "renameSong failed", error)
            result.error("RENAME_FAILED", error.message, null)
        }
    }

    private fun queryColumn(uri: Uri, column: String): String? {
        return try {
            activity.contentResolver.query(uri, arrayOf(column), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }
        } catch (error: Exception) {
            Log.e(TAG, "queryColumn($column) failed", error)
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
            Log.w(TAG, "onActivityResult with no pending rename - ignoring")
            return
        }
        Log.d(TAG, "onActivityResult resultCode=$resultCode (RESULT_OK=${Activity.RESULT_OK})")
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
