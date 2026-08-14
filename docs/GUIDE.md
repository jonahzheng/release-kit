# release-kit Guide

**[English](GUIDE.md) | [简体中文](GUIDE.zh.md)**

## 0. Install & Entry Points

Two ways, pick one:

```bash
# B: install from pub.dev (Dart CLI package)
dart pub global activate release_kit

# A: git clone and use (ship the tool with your repo)
git clone <release-kit-repo> tools/release-kit
```

Command entry points:

- B: `release-kit` (global command)
- A: `tools/release-kit/release-kit.sh` (macOS/Linux) or `release-kit.ps1` (Windows)

```bash
release-kit init                       # one-step setup (config + hook)
release-kit publish <platform> [args]  # build & package (use -p <project-root> from anywhere)
```

Config lives **inside the project**, resolution order:

1. `<project>/release-kit.yaml` (recommended, commit it with your repo)
2. `<project>/config.yaml`
3. tool default `lib/assets/config.yaml`

Both commands target the current directory. Add `-p <project-root>` (anywhere in the args) to target another project from any directory:

```bash
# operate on another project from anywhere
release-kit init -p /path/to/myapp
release-kit publish android -p /path/to/myapp
release-kit publish windows -Obfuscate -p /path/to/myapp
```

## 1. Version Management

### Bump rules (`bin/bump_version.dart`)

| Code change | Bump | Example |
|---|---|---|
| Source file deleted | major | `1.0.0 → 2.0.0` |
| New source file, or ≥ 40 added source lines | minor | `1.0.0 → 1.1.0` |
| Other (small edits, docs, config) | patch | `1.1.0 → 1.1.1` |

The build number (`+N`) increments by 1 on every commit.

### Path resolution

`bump_version.dart` locates pubspec via `--pubspec <path>` or auto-detection:

- Standalone project: `<root>/pubspec.yaml`
- Monorepo (e.g. ZShell): `<root>/app/pubspec.yaml`
- Explicit: `dart run bin/bump_version.dart --pubspec path/to/pubspec.yaml`

### Manual bump

```bash
# run the Dart script directly (release-kit ships init + publish; bump manually via this)
dart run bin/bump_version.dart                # smart bump + build+1
dart run bin/bump_version.dart --build-only   # only build+1 (release-lock)
```

### Hook install

```bash
release-kit init
```

Effect: copies the `release-kit.yaml` template + sets `git config core.hooksPath` to the project's `.githooks`, so every `git commit` auto-bumps and stages.

Skip the bump (release-lock a version): `git commit --no-verify`.

## 2. Unified Config

Config lives inside the project: `<project>/release-kit.yaml` (copied from the tool template by `release-kit init`).

Flat `key: value`, dot-namespace, `#` comments. All platform scripts read the same file.

| Key | Description |
|---|---|
| `app.name` | app name (zip/artifact naming) |
| `app.bundleId` | Android package name / iOS bundle id |
| `app.logo` | launcher icon source image (optional, icons auto-generated on `publish`) |
| `build.dartDefine.*` | injected via `--dart-define` |
| `output.dir` | artifact output dir (default `dist`) |
| `hardening.enabled` | Windows hardening rename switch (default false) |
| `hardening.engineDll` | new engine DLL name |
| `hardening.assetDir` | new asset dir name |
| `android.keystore` | keystore path |
| `android.keyAlias` | keystore alias |

Keystore passwords come from env vars, never from the config: `ANDROID_KEY_PASSWORD` / `ANDROID_STORE_PASSWORD`.

### Auto launcher icons

Set `app.logo` in the config (one source image, ≥ 1024×1024 PNG recommended):

```yaml
app.logo: assets/logo.png
```

Each `release-kit publish <platform>` first runs `lib/assets/scripts/generate_icons.sh` (`.ps1` on Windows), which drives `flutter_launcher_icons` to generate:

- Android: `android/app/src/main/res/mipmap-*/ic_launcher.png`
- iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- macOS: `macos/Runner/Assets.xcassets/AppIcon.appiconset/`
- Windows: `windows/runner/resources/app_icon.ico`

Skipped when `app.logo` is unset; errors out when the source image is missing. On first use it auto-adds `flutter_launcher_icons` to dev_dependencies.

