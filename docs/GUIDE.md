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
release-kit publish windows --obfuscate -p /path/to/myapp
```

### Common flags (all platforms)

| Flag | Description |
|---|---|
| `-p <project-root>` / `--project <project-root>` | Target another Flutter project from any directory (allowed anywhere in the args). Defaults to the current directory. |
| `--no-icons` | Skip launcher-icon regeneration. By default every `publish` regenerates icons from `app.logo` (via `generate_icons.sh`/`.ps1`) when the source is newer than the existing icons. Use this to always skip icon work (e.g. in CI, or when `app.logo` is unset and you don't want the warning). |

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
release-kit bump                          # smart bump + build+1
release-kit bump --build-only             # only build+1 (release-lock)
```

Equivalent direct-Dart invocations (when the tool is cloned, not installed from pub.dev):

```bash
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

Every `publish` build also auto-injects `--dart-define=APP_VERSION=<x.y.z>` and `--dart-define=APP_BUILD=<build>` from `pubspec.yaml` (a `build.dartDefine.APP_VERSION` / `.APP_BUILD` entry overrides the auto value). Read them at runtime:

```dart
const appVersion = String.fromEnvironment('APP_VERSION');
const appBuild = String.fromEnvironment('APP_BUILD');
```
| `output.dir` | artifact output dir (default `dist`) |
| `hardening.enabled` | Windows hardening rename switch (default false) |
| `hardening.engineDll` | new engine DLL name |
| `hardening.assetDir` | new asset dir name |
| `android.keystore` | keystore path |
| `android.keyAlias` | keystore alias |
| `linux.desktopCategories` | freedesktop desktop-entry categories for `.deb`/`.rpm` (default `Utility;`) |

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
- Linux: `linux/runner/my_icon.png` (resized 512×512 with ImageMagick, or copied as-is)

Skipped when `app.logo` is unset; errors out when the source image is missing. On first use it auto-adds `flutter_launcher_icons` to dev_dependencies.

## 3. Packaging

### Versioned changelog

Every `publish` also emits a standard, versioned changelog (Keep a Changelog format) alongside the artifacts: `dist/CHANGELOG-<version>+<build>.md`.

The content is extracted from your project's `CHANGELOG.md` — the section matching the current version (`## [x.y.z] - date` plus its `### Added/Changed/Fixed/...`). If there is no `CHANGELOG.md` (or no section for the version), release-kit falls back to grouping the `git log` since the last tag by conventional-commit type (`feat:` → Added, `fix:` → Fixed, everything else → Changed).

```text
# MyApp 1.2.3+4

## [1.2.3] - 2026-09-01

### Added
- ...
```

### Windows

```bash
release-kit publish windows [--obfuscate] [--skip-build] [--no-rename] [--harden] [--clean-flutter] [--skip-verify] [--output-dir <path>]
```

| Flag | Description |
|---|---|
| `--obfuscate` | Dart obfuscated build (symbols in `build/obfuscate_symbols`) |
| `--skip-build` | Reuse existing `build\windows\x64\runner\Release` outputs, just collect/package artifacts |
| `--no-rename` | Force hardening rename off even if `hardening.enabled: true` is set in config |
| `--harden` | Force hardening rename on regardless of config (`flutter_windows.dll → core_engine.dll`, auto-patch EXE/plugin DLL import tables) |
| `--clean-flutter` | Implies hardening; additionally scrub Flutter traces from the bundle (see below). Mutually exclusive with `--no-rename` (`--no-rename` wins) |
| `--skip-verify` | Skip the pre-zip "exe launches" smoke test (on by default; warns early if the build is broken) |
| `--output-dir <path>` | Override the artifact staging/zip output directory |

- Artifacts: `dist/<app>-<version>+<build>-win64.zip` + sha256
- Hardening rename (with `--harden` or `hardening.enabled=true`): `flutter_windows.dll → core_engine.dll`, auto-patching EXE/plugin DLL import tables

### Scrub Flutter traces (`--clean-flutter`)

