#!/bin/sh
# release-kit: unified CLI entry (macOS/Linux)
# Usage:
#   ./release-kit.sh init [-p <project-root>]                       # copy config template + install hook
#   ./release-kit.sh publish <platform> [args] [-p <project-root>]  # windows|android|macos|linux|ios
#
# All commands run against the current directory. Pass -p <project-root>
# (anywhere in the args) to target another project from any directory.
set -e

KIT_ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

usage() {
  cat <<'EOF'
release-kit <command>

  init                        copy config template (release-kit.yaml) + install hook
  publish <platform> [args]   build & package (windows|android|macos|linux|ios)

  -p <project-root>           optional, any command: target another project from anywhere
EOF
  exit 1
}

# strip -p/--project out of "$@" and print the remaining args
# (project path is written to a temp file; read via cat "$PROJECT_TMP")
extract_project() {
  PROJECT_ARG=""
  KEEP=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -p|--project)
        if [ -n "$2" ]; then PROJECT_ARG="$2"; shift 2; else shift; fi
        ;;
      *) KEEP="$KEEP $1"; shift ;;
    esac
  done
  printf '%s' "$PROJECT_ARG" > "$PROJECT_TMP"
  echo "$KEEP"
}

cmd="$1"; shift || true

# extract -p first so every command supports it
PROJECT_TMP="${TMPDIR:-/tmp}/release-kit-proj.$$"
trap 'rm -f "$PROJECT_TMP"' EXIT
# shellcheck disable=SC2046
set -- $(extract_project "$@")
PROJECT_ARG=$(cat "$PROJECT_TMP")
rm -f "$PROJECT_TMP"

# resolve the effective project root (cwd unless -p was given)
ROOT="$PROJECT_ARG"
[ -z "$ROOT" ] && ROOT=$(pwd)

# validate project root early (before touching the filesystem)
if [ ! -d "$ROOT" ]; then
  echo "release-kit: project root not found: $ROOT" >&2
  exit 1
fi

# validate pubspec exists before doing anything, so we never write config
# files or run builds against a non-Flutter directory
if [ ! -f "$ROOT/pubspec.yaml" ] && [ ! -f "$ROOT/app/pubspec.yaml" ]; then
  echo "release-kit: no pubspec.yaml found under $ROOT" >&2
  echo "  run from your Flutter project root, or pass -p <project-root>" >&2
  exit 1
fi

case "$cmd" in
  init)
    cd "$ROOT"
    cfg="release-kit.yaml"
    if [ ! -f "$cfg" ]; then
      cp "$KIT_ROOT/config.yaml" "$cfg"
      echo "==> created $cfg (edit it to match your app)"
    else
      echo "==> $cfg already exists, keeping it"
    fi
    exec "$KIT_ROOT/scripts/install_hook.sh"
    ;;
  publish)
    platform="$1"; shift || usage
    cd "$ROOT"
    # strip --no-icons and regenerate launcher icons from app.logo (if configured)
    NO_ICONS=0
    KEEP=""
    for a in "$@"; do
      case "$a" in
        --no-icons) NO_ICONS=1 ;;
        *) KEEP="$KEEP $a" ;;
      esac
    done
    # shellcheck disable=SC2086
    set -- $KEEP
    if [ "$NO_ICONS" = "0" ]; then
      "$KIT_ROOT/scripts/generate_icons.sh"
    else
      echo "==> --no-icons: skipping icon generation"
    fi
    case "$platform" in
      windows) powershell -ExecutionPolicy Bypass -File "$KIT_ROOT/scripts/publish_windows.ps1" "$@" ;;
      android) exec "$KIT_ROOT/scripts/publish_android.sh" "$@" ;;
      macos)   exec "$KIT_ROOT/scripts/publish_macos.sh" "$@" ;;
      linux)   exec "$KIT_ROOT/scripts/publish_linux.sh" "$@" ;;
      ios)     exec "$KIT_ROOT/scripts/publish_ios.sh" "$@" ;;
      *) echo "unknown platform: $platform" >&2; usage ;;
    esac
    ;;
  *) usage ;;
esac