## 3. Packaging

### Windows

```bash
release-kit publish windows [-Obfuscate] [-SkipBuild] [-NoRename] [-Harden] [-CleanFlutter] [-SkipVerify]
```

- `-Obfuscate`: Dart obfuscated build (symbols in `build/obfuscate_symbols`)
- `-SkipVerify`: skip the pre-zip "exe launches" smoke test (on by default; warns early if the build is broken)
- Artifacts: `dist/<app>-<version>-win64.zip` + sha256
- Hardening rename (with `-Harden` or `hardening.enabled=true`): `flutter_windows.dll → core_engine.dll`, auto-patching EXE/plugin DLL import tables

### Scrub Flutter traces (`-CleanFlutter`)

```bash
release-kit publish windows -Obfuscate -CleanFlutter
```

Pure **artifact-level** processing, **no project source changes** (`main.cpp` / CMake / `git status` unaffected, `flutter run` keeps working):

1. `data\flutter_assets` → `data\resources`
2. exe-embedded UTF-16 `flutter_assets` path string → `resources` (equal-length NUL padding, engine loads fine)
3. `flutter_windows.dll` → `core_engine.dll` + import table patch
4. remaining Flutter plugin DLLs (e.g. `flutter_tts_plugin.dll`, `isar_community_flutter_libs_plugin.dll`) renamed + reference patched

The bundle no longer contains any `flutter` filenames, and **the packaged exe is verified runnable**.

> `-CleanFlutter` implies hardening rename; mutually exclusive with `-NoRename` (`-NoRename` wins).

### Android

```bash
release-kit publish android [--apk] [--aab] [--skip-build] [--obfuscate]
```

- Default builds APK + AAB
- `--obfuscate`: Dart obfuscated build (symbols in `build/obfuscate_symbols`)
- Artifacts: `dist/<app>-<version>-android.apk / .aab` + sha256
- Signing must be configured with a keystore under your project's `android/` (passwords via env vars)

> On the Windows entry (`release-kit.ps1`), `-Obfuscate` auto-maps to `--obfuscate`, so the two platforms share one spelling:
> ```powershell
> release-kit publish windows -Obfuscate      # Windows obfuscation
> release-kit publish android -Obfuscate      # Android obfuscation (same as --obfuscate)
> ```
> Other non-Windows platforms (macOS/Linux/iOS) run via Git Bash on Windows.

### iOS

```bash
release-kit publish ios [--skip-build] [--obfuscate] [--export-method <method>] [--no-codesign]
```

- Requires **macOS + Xcode + iOS signing** (Apple Developer cert/profile); produces an `.ipa` for TestFlight / App Store
- `--obfuscate`: Dart obfuscated build (symbols in `build/obfuscate_symbols`)
- `--export-method`: `ad-hoc` | `development` | `enterprise` | `app-store` (default `app-store`)
- `--no-codesign`: build without code signing (CI / local smoke test)
- Artifacts: `dist/<app>-<version>-ios.ipa` + sha256

### macOS

```bash
release-kit publish macos [--skip-build] [--obfuscate] [--no-codesign]
```

- Requires **macOS + Xcode**; produces a drag-to-install `.dmg` via `hdiutil` (UDZO)
- `--obfuscate`: Dart obfuscated build (symbols in `build/obfuscate_symbols`)
- `--no-codesign`: build without code signing (CI / local smoke test)
- Note: distribution needs a Developer ID signing config; without it the `.app` runs locally only
- Artifacts: `dist/<app>-<version>-macos.dmg` + sha256

### Linux (skeleton)

The script contains config reading + `flutter build` commands + artifact paths, but is **not yet verified in the corresponding environment** — refine as needed:

- Linux: bundle → tar.gz / AppImage

## 4. FAQ

| Symptom | Cause | Fix |
|---|---|---|
| hook reports `version: line not found` | pubspec has no `version:` line | add `version: 0.1.0+1` to pubspec |
| hook not running | `core.hooksPath` not set | re-run `release-kit init` |
| Windows build DLL_NOT_FOUND | import table not patched after hardening rename | re-run with the latest scripts (auto-patches) |
| Android build signing failed | keystore password missing | set `ANDROID_KEY_PASSWORD` etc. env vars |
