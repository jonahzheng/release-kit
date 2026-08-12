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

```bash
# 1. Copy release-kit into your environment
git clone <release-kit-repo> tools/release-kit
cd /path/to/myapp

# 2. One-click init: copies a config template (release-kit.yaml) + installs the hook
./tools/release-kit/release-kit.sh init

# 3. Edit the config to match your app
#    release-kit.yaml  (keep it in YOUR repo, versioned with your project)

# 4. Package any platform with one command
./tools/release-kit/release-kit.sh publish windows [-Obfuscate]
./tools/release-kit/release-kit.sh publish android
```

- Config is kept **inside your project** (`release-kit.yaml`), not inside the tool.
- Every `git commit` automatically bumps `pubspec.yaml` (skip with `--no-verify`).
- Artifacts go to `dist/<app>-<version>-<platform>`.

### Windows

```powershell
# same workflow, PowerShell entry:
.\tools\release-kit\release-kit.ps1 init
.\tools\release-kit\release-kit.ps1 publish windows -Obfuscate
```

### Commands

| Command | Description |
|---|---|
| `release-kit init` | copy `release-kit.yaml` template + install hook (one step) |
| `release-kit install` | install the pre-commit hook only |
| `release-kit publish <platform>` | build & package (windows / android / macos / linux / ios) |
| `release-kit publish <platform> -p <project-root>` | same, but target another project from anywhere |
| `release-kit bump [--build-only]` | manually bump the pubspec version |

## Layout

```
release-kit.sh / release-kit.ps1   # unified CLI entry
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
config.yaml               # default config template
docs/RELEASE.md           # usage docs
```

## License

MIT
