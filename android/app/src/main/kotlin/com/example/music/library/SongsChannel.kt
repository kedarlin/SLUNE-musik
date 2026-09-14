package com.example.music.library

import android.app.Activity
import android.app.RecoverableSecurityException
import android.content.ContentUris
import android.content.ContentValues
import android.content.IntentSender
import android.net.Uri
import android.provider.MediaStore
import android.util.Log
import com.mpatric.mp3agic.ID3v24Tag
import com.mpatric.mp3agic.Mp3File
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File

private const val TAG = "SongsChannel"
private const val METHOD_CHANNEL = "muxic/songs"
private const val RENAME_REQUEST_CODE = 4301

/**
 * Renames a song: the MediaStore row (DISPLAY_NAME/TITLE) and, for MP3s,
 * the file's own embedded ID3 title tag.
 *
 * The tag rewrite matters more than it sounds like it should. Confirmed
 * on-device via logcat: on Android Q+, MediaProvider re-derives the
 * MediaStore TITLE column from the file's actual embedded tag whenever the
 * file is touched (e.g. by the DISPLAY_NAME change this same rename makes) -
 * a plain ContentResolver.update() of TITLE alone "succeeds" (no exception,
 * rows > 0) and then gets silently reverted right back to whatever was
 * already embedded in the file, because MediaProvider treats that as the
 * canonical source of truth for a file this app doesn't own. So for any
 * file that already carries a tag (most of them), the only way to actually
 * change what a music player displays is to rewrite the tag itself.
 *
 * Every song in the library is media this app didn't create, so on
 * Android 10+ (scoped storage) modifying it throws a
 * RecoverableSecurityException carrying a one-time user-consent IntentSender
 * - there is no way around showing that system dialog. This class starts
 * that IntentSender and holds the pending MethodChannel [Result] until
 * MainActivity forwards the activity result back via [onActivityResult],
 * then retries the same rename (which succeeds once consent is granted).
 *
 * Logs every step at Debug level (filter logcat on tag "SongsChannel").
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
        val rawExt = currentName?.substringAfterLast('.', "") ?: ""
        val newDisplayName = if (rawExt.isNotEmpty()) "$newTitle.$rawExt" else newTitle
        val isMp3 = rawExt.equals("mp3", ignoreCase = true)

        Log.d(
            TAG,
            "performRename uri=$uri currentDisplayName=\"$currentName\" isMp3=$isMp3 " +
                "-> newDisplayName=\"$newDisplayName\", newTitle=\"$newTitle\"",
        )

        try {
            val rows = activity.contentResolver.update(
                uri,
                ContentValues().apply {
                    put(MediaStore.Audio.Media.DISPLAY_NAME, newDisplayName)
                    put(MediaStore.Audio.Media.TITLE, newTitle)
                },
                null,
                null,
            )
            Log.d(TAG, "contentResolver.update rows=$rows")
            if (rows <= 0) {
                Log.w(TAG, "update() reported 0 rows changed - treating as failure")
                result.success(false)
                return
            }

            if (isMp3) {
                val tagWritten = rewriteMp3Title(uri, newTitle)
                Log.d(TAG, "rewriteMp3Title -> $tagWritten")
                if (tagWritten) {
                    // The file's own tag now matches, so this no longer fights
                    // MediaProvider's own metadata re-extraction.
                    activity.contentResolver.update(
                        uri,
                        ContentValues().apply { put(MediaStore.Audio.Media.TITLE, newTitle) },
                        null,
                        null,
                    )
                }
            }

            Log.d(TAG, "verify: title is now \"${queryColumn(uri, MediaStore.Audio.Media.TITLE)}\"")
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

    /**
     * Rewrites the MP3's own embedded ID3v2 title frame via mp3agic.
     *
     * mp3agic only works against real files on disk (no stream/URI
     * constructor), so this copies the content URI's bytes to a temp file in
     * the cache dir, edits that, then streams the result back through the
     * same content URI - keeping the existing MediaStore row/URI identity
     * intact rather than creating a new one. "wt" (truncate) matters: the
     * rewritten file is rarely the exact same byte length as the original.
     *
     * Lets SecurityException (including RecoverableSecurityException)
     * propagate to the caller's consent-request handling rather than
     * swallowing it here - only genuine tag/IO failures return false.
     */
    private fun rewriteMp3Title(uri: Uri, newTitle: String): Boolean {
        val stamp = System.currentTimeMillis()
        val inputTemp = File(activity.cacheDir, "rename_in_$stamp.mp3")
        val outputTemp = File(activity.cacheDir, "rename_out_$stamp.mp3")
        try {
            val opened = activity.contentResolver.openInputStream(uri)?.use { input ->
                inputTemp.outputStream().use { output -> input.copyTo(output) }
                true
            } ?: false
            if (!opened) {
                Log.w(TAG, "rewriteMp3Title: could not open input stream for $uri")
                return false
            }

            val mp3 = Mp3File(inputTemp.absolutePath)
            val tag = mp3.id3v2Tag ?: ID3v24Tag().also { mp3.id3v2Tag = it }
            tag.title = newTitle
            mp3.save(outputTemp.absolutePath)

            val written = activity.contentResolver.openOutputStream(uri, "wt")?.use { output ->
                outputTemp.inputStream().use { input -> input.copyTo(output) }
                true
            } ?: false
            if (!written) {
                Log.w(TAG, "rewriteMp3Title: could not open output stream for $uri")
                return false
            }
            return true
        } catch (security: SecurityException) {
            throw security
        } catch (error: Exception) {
            Log.e(TAG, "rewriteMp3Title failed", error)
            return false
        } finally {
            inputTemp.delete()
            outputTemp.delete()
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
