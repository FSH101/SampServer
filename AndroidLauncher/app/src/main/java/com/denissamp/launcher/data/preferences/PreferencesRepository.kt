package com.denissamp.launcher.data.preferences

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import timber.log.Timber

class PreferencesRepository(context: Context) {
    private val masterKeyAlias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
    private val sharedPreferences = EncryptedSharedPreferences.create(
        "encrypted_prefs",
        masterKeyAlias,
        context,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    private val _state = MutableStateFlow(loadPreferences())
    val state: Flow<LauncherPreferences> = _state.asStateFlow()

    private fun loadPreferences(): LauncherPreferences = LauncherPreferences(
        nickname = sharedPreferences.getString(KEY_NICKNAME, "Player") ?: "Player",
        password = sharedPreferences.getString(KEY_PASSWORD, "") ?: "",
        autoLaunchClient = sharedPreferences.getBoolean(KEY_AUTO_LAUNCH, true),
        clientUri = sharedPreferences.getString(KEY_CLIENT_URI, null)
    )

    suspend fun update(transform: (LauncherPreferences) -> LauncherPreferences) = withContext(Dispatchers.IO) {
        val updated = transform(_state.value)
        sharedPreferences.edit().apply {
            putString(KEY_NICKNAME, updated.nickname)
            putString(KEY_PASSWORD, updated.password)
            putBoolean(KEY_AUTO_LAUNCH, updated.autoLaunchClient)
            putString(KEY_CLIENT_URI, updated.clientUri)
        }.apply()
        _state.emit(updated)
        Timber.i("Preferences updated: $updated")
    }

    companion object {
        private const val KEY_NICKNAME = "nickname"
        private const val KEY_PASSWORD = "password"
        private const val KEY_AUTO_LAUNCH = "auto_launch"
        private const val KEY_CLIENT_URI = "client_uri"
    }
}

data class LauncherPreferences(
    val nickname: String,
    val password: String,
    val autoLaunchClient: Boolean,
    val clientUri: String?
)
