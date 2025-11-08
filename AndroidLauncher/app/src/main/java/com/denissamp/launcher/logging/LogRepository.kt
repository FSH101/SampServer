package com.denissamp.launcher.logging

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import timber.log.Timber
import java.io.File
import java.io.FileWriter
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

class LogRepository(context: Context) {
    private val logDir: File = File(context.filesDir, "logs").apply { mkdirs() }
    private val logFile: File = File(logDir, "launcher.log")
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US)

    val tree: Timber.Tree = object : Timber.DebugTree() {
        private val writing = AtomicBoolean(false)

        override fun log(priority: Int, tag: String?, message: String, t: Throwable?) {
            super.log(priority, tag, message, t)
            if (writing.compareAndSet(false, true)) {
                try {
                    FileWriter(logFile, true).use { writer ->
                        val formatted = "${dateFormat.format(System.currentTimeMillis())} [${priorityLabel(priority)}] ${tag.orEmpty()}: $message\n"
                        writer.append(formatted)
                        if (t != null) {
                            writer.append(t.stackTraceToString()).append('\n')
                        }
                    }
                } finally {
                    writing.set(false)
                }
            }
        }
    }

    fun getLogFile(): File = logFile

    suspend fun clear() = withContext(Dispatchers.IO) {
        logFile.writeText("")
    }

    private fun priorityLabel(priority: Int): String = when (priority) {
        android.util.Log.VERBOSE -> "V"
        android.util.Log.DEBUG -> "D"
        android.util.Log.INFO -> "I"
        android.util.Log.WARN -> "W"
        android.util.Log.ERROR -> "E"
        android.util.Log.ASSERT -> "A"
        else -> priority.toString()
    }
}
