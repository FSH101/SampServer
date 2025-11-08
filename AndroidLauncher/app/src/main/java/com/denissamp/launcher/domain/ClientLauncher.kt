package com.denissamp.launcher.domain

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import com.denissamp.launcher.core.Constants
import timber.log.Timber

class ClientLauncher(private val context: Context) {

    fun findInstalledClient(): String? {
        val pm = context.packageManager
        return Constants.SUPPORTED_PACKAGES.firstOrNull { packageName ->
            runCatching { pm.getLaunchIntentForPackage(packageName) }
                .getOrNull() != null
        }
    }

    fun launchClient(packageName: String) {
        val pm = context.packageManager
        val intent = pm.getLaunchIntentForPackage(packageName)
            ?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
            ?: throw ActivityNotFoundException("Missing launch intent for $packageName")
        context.startActivity(intent)
        Timber.i("Launching client $packageName")
    }

    fun openClientStorePage(packageName: String) {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$packageName")).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        runCatching { context.startActivity(intent) }
            .onFailure {
                val fallback = Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$packageName"))
                    .apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
                context.startActivity(fallback)
            }
    }
}
