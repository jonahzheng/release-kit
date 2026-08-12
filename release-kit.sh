#!/bin/sh
# release-kit: unified CLI entry (macOS/Linux)
# Usage:
#   ./release-kit.sh init                       # copy config template + install hook
#   ./release-kit.sh install                    # install hook only
#   ./release-kit.sh publish <platform> [args]  # windows|android|macos|linux|ios
#   ./release-kit.sh bump [--build-only]        # manually bump version
#
# Run from the Flutter project root (or app/ subdir in a monorepo).
set -e

KIT_ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

usage() {
  cat <<'EOF'
release-kit <command>

  init                        copy config template (release-kit.yaml) + install hook
  install                     install version-bump pre-commit hook
  publish <platform> [args]   build & package (windows|android|macos|linux|ios)
  bump [--build-only]         manually bump pubspec version
EOF
  exit 1
}

cmd="$1"; shift || true
case "$cmd" in
  init)
    cfg="release-kit.yaml"
    if [ ! -f "$cfg" ]; then
      cp "$KIT_ROOT/config.yaml" "$cfg"
      echo "==> created $cfg (edit it to match your app)"
    else
      echo "==> $cfg already exists, keeping it"
    fi
    exec "$KIT_ROOT/scripts/install_hook.sh" "$@"
    ;;
  install)
    exec "$KIT_ROOT/scripts/install_hook.sh" "$@"
    ;;
  publish)
    platform="$1"; shift || usage
    case "$platform" in
      windows) powershell -ExecutionPolicy Bypass -File "$KIT_ROOT/scripts/publish_windows.ps1" "$@" ;;
      android) exec "$KIT_ROOT/scripts/publish_android.sh" "$@" ;;
      macos)   exec "$KIT_ROOT/scripts/publish_macos.sh" "$@" ;;
      linux)   exec "$KIT_ROOT/scripts/publish_linux.sh" "$@" ;;
      ios)     exec "$KIT_ROOT/scripts/publish_ios.sh" "$@" ;;
      *) echo "unknown platform: $platform" >&2; usage ;;
    esac
    ;;
  bump)
    exec dart run "$KIT_ROOT/bin/bump_version.dart" "$@"
    ;;
  *) usage ;;
esac
