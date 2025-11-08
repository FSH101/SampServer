# SA-MP Mobile Launcher

Android launcher application targeting the SA-MP/open.mp server at `141.95.190.144:1453`. The launcher prepares resources, keeps the mod-pack in sync with a manifest hosted on CDN, updates client INI files via SAF, and launches any supported mobile SA-MP client package.

## Features

- Jetpack Compose UI with dark theme and RU copy
- Manifest-driven resource synchronization with SHA-256 verification and ZIP extraction
- Storage Access Framework integration for scoped storage compliance
- Encrypted preference storage for nickname, password, and auto-launch configuration
- Automatic client discovery and launch for the configured server
- Timber-based persistent logging for diagnostics

## Project structure

- `app/` — Android application module
- `app/src/main/java/com/denissamp/launcher` — Kotlin sources grouped by feature
- `app/src/main/res` — Compose resources and launcher assets

## Building

```bash
cd AndroidLauncher
gradle assembleDebug
```

The resulting APK is placed under `app/build/outputs/apk/debug/`.

## Configuration

Update `Constants.MANIFEST_URL` in `core/Constants.kt` with the production CDN endpoint before release builds. The launcher automatically pins the SA-MP server host and port defined in the same file.
