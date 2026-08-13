<h1 align="center">release-kit</h1>

<h3 align="center">Flutter release toolkit — automatic version management + multi-platform packaging, unified config, reusable by any Flutter project.</h3>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-2DBCF2.svg?logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Platform-Windows%20Android%20macOS%20Linux%20iOS-blue.svg" alt="Platform">
  <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License">
</p>

<p align="center">
  <strong>English</strong> | <a href="README.zh.md">简体中文</a>
</p>

<p align="center">
  <a href="https://github.com/sponsors/jonahzheng">
    <img src="https://img.shields.io/badge/%E2%9D%A4%EF%B8%8F%20Sponsor%20me%20on%20GitHub-EA4AAA?style=for-the-badge&logo=github&logoColor=white" alt="Sponsor me on GitHub">
  </a>
</p>

---

> **release-kit** is a Flutter release toolkit: versions bump automatically on `git commit`, one flat `release-kit.yaml` drives every platform, and one command packages Windows / Android / macOS / Linux / iOS.

---

## Features

- **Auto version bump** — `git commit` increments `pubspec.yaml` (smart major/minor/patch + build)
- **One flat config** — `release-kit.yaml` shared by all platform scripts
- **One command packaging** — Windows / Android / macOS / Linux / iOS
- **Auto launcher icons** — one `app.logo` source image, icons generated for every platform

---

## Quick Start

```bash
git clone <release-kit-repo> tools/release-kit   # 1. get the tool
cd /path/to/myapp                                 # 2. your Flutter project

tools/release-kit/release-kit.sh init             # 3. one step: config + hook
tools/release-kit/release-kit.sh publish android  # 4. build & package
```

Windows? Use `release-kit.ps1` instead of `release-kit.sh`:

```powershell
.\tools\release-kit\release-kit.ps1 init
.\tools\release-kit\release-kit.ps1 publish windows -Obfuscate
```

After `init`, edit `release-kit.yaml` in your project. Then:

- `git commit` auto-bumps `pubspec.yaml` (skip with `--no-verify`)
- Artifacts go to `dist/<app>-<version>-<platform>`

---

## Commands

| Command | Description |
|---|---|
| `release-kit init` | copy `release-kit.yaml` template + install hook (one step) |
| `release-kit publish <platform>` | build & package (windows / android / macos / linux / ios) |

Commands target the current directory. Add `-p <project-root>` (anywhere in the args) to target another project from any directory:

```bash
release-kit init -p /path/to/myapp
release-kit publish android --obfuscate -p /path/to/myapp
```

---

## Version Management

### Bump rules

| Code change | Bump | Example |
|:---|:---:|:---:|
| Source file deleted | major | `1.0.0 → 2.0.0` |
| New source file, or ≥ 40 new source lines | minor | `1.0.0 → 1.1.0` |
| Other (small edits, docs, config) | patch | `1.1.0 → 1.1.1` |

The build number (`+N`) increments by 1 on every commit.

### Skip a bump

`git commit --no-verify` (release-lock the version).

### Manual bump

```bash
dart run bin/bump_version.dart                # smart bump + build+1
dart run bin/bump_version.dart --build-only   # only build+1 (release-lock)
```

---

## Unified Config

`release-kit init` copies `release-kit.yaml` into your project. One flat `key: value` file (dot-namespace, `#` comments) read by every platform script:

| Key | Description |
|---|---|
| `app.name` | app name (artifact naming) |
| `app.bundleId` | Android package name / iOS bundle id |
| `app.logo` | launcher icon source image (optional) |
| `build.dartDefine.*` | injected via `--dart-define` |
| `output.dir` | artifact output dir (default `dist`) |
| `hardening.enabled` | Windows hardening rename (default off) |
| `hardening.engineDll` | new engine DLL name |
| `hardening.assetDir` | new asset dir name |
| `android.keystore` | keystore path |
| `android.keyAlias` | keystore alias |

Keystore passwords come from env vars, never from the config: `ANDROID_KEY_PASSWORD` / `ANDROID_STORE_PASSWORD`.

### Auto launcher icons

Set `app.logo` (one source image, ≥ 1024×1024 PNG recommended):

```yaml
app.logo: assets/logo.png
```

Each `release-kit publish <platform>` regenerates the platform's icons via `flutter_launcher_icons` (Android mipmaps, iOS/macOS appicon sets, Windows `.ico`). Skip with `--no-icons`.

---

## Platform Flags

| Platform | Flags | Description |
|---|---|---|
| **windows** | `-Obfuscate` | Dart obfuscated release build (symbols in `build/obfuscate_symbols`) |
| | `-SkipBuild` | reuse existing build outputs, just collect & zip |
| | `-NoRename` | skip hardening rename even if enabled |
| | `-Harden` | force hardening on (rename `flutter_windows.dll` → `core_engine.dll` + patch imports) |
| | `-CleanFlutter` | scrub all Flutter traces from the bundle (asset dir + exe path + plugin dlls), no source changes |
| | `-SkipVerify` | skip the pre-zip "exe launches" smoke test (on by default) |
| | `-OutputDir <path>` | custom artifact dir (default: `<project>/dist/<binary>`) |
| **android** | `--apk` / `--aab` | build only APK or only AAB (default: both) |
| | `--skip-build` | reuse existing outputs, just collect |
| | `--obfuscate` | Dart obfuscated release build (symbols in `build/obfuscate_symbols`) |
| **linux** | `--skip-build` | reuse existing outputs, just package |
| | `--appimage` | also build an AppImage (requires `linuxdeploy` on PATH) |
| **macos / ios** | `--skip-build` | reuse existing outputs, just package |

All flags combine with `-p <project-root>`.

### Android specifics

```bash
release-kit publish android [--apk] [--aab] [--skip-build] [--obfuscate]
```

- Default: build + collect **both** APK and AAB
- `--apk` alone → APK only; `--aab` alone → AAB only; both given → both
- `--skip-build` → reuse existing Gradle outputs, just collect artifacts
- Signing: configure the keystore in your project's `android/`, passwords via `ANDROID_KEY_PASSWORD` / `ANDROID_STORE_PASSWORD`
- Artifacts: `dist/<app>-<version>-android.apk` and `.aab` (+ sha256)

> **Note:** On the Windows entry (`release-kit.ps1`), `-Obfuscate` also works for android (auto-mapped to `--obfuscate`), so the two most common platforms share one spelling: `release-kit publish android -Obfuscate`. Non-Windows shell platforms run via Git Bash.

> **Note:** **All platforms** also accept `--no-icons` to skip auto icon generation (e.g. when your project's Dart SDK can't resolve `flutter_launcher_icons` yet): `release-kit publish windows --no-icons`.

---

## Layout

```
release-kit.sh / release-kit.ps1   # unified CLI entry
bin/
  bump_version.dart       # automatic version bump (pure Dart)
  pre-commit.hook         # hook template
scripts/
  generate_icons.sh/.ps1  # auto-generate launcher icons (app.logo)
  install_hook.ps1/.sh    # one-click hook installer
  common.sh               # shared logic
  publish_windows.ps1     # Windows packaging
  publish_android.sh      # Android packaging
  publish_macos.sh        # macOS packaging
  publish_linux.sh        # Linux packaging
  publish_ios.sh          # iOS packaging
config.yaml               # default config template
docs/RELEASE.md           # detailed usage docs
README.md / README.zh.md  # English / 简体中文
```

---

## License

MIT License — see [LICENSE](LICENSE).
