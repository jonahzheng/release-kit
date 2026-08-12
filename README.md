# release-kit

Flutter release toolkit: **automatic version management** + **multi-platform packaging**, with a unified config entry, reusable by any Flutter project.

> Independently extracted from ZShell (ZShell stays as-is). Windows + Android first; macOS / Linux / iOS are skeletons.

## Features

- **Automatic version bumping** (`bin/bump_version.dart` + pre-commit hook)
  - Analyzes staged changes to decide the bump: deleted source → major, added/major changes → minor, minor changes → patch, build +1
  - Supports both monorepo (`app/` subdirectory) and standalone project (root directory) layouts
  - `git commit --no-verify` skips the bump (release freeze)
- **Unified config**: a single `config.yaml` shared by Windows/Android/Linux/macOS/iOS scripts
- **Multi-platform packaging**: `scripts/publish_*.sh` / `publish_windows.ps1`
  - Windows: zip + optional hardening rename (engine DLL rename + import table patch)
  - Android: APK + AAB
  - macOS / iOS / Linux: skeleton scripts

## Quick Start

### 1. Copy release-kit into your environment

```bash
# Assuming your Flutter project is at /path/to/myapp
git clone <release-kit-repo> /path/to/release-kit
cd /path/to/myapp
```

### 2. Configure

Edit `release-kit/config.yaml` and set the app name, icon, bundle id, server address, etc.

### 3. Install the version-bump hook

```bash
# Windows
powershell -ExecutionPolicy Bypass -File release-kit/scripts/install_hook.ps1 -ProjectRoot .

# macOS / Linux
./release-kit/scripts/install_hook.sh -p .
```

Every `git commit` will then automatically bump the version in `pubspec.yaml`.

### 4. Package

```bash
# Windows (run from the Flutter project root)
powershell -ExecutionPolicy Bypass -File release-kit/scripts/publish_windows.ps1 -Obfuscate

# Android
./release-kit/scripts/publish_android.sh
```

Artifacts are written to `dist/<app>-<version>-<platform>`.

## Layout

```
bin/
  bump_version.dart       # automatic version bump (pure Dart)
  pre-commit.hook         # hook template
scripts/
  install_hook.ps1/.sh    # one-click hook installer
  common.sh               # shared logic
  publish_windows.ps1     # Windows packaging
  publish_android.sh      # Android packaging
  publish_macos.sh        # macOS skeleton
  publish_linux.sh        # Linux skeleton
  publish_ios.sh          # iOS skeleton
config.yaml               # unified config
docs/RELEASE.md           # usage docs
```

## License

MIT
