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
        # strip trailing inline comment (" #...")
        value=$(echo "$value" | sed 's/[[:space:]]*#.*$//')
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
# usage: read_version <pubspec> -> sets VERSION (x.y.z), VERSION_BUILD (int),
# VERSION_FULL (x.y.z+build) and VERSION_CODE (int).
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
  VERSION_BUILD=$build
  VERSION_FULL="$VERSION+$build"
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

# --- auto version defines from pubspec (call read_version first) ---
# Injected into every build so apps can read their real version at runtime:
#   const appVersion = String.fromEnvironment('APP_VERSION');
#   const appBuild   = String.fromEnvironment('APP_BUILD');
version_defines() {
  printf '%s' "--dart-define=APP_VERSION=$VERSION --dart-define=APP_BUILD=$VERSION_BUILD"
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

# --- versioned changelog for the published build ---
# write_changelog: emits <OUT_DIR>/CHANGELOG-<VERSION_FULL>.md
#   - preferred: the current version's section from the project's CHANGELOG.md
#     (Keep a Changelog: `## [x.y.z] - date` + `### Added/Changed/Fixed`)
#   - fallback:  git log since the last tag, grouped by conventional-commit type
# Requires VERSION, VERSION_FULL, APP_NAME, PROJECT_ROOT, OUT_DIR.
write_changelog() {
  local changelog="" out
  if [ -f "$PROJECT_ROOT/CHANGELOG.md" ]; then
    changelog="$PROJECT_ROOT/CHANGELOG.md"
  elif [ -f "$PROJECT_ROOT/../CHANGELOG.md" ]; then
    changelog="$PROJECT_ROOT/../CHANGELOG.md"
  fi

  mkdir -p "$PROJECT_ROOT/$OUT_DIR"
  out="$PROJECT_ROOT/$OUT_DIR/CHANGELOG-$VERSION_FULL.md"
  {
    echo "# $APP_NAME $VERSION_FULL"
    echo ""
  } > "$out"

  if [ -n "$changelog" ] && extract_version_section "$VERSION" "$changelog" >> "$out"; then
    :
  else
    git_changelog >> "$out"
  fi
  echo "==> changelog: $out"
}

# Prints the section for [ver] from a Keep-a-Changelog CHANGELOG.md
# (from the matching `## [ver]` header up to the next `## ` header, inclusive
# of the matching header). Returns 0 only when a section was found.
extract_version_section() {
  awk -v ver="$1" '
    /^## / {
      h = $0
      sub(/^## */, "", h)
      sub(/^\[/, "", h)
      sub(/\].*$/, "", h)
      sub(/[ -].*$/, "", h)
      if (h == ver) { print; found = 1; next }
      if (found) exit
    }
    found { print }
    END { exit !found }
  ' "$2"
}

# Generates a changelog from the git log (last tag .. HEAD) grouped into
# Keep-a-Changelog categories from conventional-commit prefixes.
git_changelog() {
  local range="" tag dir
  if git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    tag=$(git -C "$PROJECT_ROOT" describe --tags --abbrev=0 2>/dev/null || true)
    [ -n "$tag" ] && range="$tag..HEAD"
  fi

  dir=$(mktemp -d)
  : > "$dir/added"
  : > "$dir/changed"
  : > "$dir/fixed"

  if [ -n "$range" ]; then
    git -C "$PROJECT_ROOT" log "$range" --pretty=tformat:'%s' 2>/dev/null
  else
    git -C "$PROJECT_ROOT" log --pretty=tformat:'%s' 2>/dev/null
  fi | while IFS= read -r subject; do
    [ -z "$subject" ] && continue
    case "$subject" in
      feat:*|add:*|Add:*)
        printf '%s\n' "$subject" | sed 's/^[^:]*:[[:space:]]*/- /' >> "$dir/added" ;;
      fix:*|Fix:*)
        printf '%s\n' "$subject" | sed 's/^[^:]*:[[:space:]]*/- /' >> "$dir/fixed" ;;
      *)
        printf -- '- %s\n' "$subject" >> "$dir/changed" ;;
    esac
  done

  echo "## [$VERSION] - $(date +%Y-%m-%d)"
  echo ""
  if [ -s "$dir/added" ]; then
    echo "### Added"
    echo ""
    cat "$dir/added"
    echo ""
  fi
  if [ -s "$dir/changed" ]; then
    echo "### Changed"
    echo ""
    cat "$dir/changed"
    echo ""
  fi
  if [ -s "$dir/fixed" ]; then
    echo "### Fixed"
    echo ""
    cat "$dir/fixed"
    echo ""
  fi
  if [ ! -s "$dir/added" ] && [ ! -s "$dir/changed" ] && [ ! -s "$dir/fixed" ]; then
    echo "- Initial release of $VERSION_FULL."
  fi
  rm -rf "$dir"
}
