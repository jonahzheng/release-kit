# release-kit

**[English](README.md) | [简体中文](README.zh.md)**

Flutter release toolkit: **automatic version management** + **multi-platform packaging**, unified config, reusable by any Flutter project.

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

- Config lives in **your project** (`release-kit.yaml`) — edit it after `init`.
- `git commit` auto-bumps `pubspec.yaml` (skip with `--no-verify`).
- Artifacts go to `dist/<app>-<version>-<platform>`.

Windows? Use `release-kit.ps1` instead of `release-kit.sh`:

```powershell
.\tools\release-kit\release-kit.ps1 init
.\tools\release-kit\release-kit.ps1 publish windows -Obfuscate
```

### Commands

| Command | Description |
|---|---|
| `release-kit init` | copy `release-kit.yaml` template + install hook (one step) |
| `release-kit publish <platform>` | build & package (windows / android / macos / linux / ios) |

Both target the current directory. Add `-p <project-root>` (anywhere in the args) to target another project from any directory:

```bash
release-kit init -p /path/to/myapp
release-kit publish android -Obfuscate -p /path/to/myapp
```

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

## License

MIT
