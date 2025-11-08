package com.denissamp.launcher.ui

import android.app.Application
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.denissamp.launcher.data.manifest.ManifestRepository
import com.denissamp.launcher.data.preferences.PreferencesRepository
import com.denissamp.launcher.data.resources.ResourceManager
import com.denissamp.launcher.domain.ClientLauncher
import com.denissamp.launcher.domain.IniWriter

class LauncherViewModelFactory(
    private val application: Application,
    private val manifestRepository: ManifestRepository,
    private val preferencesRepository: PreferencesRepository,
    private val resourceManager: ResourceManager,
    private val clientLauncher: ClientLauncher,
    private val iniWriter: IniWriter
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(LauncherViewModel::class.java)) {
            return LauncherViewModel(
                application,
                manifestRepository,
                preferencesRepository,
                resourceManager,
                clientLauncher,
                iniWriter
            ) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class ${modelClass.name}")
    }
}
