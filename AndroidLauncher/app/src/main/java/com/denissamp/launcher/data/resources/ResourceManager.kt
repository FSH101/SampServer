package com.denissamp.launcher.data.resources

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import com.denissamp.launcher.data.manifest.InstalledIndex
import com.denissamp.launcher.data.manifest.ManifestFile
import com.denissamp.launcher.data.manifest.ManifestPayload
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request
import okio.buffer
import okio.sink
import timber.log.Timber
import java.io.File
import java.security.MessageDigest
import java.util.zip.ZipInputStream

class ResourceManager(
    private val context: Context,
    private val contentResolver: ContentResolver,
    private val client: OkHttpClient,
    private val json: Json
) {
    private val indexFile: File = File(context.filesDir, "installed.json")
    private val messageDigest = MessageDigest.getInstance("SHA-256")

    private val _progress = MutableStateFlow<ResourceSyncProgress>(ResourceSyncProgress.Idle)
    val progress: StateFlow<ResourceSyncProgress> = _progress

    suspend fun loadIndex(): InstalledIndex? = withContext(Dispatchers.IO) {
        if (!indexFile.exists()) return@withContext null
        runCatching { json.decodeFromString(InstalledIndex.serializer(), indexFile.readText()) }
            .onFailure { Timber.w(it, "Failed to parse installed index") }
            .getOrNull()
    }

    suspend fun syncResources(
        rootUri: Uri,
        manifest: ManifestPayload,
        force: Boolean
    ): ResourceSyncResult = withContext(Dispatchers.IO) {
        _progress.emit(ResourceSyncProgress.Running(fileIndex = 0, fileCount = manifest.files.size))
        val documentRoot = DocumentFile.fromTreeUri(context, rootUri)
            ?: return@withContext ResourceSyncResult.PermissionMissing

        val installedIndex = if (!force) loadIndex() else null
        val hashes = installedIndex?.files?.toMutableMap() ?: mutableMapOf()
        var processed = 0
        for (file in manifest.files) {
            processed += 1
            _progress.emit(ResourceSyncProgress.Running(processed, manifest.files.size))
            val shouldDownload = installedIndex?.files?.get(file.dest)?.equals(file.sha256, ignoreCase = true) != true
            if (shouldDownload || force) {
                Timber.i("Downloading ${file.url}")
                downloadAndInstall(documentRoot, file)
                hashes[file.dest] = file.sha256
            } else {
                hashes.putIfAbsent(file.dest, file.sha256)
            }
        }
        saveIndex(manifest.version, hashes)
        _progress.emit(ResourceSyncProgress.Success)
        ResourceSyncResult.Success
    }

    private fun saveIndex(version: String, files: Map<String, String>) {
        val payload = InstalledIndex(version = version, files = files)
        indexFile.writeText(json.encodeToString(InstalledIndex.serializer(), payload))
    }

    private fun downloadAndInstall(root: DocumentFile, file: ManifestFile) {
        val tempFile = File(context.cacheDir, "${file.sha256}.tmp")
        val request = Request.Builder().url(file.url).get().build()
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) error("Failed to download ${file.url}")
            val sink = tempFile.sink().buffer()
            response.body?.source()?.use { source ->
                sink.use { it.writeAll(source) }
            } ?: error("Empty body")
        }

        val downloadedHash = sha256(tempFile)
        if (!downloadedHash.equals(file.sha256, ignoreCase = true)) {
            tempFile.delete()
            error("Hash mismatch for ${file.dest}")
        }

        if (file.type == ManifestFile.FileType.ZIP) {
            unzipInto(root, file, tempFile)
        } else {
            writeFile(root, file.dest, tempFile)
        }
        tempFile.delete()
    }

    private fun writeFile(root: DocumentFile, dest: String, source: File) {
        val parts = dest.split('/')
        var current = root
        for (i in 0 until parts.lastIndex) {
            val name = parts[i]
            current = current.findFile(name) ?: current.createDirectory(name)
                ?: throw IllegalStateException("Failed to create directory $name")
        }
        val fileName = parts.last()
        current.findFile(fileName)?.delete()
        val created = current.createFile("application/octet-stream", fileName)
            ?: throw IllegalStateException("Failed to create file $fileName")
        contentResolver.openOutputStream(created.uri)?.use { output ->
            source.inputStream().use { input ->
                input.copyTo(output)
            }
        } ?: throw IllegalStateException("Unable to open output stream for $fileName")
    }

    private fun unzipInto(root: DocumentFile, file: ManifestFile, source: File) {
        val destRoot = file.unpackTo?.let { ensurePath(root, it) } ?: root
        ZipInputStream(source.inputStream()).use { zip ->
            while (true) {
                val entry = zip.nextEntry ?: break
                if (entry.isDirectory) {
                    ensurePath(destRoot, entry.name)
                } else {
                    val parentPath = entry.name.substringBeforeLast('/', "")
                    val parent = if (parentPath.isEmpty()) destRoot else ensurePath(destRoot, parentPath)
                    val fileName = entry.name.substringAfterLast('/')
                    parent.findFile(fileName)?.delete()
                    val created = parent.createFile("application/octet-stream", fileName)
                        ?: throw IllegalStateException("Failed to create zip entry ${entry.name}")
                    contentResolver.openOutputStream(created.uri)?.use { output ->
                        zip.copyTo(output)
                    }
                }
                zip.closeEntry()
            }
        }
    }

    private fun ensurePath(root: DocumentFile, path: String): DocumentFile {
        val parts = path.split('/').filter { it.isNotBlank() }
        var current = root
        for (part in parts) {
            val existing = current.findFile(part)
            current = if (existing == null || !existing.isDirectory) {
                existing?.delete()
                current.createDirectory(part)
                    ?: throw IllegalStateException("Cannot create directory $part")
            } else {
                existing
            }
        }
        return current
    }

    private fun sha256(file: File): String {
        messageDigest.reset()
        file.inputStream().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val read = input.read(buffer)
                if (read <= 0) break
                messageDigest.update(buffer, 0, read)
            }
        }
        return messageDigest.digest().joinToString(separator = "") { "%02x".format(it) }
    }
}

sealed interface ResourceSyncResult {
    data object Success : ResourceSyncResult
    data object PermissionMissing : ResourceSyncResult
}

sealed interface ResourceSyncProgress {
    data object Idle : ResourceSyncProgress
    data class Running(val fileIndex: Int, val fileCount: Int) : ResourceSyncProgress
    data object Success : ResourceSyncProgress
}
