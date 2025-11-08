package com.denissamp.launcher.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.CloudDownload
import androidx.compose.material.icons.outlined.PlayArrow
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.denissamp.launcher.R
import com.denissamp.launcher.core.Constants
import com.denissamp.launcher.data.resources.ResourceSyncProgress

sealed class LauncherScreen(val route: String) {
    data object Main : LauncherScreen("main")
    data object Resources : LauncherScreen("resources")
    data object Settings : LauncherScreen("settings")
    data object NoClient : LauncherScreen("no-client")
}

@Composable
fun LauncherRoot(viewModel: LauncherViewModel, onRequestSaf: () -> Unit) {
    val navController = rememberNavController()
    val state by viewModel.uiState.collectAsState()

    LaunchedEffect(state.installedClientPackage) {
        if (state.installedClientPackage == null) {
            navController.navigate(LauncherScreen.NoClient.route) {
                popUpTo(LauncherScreen.Main.route) { inclusive = true }
            }
        } else if (navController.currentDestination?.route == LauncherScreen.NoClient.route) {
            navController.navigate(LauncherScreen.Main.route) {
                popUpTo(LauncherScreen.NoClient.route) { inclusive = true }
            }
        }
    }

    NavHost(navController = navController, startDestination = LauncherScreen.Main.route) {
        composable(LauncherScreen.Main.route) {
            MainScreen(
                state = state,
                navController = navController,
                onPlay = viewModel::launchClient,
                onCheckUpdates = { viewModel.checkUpdates(force = true) }
            )
        }
        composable(LauncherScreen.Resources.route) {
            ResourcesScreen(
                state = state,
                onCheckUpdates = { viewModel.checkUpdates(force = true) },
                onRepair = { viewModel.syncResources(force = true) }
            )
        }
        composable(LauncherScreen.Settings.route) {
            SettingsScreen(
                state = state,
                onNicknameChange = viewModel::updateNickname,
                onPasswordChange = viewModel::updatePassword,
                onAutoLaunchToggle = viewModel::toggleAutoLaunch,
                onRequestFolder = onRequestSaf
            )
        }
        composable(LauncherScreen.NoClient.route) {
            NoClientScreen(onOpenStore = viewModel::openClientPage, onRetry = viewModel::refreshInstalledClient)
        }
    }
}

@Composable
private fun MainScreen(state: LauncherUiState, navController: NavHostController, onPlay: () -> Unit, onCheckUpdates: () -> Unit) {
    Scaffold(topBar = {
        TopAppBar(title = { Text(text = stringResource(id = R.string.app_name)) })
    }) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(24.dp)
                .fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            ManifestStatusCard(state)
            Button(onClick = onPlay, modifier = Modifier.fillMaxWidth()) {
                Icon(Icons.Outlined.PlayArrow, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text(text = stringResource(R.string.play))
            }
            Button(onClick = { navController.navigate(LauncherScreen.Resources.route) }, modifier = Modifier.fillMaxWidth()) {
                Icon(Icons.Outlined.CloudDownload, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text(text = stringResource(R.string.resources))
            }
            Button(onClick = { navController.navigate(LauncherScreen.Settings.route) }, modifier = Modifier.fillMaxWidth()) {
                Icon(Icons.Outlined.Build, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text(text = stringResource(R.string.settings))
            }
            Button(onClick = onCheckUpdates, modifier = Modifier.fillMaxWidth()) {
                Text(text = stringResource(R.string.check_updates))
            }
            Spacer(modifier = Modifier.weight(1f))
            Text(text = stringResource(R.string.server_address_label), style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
private fun ManifestStatusCard(state: LauncherUiState) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
        Column(modifier = Modifier.padding(16.dp)) {
            val statusText = when (val status = state.manifestStatus) {
                ManifestStatus.Idle -> stringResource(R.string.manifest_idle)
                ManifestStatus.Loading -> stringResource(R.string.manifest_sync_in_progress)
                ManifestStatus.Error -> state.error ?: stringResource(R.string.manifest_error)
                is ManifestStatus.UpToDate -> stringResource(R.string.manifest_up_to_date) + " (" + status.version + ")"
                is ManifestStatus.UpdateAvailable -> stringResource(R.string.manifest_update_available) + " (" + status.version + ")"
            }
            Text(text = statusText, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium)
        }
    }
}

@Composable
private fun ResourcesScreen(state: LauncherUiState, onCheckUpdates: () -> Unit, onRepair: () -> Unit) {
    Scaffold(topBar = { TopAppBar(title = { Text(stringResource(R.string.resources)) }) }) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(24.dp)
                .fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Button(onClick = onCheckUpdates, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.check_updates))
            }
            Button(onClick = onRepair, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.repair_files))
            }
            when (val progress = state.syncProgress) {
                ResourceSyncProgress.Idle -> Text(text = stringResource(R.string.manifest_up_to_date))
                is ResourceSyncProgress.Running -> Text(text = stringResource(R.string.file_count_progress, progress.fileIndex, progress.fileCount))
                ResourceSyncProgress.Success -> Text(text = stringResource(R.string.manifest_sync_completed))
            }
        }
    }
}

@Composable
private fun SettingsScreen(
    state: LauncherUiState,
    onNicknameChange: (String) -> Unit,
    onPasswordChange: (String) -> Unit,
    onAutoLaunchToggle: (Boolean) -> Unit,
    onRequestFolder: () -> Unit
) {
    val prefs = state.preferences
    Scaffold(topBar = { TopAppBar(title = { Text(stringResource(R.string.settings)) }) }) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(24.dp)
                .fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            TextField(
                modifier = Modifier.fillMaxWidth(),
                value = prefs?.nickname.orEmpty(),
                onValueChange = onNicknameChange,
                label = { Text(stringResource(R.string.nickname)) }
            )
            TextField(
                modifier = Modifier.fillMaxWidth(),
                value = prefs?.password.orEmpty(),
                onValueChange = onPasswordChange,
                label = { Text(stringResource(R.string.password)) },
                visualTransformation = PasswordVisualTransformation()
            )
            RowSwitch(
                checked = prefs?.autoLaunchClient ?: true,
                onCheckedChange = onAutoLaunchToggle,
                label = stringResource(R.string.auto_launch)
            )
            Text(text = state.clientUri?.toString() ?: stringResource(R.string.missing_saf_permission))
            Button(onClick = onRequestFolder, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.select_client_folder))
            }
        }
    }
}

@Composable
private fun RowSwitch(checked: Boolean, onCheckedChange: (Boolean) -> Unit, label: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(text = label)
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors()
        )
    }
}

@Composable
private fun NoClientScreen(onOpenStore: (String) -> Unit, onRetry: () -> Unit) {
    Scaffold(topBar = { TopAppBar(title = { Text(stringResource(R.string.no_client_title)) }) }) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(24.dp)
                .fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(stringResource(R.string.no_client_description))
            Constants.SUPPORTED_PACKAGES.forEach { packageName ->
                TextButton(onClick = { onOpenStore(packageName) }) {
                    Text(text = packageName)
                }
            }
            Button(onClick = onRetry) {
                Text(stringResource(R.string.retry))
            }
        }
    }
}