```bash
release-kit publish windows --obfuscate --clean-flutter
```

Pure **artifact-level** processing, **no project source changes** (`main.cpp` / CMake / `git status` unaffected, `flutter run` keeps working):

1. `data\flutter_assets` → `data\resources`
2. exe-embedded UTF-16 `flutter_assets` path string → `resources` (equal-length NUL padding, engine loads fine)
3. `flutter_windows.dll` → `core_engine.dll` + import table patch
4. remaining Flutter plugin DLLs (e.g. `flutter_tts_plugin.dll`, `isar_community_flutter_libs_plugin.dll`) renamed + reference patched

The bundle no longer contains any `flutter` filenames, and **the packaged exe is verified runnable**.

> `--clean-flutter` implies hardening rename; mutually exclusive with `--no-rename` (`--no-rename` wins).

### Android

```bash
release-kit publish android [--apk] [--aab] [--skip-build] [--obfuscate]
```

| Flag | Description |
|---|---|
| `--apk` | Build only the APK (turns off AAB) |
| `--aab` | Build only the AAB (turns off APK) |
| `--skip-build` | Reuse existing build outputs, just collect artifacts |
| `--obfuscate` | Dart obfuscated build (symbols in `build/obfuscate_symbols`) |

Default builds both APK + AAB.
- Artifacts: `dist/<app>-<version>-android.apk / .aab` + sha256
- Signing must be configured with a keystore under your project's `android/` (passwords via env vars)

> Every platform uses the same double-dash long-flag spelling, so `--obfuscate` works identically on Windows, Android, macOS, Linux and iOS:
> ```powershell
> release-kit publish windows --obfuscate      # Windows obfuscation
> release-kit publish android --obfuscate      # Android obfuscation
> ```
> Non-Windows platforms (macOS/Linux/iOS) run via Git Bash on Windows.

### iOS

```bash
release-kit publish ios [--skip-build] [--obfuscate] [--export-method <method>] [--no-codesign]
```

| Flag | Description |
|---|---|
| `--skip-build` | Reuse existing build outputs, just collect the `.ipa` |
| `--obfuscate` | Dart obfuscated build (symbols in `build/obfuscate_symbols`) |
| `--export-method <method>` | `ad-hoc` \| `development` \| `enterprise` \| `app-store` (default `app-store`) |
| `--no-codesign` | Build without code signing (CI / local smoke test); collects the `.xcarchive` since Flutter skips `.ipa` generation when unsigned |

- Requires **macOS + Xcode + iOS signing** (Apple Developer cert/profile); produces an `.ipa` for TestFlight / App Store
- Artifacts: `dist/<app>-<version>-ios.ipa` + sha256

### macOS

```bash
release-kit publish macos [--skip-build] [--obfuscate]
```

| Flag | Description |
|---|---|
| `--skip-build` | Reuse existing build outputs, just package the `.app` into a `.dmg` |
| `--obfuscate` | Dart obfuscated build (symbols in `build/obfuscate_symbols`) |

- Requires **macOS + Xcode**; produces a drag-to-install `.dmg` via `hdiutil` (UDZO)
- Note: distribution needs a Developer ID signing config; without it the `.app` runs locally only (`flutter build macos` has no `--no-codesign`)
- Artifacts: `dist/<app>-<version>+<build>-macos.dmg` + `dist/<app>-<version>+<build>-macos.zip` + sha256

### Linux

```bash
release-kit publish linux [--skip-build] [--obfuscate] [--deb] [--rpm] [--appimage]
```

