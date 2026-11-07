package com.dev.vokey

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.OpenableColumns
import java.io.File
import java.util.UUID

/**
 * Copies a user-picked audio file (Storage Access Framework) into app-private
 * storage after validating type, size and duration. No broad storage
 * permission is used; the picked URI is read once and not retained.
 */
internal object CustomSoundImporter {
    class ImportException(message: String) : Exception(message)

    /** Runs on a background thread. Returns metadata for Flutter (no audio). */
    fun import(context: Context, uri: Uri): Map<String, Any> {
        val resolver = context.contentResolver
        val mime = resolver.getType(uri)
        var displayName: String? = null
        var declaredSize = -1L
        resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)
            ?.use { c ->
                if (c.moveToFirst()) {
                    displayName = c.getString(0)
                    if (!c.isNull(1)) declaredSize = c.getLong(1)
                }
            }
        if (mime != null && !mime.startsWith("audio/") && mime != "application/ogg") {
            throw ImportException("That file is not an audio file.")
        }
        val ext = CustomSoundFiles.extensionFor(mime, displayName)
            ?: throw ImportException("Unsupported format. Use MP3, M4A/AAC, OGG, OPUS, WAV or FLAC.")
        if (declaredSize > CustomSoundFiles.MAX_BYTES) {
            throw ImportException("The file is larger than 10 MB.")
        }

        val dir = FinderAlertManager.customSoundDir(context).apply { mkdirs() }
        val fileName = "${UUID.randomUUID().toString().replace("-", "")}.$ext"
        val target = File(dir, fileName)
        val temp = File(dir, "$fileName.part")
        try {
            var copied = 0L
            resolver.openInputStream(uri)?.use { input ->
                temp.outputStream().use { output ->
                    val buffer = ByteArray(32 * 1024)
                    while (true) {
                        val n = input.read(buffer)
                        if (n < 0) break
                        copied += n
                        if (copied > CustomSoundFiles.MAX_BYTES) {
                            throw ImportException("The file is larger than 10 MB.")
                        }
                        output.write(buffer, 0, n)
                    }
                }
            } ?: throw ImportException("Android could not open that file.")

            val durationMs = try {
                MediaMetadataRetriever().run {
                    try {
                        setDataSource(temp.absolutePath)
                        extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
                    } finally {
                        release()
                    }
                }
            } catch (_: Exception) {
                0L
            }
            CustomSoundFiles.validate(copied, durationMs)?.let { throw ImportException(it) }
            if (!temp.renameTo(target)) throw ImportException("Could not save the sound.")
            return mapOf(
                "file_name" to fileName,
                "name" to CustomSoundFiles.displayName(displayName),
                "duration_ms" to durationMs,
                "size_bytes" to copied,
            )
        } finally {
            temp.delete()
        }
    }

    fun delete(context: Context, fileName: String?): Boolean {
        if (!CustomSoundFiles.isSafeFileName(fileName)) return false
        return File(FinderAlertManager.customSoundDir(context), fileName!!).delete()
    }

    fun exists(context: Context, fileName: String?): Boolean =
        CustomSoundFiles.isSafeFileName(fileName) &&
            File(FinderAlertManager.customSoundDir(context), fileName!!).isFile
}
