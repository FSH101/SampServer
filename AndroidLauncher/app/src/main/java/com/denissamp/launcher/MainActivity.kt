package com.denissamp.launcher

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import com.denissamp.launcher.core.Constants
import com.denissamp.launcher.data.manifest.ManifestRepository
import com.denissamp.launcher.data.preferences.PreferencesRepository
import com.denissamp.launcher.data.resources.ResourceManager
import com.denissamp.launcher.domain.ClientLauncher
import com.denissamp.launcher.domain.IniWriter
import com.denissamp.launcher.ui.LauncherRoot
import com.denissamp.launcher.ui.LauncherViewModel
import com.denissamp.launcher.ui.LauncherViewModelFactory
import com.denissamp.launcher.ui.theme.SampLauncherTheme
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import timber.log.Timber

class MainActivity : ComponentActivity() {

    private val okHttpClient by lazy { OkHttpClient.Builder().build() }
    private val json by lazy { Json { ignoreUnknownKeys = true } }

    private val viewModel: LauncherViewModel by viewModels {
        val manifestRepository = ManifestRepository(
            applicationContext,
            okHttpClient,
            json,
            Constants.MANIFEST_URL
        )
        val preferencesRepository = PreferencesRepository(applicationContext)
        val resourceManager = ResourceManager(
            applicationContext,
            contentResolver,
            okHttpClient,
            json
        )
        val clientLauncher = ClientLauncher(applicationContext)
        val iniWriter = IniWriter(applicationContext, contentResolver)
        LauncherViewModelFactory(
            application,
            manifestRepository,
            preferencesRepository,
            resourceManager,
            clientLauncher,
            iniWriter
        )
    }

    private val openDocumentTreeLauncher = registerForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri: Uri? ->
        if (uri != null) {
            val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            runCatching { contentResolver.takePersistableUriPermission(uri, flags) }
                .onFailure { Timber.w(it, "Failed to persist SAF permissions") }
            viewModel.updateClientUri(uri)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Timber.i("MainActivity created")
        setContent {
            SampLauncherTheme {
                LauncherRoot(viewModel = viewModel) {
                    openDocumentTreeLauncher.launch(null)
                }
            }
        }
        viewModel.checkUpdates()
    }
}
