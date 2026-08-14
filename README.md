<h1 align="center">release-kit</h1>

<h3 align="center">Flutter release toolkit — automatic version management + multi-platform packaging, unified config, reusable by any Flutter project.</h3>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-2DBCF2.svg?logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Platform-Windows%20Android%20macOS%20Linux%20iOS-blue.svg" alt="Platform">
  <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License">
  <a href="https://pub.dev/packages/release_kit">
    <img src="https://img.shields.io/pub/v/release_kit.svg" alt="pub.dev">
  </a>
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

> **release-kit** — a Dart CLI package (on pub.dev) that versions bump automatically on `git commit`, drives every platform from one `release-kit.yaml`, and builds Windows / Android / macOS / Linux / iOS with one command.

> Full usage manual: **[docs/GUIDE.md](docs/GUIDE.md)**  ·  pub.dev: **[release_kit](https://pub.dev/packages/release_kit)**

---

## Features

- **Auto version bump** — `git commit` increments `pubspec.yaml`
- **One flat config** — `release-kit.yaml` shared by all platforms
- **One command packaging** — Windows / Android / macOS / Linux / iOS
- **Auto launcher icons** — one `app.logo` image → all platform icons

---

## Quick Start

```bash
# 1. install (Dart CLI, from pub.dev)
dart pub global activate release_kit

# 2. your Flutter project
cd /path/to/myapp

# 3. one step: config + hook
release-kit init

# 4. build & package
release-kit publish android
```

Alternative — git clone (ship the tool with your repo):

```bash
git clone <release-kit-repo> tools/release-kit
tools/release-kit/release-kit.sh init
tools/release-kit/release-kit.sh publish android
```

Windows? Use `release-kit.ps1` instead of `release-kit.sh`:

```powershell
.\tools\release-kit\release-kit.ps1 init
.\tools\release-kit\release-kit.ps1 publish windows -Obfuscate
```

---

## Commands

| Command | Description |
|---|---|
| `release-kit init` | copy `release-kit.yaml` template + install hook |
| `release-kit publish <platform>` | build & package (windows / android / macos / linux / ios) |
| `release-kit bump [--build-only]` | auto-increment the version in `pubspec.yaml` from staged changes |

Add `-p <project-root>` (anywhere in the args) to target another project from any directory:

```bash
release-kit publish android --obfuscate -p /path/to/myapp
```

### Key flags

| Platform | Flags |
|---|---|
| windows | `-Obfuscate` `-SkipBuild` `-NoRename` `-Harden` `-CleanFlutter` `-SkipVerify` `-OutputDir` |
| android | `--apk` / `--aab` `--skip-build` `--obfuscate` |
| linux | `--skip-build` `--obfuscate` `--deb` `--rpm` `--appimage` |
| ios | `--skip-build` `--obfuscate` `--export-method` `--no-codesign` |
| macos | `--skip-build` `--obfuscate` |

> On Windows, `-Obfuscate` also works for android (auto-mapped to `--obfuscate`). All platforms accept `--no-icons`.

---

## License

MIT License — see [LICENSE](LICENSE).
