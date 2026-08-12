#!/bin/sh
# release-kit: unified CLI entry (macOS/Linux)
# Usage:
#   ./release-kit.sh init                       # copy config template + install hook
#   ./release-kit.sh install                    # install hook only
#   ./release-kit.sh publish <platform> [args]  # windows|android|macos|linux|ios
#   ./release-kit.sh bump [--build-only]        # manually bump version
#
# All commands run against the current directory. To target another project
# from anywhere, pass -p <project-root> to publish/install.
set -e

KIT_ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

usage() {
  cat <<'EOF'
release-kit <command>

  init                        copy config template (release-kit.yaml) + install hook
  install                     install version-bump pre-commit hook
  publish <platform> [args]   build & package (windows|android|macos|linux|ios)
                              optional: -p <project-root> to target another project
  bump [--build-only]         manually bump pubspec version
EOF
  exit 1
}

# strip -p/--project out of "$@" and print the remaining args
# (PROJECT_ARG is set as a side effect)
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
  echo "$KEEP"
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
    # shellcheck disable=SC2046
    set -- $(extract_project "$@")
    if [ -n "$PROJECT_ARG" ]; then
      cd "$PROJECT_ARG" || { echo "cannot cd to $PROJECT_ARG" >&2; exit 1; }
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
  bump)
    exec dart run "$KIT_ROOT/bin/bump_version.dart" "$@"
    ;;
  *) usage ;;
esac