| Flag | Description |
|---|---|
| `--skip-build` | Reuse existing build outputs, just package artifacts |
| `--obfuscate` | Dart obfuscated build (symbols in `build/obfuscate_symbols`) |
| `--deb` | Build a Debian/Ubuntu package via `dpkg-deb` (desktop entry + hi-color icon included; `dpkg-deb` must be installed) |
| `--rpm` | Build a Fedora/RHEL package via `rpmbuild` (`rpmbuild` must be installed) |
| `--appimage` | Build an AppImage via `linuxdeploy` (must be installed; see https://github.com/linuxdeploy/linuxdeploy) |

- Requires a Linux host with Flutter Linux desktop support (GTK toolchain)
- Default output: portable `dist/<app>-<version>+<build>-linux.zip` (release bundle under a single top-level `<app>/` dir) — always produced; used by the website download + in-app auto-update
- Desktop-entry categories come from `linux.desktopCategories` (default `Utility;`)
- Icon source for the packages: `linux/runner/my_icon.png` (auto-generated from `app.logo`)
- Artifacts: `dist/<app>-<version>+<build>-linux.zip` + optional `.deb` / `.rpm` / `.AppImage` + sha256

## 4. FAQ

| Symptom | Cause | Fix |
|---|---|---|
| hook reports `version: line not found` | pubspec has no `version:` line | add `version: 0.1.0+1` to pubspec |
| hook not running | `core.hooksPath` not set | re-run `release-kit init` |
| Windows build DLL_NOT_FOUND | import table not patched after hardening rename | re-run with the latest scripts (auto-patches) |
| Android build signing failed | keystore password missing | set `ANDROID_KEY_PASSWORD` etc. env vars |

### Linux / WSL environment issues (not caused by release-kit)

These come from the build host, not from release-kit.

**Q: `release-kit publish linux` prints `Woah! You appear to be trying to run flutter as root.`**

It's a warning, not an error — you're running Flutter as `root` (common under WSL). It doesn't affect packaging; to silence it, run from a non-root user.

**Q: build fails with `Cannot allocate memory, errno = 12` (ENOMEM)**

The host ran out of memory (not disk). Check `free -h`. Under WSL1 the distro shares the host's RAM and `.wslconfig` limits don't apply, so heavy Linux builds easily hit this.

```bash
free -h          # check available memory
```

Free up memory (close other apps) or move to WSL2 (see next).

**Q: my `.wslconfig` `[wsl2]` `memory=` / `swap=` has no effect**

Those settings only apply to WSL2. If `wsl -l -v` shows `VERSION 1`, you're on WSL1 and the `[wsl2]` section is ignored. Convert to WSL2:

```powershell
wsl --set-version <distro> 2
```

**Q: converting to WSL2 fails with `HCS_E_SERVICE_NOT_AVAILABLE` / "required feature is not installed"**

The Virtual Machine Platform isn't running. Enable it and reboot (reboot is mandatory):

```powershell
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

Then reboot Windows, confirm the hypervisor is up, and convert:

```powershell
(Get-CimInstance Win32_ComputerSystem).HypervisorPresent   # must be True
wsl --set-version <distro> 2
```

If it's still `False`, run `bcdedit /set hypervisorlaunchtype auto` and reboot again.

**Q: `--rpm` fails with `rpmbuild not found`**

```bash
sudo apt install -y rpm
```

**Q: `--appimage` fails with `linuxdeploy not found`**

Install `linuxdeploy` (plus the GTK plugin so GTK deps get bundled):

```bash
wget https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
chmod +x linuxdeploy-x86_64.AppImage
sudo mv linuxdeploy-x86_64.AppImage /usr/local/bin/linuxdeploy

wget https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh
chmod +x linuxdeploy-plugin-gtk.sh
sudo mv linuxdeploy-plugin-gtk.sh /usr/local/bin/linuxdeploy-plugin-gtk
```

**Q: `--appimage` fails with `fuse: device not found` / `Cannot mount AppImage`**

`linuxdeploy` is itself an AppImage and needs FUSE, which is often unavailable under WSL. Wrap it to run without FUSE:

```bash
sudo mv /usr/local/bin/linuxdeploy /usr/local/bin/linuxdeploy.AppImage
printf '#!/bin/sh\nexec /usr/local/bin/linuxdeploy.AppImage --appimage-extract-and-run "$@"\n' \
  | sudo tee /usr/local/bin/linuxdeploy >/dev/null
sudo chmod +x /usr/local/bin/linuxdeploy
```

Then re-run `release-kit publish linux --appimage`.
