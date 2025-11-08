package com.denissamp.launcher.ui

import android.app.Application
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.denissamp.launcher.data.manifest.ManifestPayload
import com.denissamp.launcher.data.manifest.ManifestRepository
import com.denissamp.launcher.data.preferences.LauncherPreferences
import com.denissamp.launcher.data.preferences.PreferencesRepository
import com.denissamp.launcher.data.resources.ResourceManager
import com.denissamp.launcher.data.resources.ResourceSyncProgress
import com.denissamp.launcher.data.resources.ResourceSyncResult
import com.denissamp.launcher.domain.ClientLauncher
import com.denissamp.launcher.domain.IniWriter
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import timber.log.Timber

class LauncherViewModel(
    application: Application,
    private val manifestRepository: ManifestRepository,
    private val preferencesRepository: PreferencesRepository,
    private val resourceManager: ResourceManager,
    private val clientLauncher: ClientLauncher,
    private val iniWriter: IniWriter
) : AndroidViewModel(application) {

    private val _uiState = MutableStateFlow(LauncherUiState())
    val uiState: StateFlow<LauncherUiState> = _uiState.asStateFlow()

    private var manifestPayload: ManifestPayload? = null

    init {
        viewModelScope.launch {
            preferencesRepository.state.collect { prefs ->
                _uiState.emit(_uiState.value.copy(preferences = prefs, clientUri = prefs.clientUri?.let(Uri::parse)))
            }
        }
        viewModelScope.launch {
            resourceManager.progress.collect { progress ->
                _uiState.emit(_uiState.value.copy(syncProgress = progress))
            }
        }
        refreshInstalledClient()
    }

    fun refreshInstalledClient() {
        val installed = clientLauncher.findInstalledClient()
        _uiState.value = _uiState.value.copy(installedClientPackage = installed)
    }

    fun updateNickname(nickname: String) {
        viewModelScope.launch {
            preferencesRepository.update { it.copy(nickname = nickname) }
        }
    }

    fun updatePassword(password: String) {
        viewModelScope.launch {
            preferencesRepository.update { it.copy(password = password) }
        }
    }

    fun toggleAutoLaunch(enabled: Boolean) {
        viewModelScope.launch {
            preferencesRepository.update { it.copy(autoLaunchClient = enabled) }
        }
    }

    fun updateClientUri(uri: Uri?) {
        viewModelScope.launch {
            preferencesRepository.update { it.copy(clientUri = uri?.toString()) }
        }
    }

    fun checkUpdates(force: Boolean = false) {
        viewModelScope.launch {
            _uiState.emit(_uiState.value.copy(manifestStatus = ManifestStatus.Loading, error = null))
            runCatching {
                manifestRepository.fetchManifest(force)
            }.onSuccess { manifest ->
                manifestPayload = manifest
                val index = resourceManager.loadIndex()
                val needsUpdate = index == null || index.version != manifest.version ||
                    manifest.files.any { file ->
                        index.files[file.dest]?.equals(file.sha256, ignoreCase = true) != true
                    }
                _uiState.emit(
                    _uiState.value.copy(
                        manifestStatus = if (needsUpdate) ManifestStatus.UpdateAvailable(manifest.version) else ManifestStatus.UpToDate(manifest.version)
                    )
                )
            }.onFailure { throwable ->
                Timber.e(throwable)
                _uiState.emit(_uiState.value.copy(manifestStatus = ManifestStatus.Error, error = throwable.message))
            }
        }
    }

    fun syncResources(force: Boolean = false) {
        val rootUri = _uiState.value.clientUri
        if (rootUri == null) {
            _uiState.value = _uiState.value.copy(error = "SAF permission missing")
            return
        }
        val manifest = manifestPayload
        if (manifest == null) {
            checkUpdates(force = true)
            return
        }
        viewModelScope.launch {
            val result = resourceManager.syncResources(rootUri, manifest, force)
            when (result) {
                ResourceSyncResult.PermissionMissing -> _uiState.emit(_uiState.value.copy(error = "SAF permission missing"))
                ResourceSyncResult.Success -> {
                    _uiState.emit(_uiState.value.copy(manifestStatus = ManifestStatus.UpToDate(manifest.version)))
                    writeIni(rootUri)
                    if (_uiState.value.preferences?.autoLaunchClient == true) {
                        launchClient()
                    }
                }
            }
        }
    }

    private fun writeIni(rootUri: Uri) {
        val prefs = _uiState.value.preferences ?: return
        viewModelScope.launch {
            runCatching {
                iniWriter.writeSettings(rootUri, prefs.nickname)
                iniWriter.writeModSettings(rootUri, prefs.password.ifBlank { null })
            }.onFailure { Timber.e(it, "Failed to update ini files") }
        }
    }

    fun launchClient() {
        val packageName = _uiState.value.installedClientPackage
        if (packageName != null) {
            runCatching { clientLauncher.launchClient(packageName) }
                .onFailure { Timber.e(it, "Unable to launch client") }
        }
    }

    fun openClientPage(packageName: String) {
        clientLauncher.openClientStorePage(packageName)
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }
}

data class LauncherUiState(
    val preferences: LauncherPreferences? = null,
    val clientUri: Uri? = null,
    val manifestStatus: ManifestStatus = ManifestStatus.Idle,
    val syncProgress: ResourceSyncProgress = ResourceSyncProgress.Idle,
    val installedClientPackage: String? = null,
    val error: String? = null
)

sealed interface ManifestStatus {
    data object Idle : ManifestStatus
    data object Loading : ManifestStatus
    data object Error : ManifestStatus
    data class UpToDate(val version: String) : ManifestStatus
    data class UpdateAvailable(val version: String) : ManifestStatus
}
