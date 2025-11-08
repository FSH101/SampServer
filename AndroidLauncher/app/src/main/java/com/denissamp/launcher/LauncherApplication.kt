package com.denissamp.launcher

import android.app.Application
import com.denissamp.launcher.logging.LogRepository
import timber.log.Timber

class LauncherApplication : Application() {
    lateinit var logRepository: LogRepository
        private set

    override fun onCreate() {
        super.onCreate()
        logRepository = LogRepository(this)
        Timber.plant(logRepository.tree)
        Timber.i("LauncherApplication started")
    }
}
