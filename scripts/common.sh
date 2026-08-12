#!/bin/sh
# release-kit common helpers for publish_*.sh
# Source this from a publish script: . "$(dirname "$0")/common.sh"

# --- locate release-kit root ---
# Use BASH_SOURCE so sourcing from another script works regardless of cwd.
_common_dir=$(CDPATH= cd -- "$(dirname "${BASH_SOURCE:-$0}")" && pwd)
KIT_ROOT=$(CDPATH= cd -- "$_common_dir/.." && pwd)

# --- resolve config file ---
# Project-local config wins over the tool default:
#   <project>/release-kit.yaml  (recommended, keep config in your repo)
#   <project>/config.yaml       (alternative)
#   <repo-root>/release-kit.yaml, <repo-root>/config.yaml   (monorepo: project is app/)
#   $KIT_ROOT/config.yaml       (tool default)
# usage: cfg_file <project_root> -> echoes path (or empty)
cfg_file() {
  local proj="$1" dir
  for dir in "$proj" "$proj/.."; do
    if [ -f "$dir/release-kit.yaml" ]; then
      echo "$dir/release-kit.yaml"; return 0
    fi
    if [ -f "$dir/config.yaml" ]; then
      echo "$dir/config.yaml"; return 0
    fi
  done
  if [ -f "$KIT_ROOT/config.yaml" ]; then
    echo "$KIT_ROOT/config.yaml"
  fi
}

# --- parse config.yaml (flat key: value, dot-namespace) ---
# usage: cfg_get <key> [<config-file>]  -> echoes value (or empty)
# Always returns 0 so that `set -e` scripts can safely do: V=$(cfg_get ...)
cfg_get() {
  local key="$1" line value cfg
  if [ -n "$2" ]; then
    cfg="$2"
  else
    cfg=$(cfg_file "$PROJECT_ROOT")
  fi
  if [ -z "$cfg" ] || [ ! -f "$cfg" ]; then
    return 0
  fi
  while IFS= read -r line; do
    # strip comments and blanks
    case "$line" in
      ''|'#'*) continue ;;
    esac
    case "$line" in
      "$key":*)
        value="${line#"$key":}"
        # trim leading/trailing spaces
        value=$(echo "$value" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        echo "$value"
        return 0
        ;;
    esac
  done < "$cfg"
  return 0
}

# --- resolve app dir (project root of the consuming app) ---
# The publish script is invoked from the app's repo root.
# Exits with a clear error if no pubspec.yaml is found.
resolve_project() {
  PROJECT_ROOT=$(pwd)
  if [ -f "$PROJECT_ROOT/pubspec.yaml" ]; then
    echo "$PROJECT_ROOT"
  elif [ -f "$PROJECT_ROOT/app/pubspec.yaml" ]; then
    echo "$PROJECT_ROOT/app"
  else
    echo "release-kit: no pubspec.yaml found under $PROJECT_ROOT" >&2
    echo "  run from your Flutter project root, or pass -p <project-root>" >&2
    exit 1
  fi
}

# --- read version from pubspec.yaml ---
# usage: read_version <pubspec> -> sets VERSION (x.y.z) and VERSION_CODE (int)
# Exits with a clear error if the version cannot be parsed.
read_version() {
  local pubspec="$1" content
  content=$(cat "$pubspec")
  VERSION=$(echo "$content" | sed -n 's/^version:[[:space:]]*\([0-9]*\.[0-9]*\.[0-9]*\)+[0-9]*/\1/p' | head -n1)
  local build
  build=$(echo "$content" | sed -n 's/^version:[[:space:]]*\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)+\([0-9]*\)/\4/p' | head -n1)
  local major minor patch
  major=$(echo "$content" | sed -n 's/^version:[[:space:]]*\([0-9]*\)\..*/\1/p' | head -n1)
  minor=$(echo "$content" | sed -n 's/^version:[[:space:]]*[0-9]*\.\([0-9]*\)\..*/\1/p' | head -n1)
  patch=$(echo "$content" | sed -n 's/^version:[[:space:]]*[0-9]*\.[0-9]*\.\([0-9]*\)+.*/\1/p' | head -n1)
  if [ -z "$VERSION" ]; then
    echo "release-kit: cannot parse version from $pubspec" >&2
    echo "  expected a line like: version: 0.1.0+1" >&2
    exit 1
  fi
  [ -z "$build" ] && build=0
  VERSION_CODE=$((major * 1000000 + minor * 10000 + patch * 100 + build))
}

# --- sha256 of a file ---
sha256_file() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | awk '{print $1}'
  else
    echo "sha256sum not found" >&2
    return 1
  fi
}

# --- dart-define args from config (build.dartDefine.*) ---
# usage: dart_defines -> echoes "-Dkey=value ..."
dart_defines() {
  local key value cfg
  cfg=$(cfg_file "$PROJECT_ROOT")
  [ -n "$cfg" ] || return 0
  grep -oE '^build\.dartDefine\.[A-Za-z0-9_]+:' "$cfg" | sed 's/^build.dartDefine.//; s/:$//' | while IFS= read -r key; do
    value=$(cfg_get "build.dartDefine.$key" "$cfg")
    if [ -n "$value" ]; then
      printf '%s' " --dart-define=$key=$value"
    fi
  done
}

print_artifact() {
  local f="$1"
  echo "==> artifact: $f"
  echo "    size: $(wc -c < "$f") bytes"
  echo "    sha256: $(sha256_file "$f")"
}
