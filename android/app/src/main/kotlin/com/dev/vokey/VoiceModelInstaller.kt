package com.dev.vokey

import android.content.Context
import java.io.BufferedInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.zip.ZipInputStream

internal object VoiceModelInstaller {
    const val MODEL_DIRECTORY = "vosk-model-small-en-us-0.15"
    private const val MODEL_URL =
        "https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip"
    private const val EXPECTED_SHA256 =
        "30f26242c4eb449f948e42cb302dd7a686cb29a3423a8367f99ff41780942498"
    private const val MAX_ARCHIVE_BYTES = 100L * 1024L * 1024L

    fun modelDirectory(context: Context): File =
        File(File(context.filesDir, "voice_models"), MODEL_DIRECTORY)

    fun isInstalled(context: Context): Boolean {
        val directory = modelDirectory(context)
        return File(directory, "am").isDirectory &&
            File(directory, "conf").isDirectory &&
            File(directory, "graph").isDirectory &&
            File(directory, "am/final.mdl").isFile
    }

    fun install(
        context: Context,
        onProgress: (downloadedBytes: Long, totalBytes: Long) -> Unit,
    ): File {
        if (isInstalled(context)) return modelDirectory(context)

        val root = File(context.filesDir, "voice_models")
        if (!root.exists() && !root.mkdirs()) {
            throw IllegalStateException("Could not create the private voice-model directory.")
        }

        val archive = File(root, "model_download.zip.part")
        val staging = File(root, "model_staging")
        val connection = URL(MODEL_URL).openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = 20_000
            connection.readTimeout = 45_000
            connection.instanceFollowRedirects = true
            connection.setRequestProperty("User-Agent", "Vokey-Android")
            connection.connect()

            val code = connection.responseCode
            if (code !in 200..299) {
                throw IllegalStateException("Model download failed (HTTP $code).")
            }

            val contentLength = connection.contentLengthLong
            if (contentLength > MAX_ARCHIVE_BYTES) {
                throw IllegalStateException("The model archive is larger than the allowed download size.")
            }

            BufferedInputStream(connection.inputStream).use { input ->
                FileOutputStream(archive).use { output ->
                    val buffer = ByteArray(32 * 1024)
                    var downloaded = 0L
                    var count: Int
                    while (input.read(buffer).also { count = it } != -1) {
                        downloaded += count
                        if (downloaded > MAX_ARCHIVE_BYTES) {
                            throw IllegalStateException("The model archive exceeded the allowed download size.")
                        }
                        output.write(buffer, 0, count)
                        onProgress(downloaded, contentLength)
                    }
                    output.fd.sync()
                }
            }
        } finally {
            connection.disconnect()
        }

        val checksum = sha256(archive)
        if (!checksum.equals(EXPECTED_SHA256, ignoreCase = true)) {
            archive.delete()
            throw SecurityException("The downloaded speech model failed SHA-256 verification.")
        }

        if (staging.exists()) staging.deleteRecursively()
        if (!staging.mkdirs()) {
            archive.delete()
            throw IllegalStateException("Could not create the model extraction directory.")
        }

        try {
            unzipSafely(archive, staging)
            val extracted = File(staging, MODEL_DIRECTORY)
            if (!File(extracted, "am/final.mdl").isFile ||
                !File(extracted, "conf").isDirectory ||
                !File(extracted, "graph").isDirectory
            ) {
                throw IllegalStateException("The speech model archive is incomplete or has an unexpected structure.")
            }

            val destination = modelDirectory(context)
            if (destination.exists() && !destination.deleteRecursively()) {
                throw IllegalStateException("Could not replace the existing speech model.")
            }
            if (!extracted.renameTo(destination)) {
                copyDirectory(extracted, destination)
            }
            if (!isInstalled(context)) {
                throw IllegalStateException("The installed speech model failed validation.")
            }
            return destination
        } finally {
            archive.delete()
            staging.deleteRecursively()
        }
    }

    private fun unzipSafely(archive: File, destination: File) {
        val rootPath = destination.canonicalPath + File.separator
        ZipInputStream(BufferedInputStream(FileInputStream(archive))).use { zip ->
            val buffer = ByteArray(32 * 1024)
            while (true) {
                val entry = zip.nextEntry ?: break
                val outputFile = File(destination, entry.name)
                val canonical = outputFile.canonicalPath
                if (!canonical.startsWith(rootPath)) {
                    throw SecurityException("The speech model archive contains an unsafe path.")
                }
                if (entry.isDirectory) {
                    if (!outputFile.exists() && !outputFile.mkdirs()) {
                        throw IllegalStateException("Could not extract a model directory.")
                    }
                } else {
                    outputFile.parentFile?.let {
                        if (!it.exists() && !it.mkdirs()) {
                            throw IllegalStateException("Could not create a model folder.")
                        }
                    }
                    FileOutputStream(outputFile).use { output ->
                        var count: Int
                        while (zip.read(buffer).also { count = it } != -1) {
                            output.write(buffer, 0, count)
                        }
                    }
                }
                zip.closeEntry()
            }
        }
    }

    private fun copyDirectory(source: File, destination: File) {
        if (source.isDirectory) {
            if (!destination.exists() && !destination.mkdirs()) {
                throw IllegalStateException("Could not create the installed model folder.")
            }
            source.listFiles()?.forEach { child ->
                copyDirectory(child, File(destination, child.name))
            }
        } else {
            source.copyTo(destination, overwrite = true)
        }
    }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        FileInputStream(file).use { input ->
            val buffer = ByteArray(32 * 1024)
            var count: Int
            while (input.read(buffer).also { count = it } != -1) {
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
}
