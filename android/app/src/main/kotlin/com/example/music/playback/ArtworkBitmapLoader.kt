package com.example.music.playback

import android.content.ContentResolver
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.util.Log
import android.util.Size
import androidx.media3.common.util.BitmapLoader
import androidx.media3.datasource.DataSourceBitmapLoader
import com.google.common.util.concurrent.ListenableFuture
import com.google.common.util.concurrent.ListeningExecutorService
import com.google.common.util.concurrent.MoreExecutors
import java.io.IOException
import java.util.concurrent.Executors

private const val TAG = "ArtworkBitmapLoader"
private const val ART_SIZE = 512

/**
 * Loads media-notification artwork for local audio files.
 *
 * A lot of sample code (and the previous version of this app) points the
 * artwork URI at content://media/external/audio/albumart/<albumId>, but that
 * provider path was dropped on Android 10+, so the notification silently shows
 * no art even when the file has an embedded cover. This loader instead:
 *   - ContentResolver.loadThumbnail() on the song's MediaStore URI (API 29+),
 *     which covers both embedded covers and folder art MediaStore knows about;
 *   - MediaMetadataRetriever's embedded picture as a fallback (older APIs, or
 *     when loadThumbnail has nothing);
 *   - the default DataSourceBitmapLoader for everything else (http/data URIs,
 *     raw bytes), so remote art still works if it is ever used.
 */
class ArtworkBitmapLoader(context: Context) : BitmapLoader {

    private val appContext: Context = context.applicationContext
    private val executor: ListeningExecutorService =
        MoreExecutors.listeningDecorator(Executors.newSingleThreadExecutor())
    private val delegate = DataSourceBitmapLoader(appContext)

    override fun supportsMimeType(mimeType: String): Boolean =
        delegate.supportsMimeType(mimeType)

    override fun decodeBitmap(data: ByteArray): ListenableFuture<Bitmap> =
        delegate.decodeBitmap(data)

    override fun loadBitmap(uri: Uri): ListenableFuture<Bitmap> {
        if (uri.scheme != ContentResolver.SCHEME_CONTENT) {
            return delegate.loadBitmap(uri)
        }
        return executor.submit<Bitmap> {
            loadLocalArtwork(uri) ?: throw IOException("no artwork for $uri")
        }
    }

    private fun loadLocalArtwork(uri: Uri): Bitmap? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                return appContext.contentResolver.loadThumbnail(uri, Size(ART_SIZE, ART_SIZE), null)
            } catch (error: Exception) {
                // No MediaStore thumbnail - try the embedded picture below.
                Log.d(TAG, "loadThumbnail failed for $uri, trying retriever", error)
            }
        }

        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(appContext, uri)
            retriever.embeddedPicture?.let { bytes ->
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            }
        } catch (error: Exception) {
            Log.d(TAG, "retriever failed for $uri", error)
            null
        } finally {
            retriever.release()
        }
    }
}
