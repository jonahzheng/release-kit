# release-kit

**[English](README.md) | [简体中文](README.zh.md)**

Flutter release toolkit: **automatic version management** + **multi-platform packaging**, unified config, reusable by any Flutter project.

## Features

- Version auto-bumps on `git commit` (smart major/minor/patch + build)
- One flat config (`release-kit.yaml`) shared by all platform scripts
- Package Windows / Android / macOS / Linux / iOS with one command
- Auto-generate launcher icons from a single `app.logo` image

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

## Platform Flags

| Platform | Flags | Description |
|---|---|---|
| windows | `-Obfuscate` | Dart obfuscated release build (symbols in `build/obfuscate_symbols`) |
| | `-SkipBuild` | reuse existing build outputs, just collect & zip |
| | `-NoRename` | skip hardening rename even if enabled |
| | `-Harden` | force hardening on (rename `flutter_windows.dll` → `core_engine.dll` + patch imports) |
| | `-CleanFlutter` | scrub all Flutter traces from the bundle (asset dir + exe path + plugin dlls), no source changes |
| | `-SkipVerify` | skip the pre-zip "exe launches" smoke test (on by default) |
| | `-OutputDir <path>` | custom artifact dir (default: `<project>/dist/<binary>`) |
| android | `--apk` / `--aab` | build only APK or only AAB (default: both) |
| | `--skip-build` | reuse existing outputs, just collect |
| | `--obfuscate` | Dart obfuscated release build (symbols in `build/obfuscate_symbols`) |
| linux | `--skip-build` | reuse existing outputs, just package |
| | `--appimage` | also build an AppImage (requires `linuxdeploy` on PATH) |
| macos / ios | `--skip-build` | reuse existing outputs, just package |

All flags combine with `-p <project-root>`.

> **All platforms** also accept `--no-icons` to skip auto icon generation (e.g. when your project's Dart SDK can't resolve `flutter_launcher_icons` yet): `release-kit publish windows --no-icons`.

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
docs/RELEASE.md           # usage docs
README.md / README.zh.md  # English / 简体中文
```

## Support

Like this project? Sponsor me on GitHub:

[![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-GitHub?logo=github&style=for-the-badge&color=ea4aaa)](https://github.com/sponsors/jonahzheng)

## License

MIT
