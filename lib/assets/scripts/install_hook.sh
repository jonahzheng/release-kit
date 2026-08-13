#!/bin/sh
# release-kit: install pre-commit hook + core.hooksPath (macOS/Linux)
# Usage: ./install_hook.sh [-p <project-root>]
set -e

KIT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PROJECT_ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    -p|--project) PROJECT_ROOT="$2"; shift 2 ;;
    *) echo "usage: $0 [-p <project-root>]" >&2; exit 2 ;;
  esac
done
[ -z "$PROJECT_ROOT" ] && PROJECT_ROOT=$(pwd)

echo "==> release-kit: $KIT_ROOT"
echo "==> project root: $PROJECT_ROOT"

# Detect pubspec location
if [ -f "$PROJECT_ROOT/app/pubspec.yaml" ]; then
  PUBSPEC="app/pubspec.yaml"
elif [ -f "$PROJECT_ROOT/pubspec.yaml" ]; then
  PUBSPEC="pubspec.yaml"
else
  echo "No pubspec.yaml found under $PROJECT_ROOT" >&2
  exit 1
fi

PUBSPEC_ABS="$PROJECT_ROOT/$PUBSPEC"
# KIT_ROOT = lib/assets (scripts/..); package root = KIT_ROOT/..
BUMP_ABS="$KIT_ROOT/../bin/bump_version.dart"

mkdir -p "$PROJECT_ROOT/.githooks"

sed -e "s|{SMART_BUMP_PATH}|$BUMP_ABS|g" \
    -e "s|{PUBSPEC_PATH}|$PUBSPEC_ABS|g" \
    -e "s|{REPO_ROOT}|$PROJECT_ROOT|g" \
    "$KIT_ROOT/pre-commit.hook" > "$PROJECT_ROOT/.githooks/pre-commit"
chmod +x "$PROJECT_ROOT/.githooks/pre-commit"
echo "==> hook written: $PROJECT_ROOT/.githooks/pre-commit"

(cd "$PROJECT_ROOT" && git config core.hooksPath ".githooks")
echo "==> core.hooksPath set to .githooks"
echo "Done. Skip bump with: git commit --no-verify"
