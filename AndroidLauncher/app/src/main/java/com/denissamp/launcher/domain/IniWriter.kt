package com.denissamp.launcher.domain

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import com.denissamp.launcher.core.Constants
import timber.log.Timber
import java.io.BufferedReader
import java.io.BufferedWriter
import java.io.InputStreamReader
import java.io.OutputStreamWriter

class IniWriter(
    private val context: Context,
    private val contentResolver: ContentResolver
) {
    fun writeSettings(rootUri: Uri, nickname: String) {
        writeIni(rootUri, Constants.SAMP_SETTINGS_REL) { lines ->
            lines.filterNot { it.startsWith("name=") } + "name=$nickname"
        }
    }

    fun writeModSettings(rootUri: Uri, password: String?) {
        writeIni(rootUri, Constants.SAMP_MODSA_SETTINGS_REL) { lines ->
            val filtered = lines.filterNot {
                it.startsWith("host=") || it.startsWith("port=") || it.startsWith("password=")
            }.toMutableList()
            filtered.add("host=${Constants.SERVER_HOST}")
            filtered.add("port=${Constants.SERVER_PORT}")
            if (!password.isNullOrBlank()) {
                filtered.add("password=$password")
            }
            filtered
        }
    }

    private fun writeIni(rootUri: Uri, relativePath: String, block: (List<String>) -> List<String>) {
        val root = DocumentFile.fromTreeUri(context, rootUri)
            ?: throw IllegalStateException("SAF root not available")
        val pathParts = relativePath.split('/')
        var current = root
        for (i in 0 until pathParts.lastIndex) {
            val part = pathParts[i]
            current = current.findFile(part) ?: current.createDirectory(part)
                ?: throw IllegalStateException("Unable to create $part")
        }
        val fileName = pathParts.last()
        val file = current.findFile(fileName) ?: current.createFile("text/plain", fileName)
            ?: throw IllegalStateException("Unable to create $fileName")

        val originalLines = contentResolver.openInputStream(file.uri)?.use { input ->
            BufferedReader(InputStreamReader(input)).use { reader ->
                reader.lineSequence().toList()
            }
        } ?: emptyList()

        val updated = block(originalLines)
        val backup = current.findFile("$fileName.bak") ?: current.createFile("text/plain", "$fileName.bak")
        if (backup != null) {
            contentResolver.openOutputStream(backup.uri, "wt")?.use { out ->
                BufferedWriter(OutputStreamWriter(out)).use { writer ->
                    originalLines.forEach { line ->
                        writer.write(line)
                        writer.newLine()
                    }
                }
            }
        }

        contentResolver.openOutputStream(file.uri, "wt")?.use { out ->
            BufferedWriter(OutputStreamWriter(out)).use { writer ->
                updated.forEach { line ->
                    writer.write(line)
                    writer.newLine()
                }
            }
        } ?: throw IllegalStateException("Unable to open output stream for $fileName")

        Timber.i("Updated ini $relativePath")
    }
}
