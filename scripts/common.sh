#!/bin/sh
# release-kit common helpers for publish_*.sh
# Source this from a publish script: . "$(dirname "$0")/common.sh"

# --- locate release-kit root ---
# Use BASH_SOURCE so sourcing from another script works regardless of cwd.
_common_dir=$(CDPATH= cd -- "$(dirname "${BASH_SOURCE:-$0}")" && pwd)
KIT_ROOT=$(CDPATH= cd -- "$_common_dir/.." && pwd)

# --- parse config.yaml (flat key: value, dot-namespace) ---
# usage: cfg_get <key>  -> echoes value (or empty)
cfg_get() {
  local key="$1" line value
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
  done < "$KIT_ROOT/config.yaml"
  return 1
}

# --- resolve app dir (project root of the consuming app) ---
# The publish script is invoked from the app's repo root.
resolve_project() {
  PROJECT_ROOT=$(pwd)
  # If there's a pubspec.yaml in a subdir (monorepo like ZShell), the caller
  # should cd into it first; otherwise assume cwd.
  if [ -f "$PROJECT_ROOT/pubspec.yaml" ]; then
    echo "$PROJECT_ROOT"
  elif [ -f "$PROJECT_ROOT/app/pubspec.yaml" ]; then
    echo "$PROJECT_ROOT/app"
  else
    echo "$PROJECT_ROOT"
  fi
}

# --- read version from pubspec.yaml ---
# usage: read_version <pubspec> -> sets VERSION (x.y.z) and VERSION_CODE (int)
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
  local key value
  while IFS= read -r key; do
    value=$(cfg_get "build.dartDefine.$key" 2>/dev/null)
    if [ -n "$value" ]; then
      printf '%s' " --dart-define=$key=$value"
    fi
  done < <(grep -oE '^build\.dartDefine\.[A-Za-z0-9_]+:' "$KIT_ROOT/config.yaml" | sed 's/^build.dartDefine.//; s/:$//')
}

print_artifact() {
  local f="$1"
  echo "==> artifact: $f"
  echo "    size: $(wc -c < "$f") bytes"
  echo "    sha256: $(sha256_file "$f")"
}
