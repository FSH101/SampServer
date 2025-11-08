package com.denissamp.launcher.data.manifest

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request
import timber.log.Timber
import java.io.File

class ManifestRepository(
    private val context: Context,
    private val client: OkHttpClient,
    private val json: Json,
    private val manifestUrl: String
) {
    private val cacheFile: File = File(context.cacheDir, "manifest.json")

    suspend fun fetchManifest(force: Boolean = false): ManifestPayload = withContext(Dispatchers.IO) {
        if (!force && cacheFile.exists()) {
            runCatching { cacheFile.readText() }
                .mapCatching { json.decodeFromString(ManifestPayload.serializer(), it) }
                .onFailure { Timber.w(it, "Failed to read cached manifest") }
                .getOrNull()?.let { return@withContext it }
        }

        val request = Request.Builder().url(manifestUrl).get().build()
        val response = client.newCall(request).execute()
        if (!response.isSuccessful) {
            throw IllegalStateException("Manifest request failed with ${response.code}")
        }
        val body = response.body?.string() ?: throw IllegalStateException("Empty manifest body")
        cacheFile.writeText(body)
        json.decodeFromString(ManifestPayload.serializer(), body)
    }
}
