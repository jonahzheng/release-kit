#!/bin/sh
# release-kit: publish macOS build (config-driven)
# Usage:
#   ./publish_macos.sh [--skip-build]
# Run from the Flutter project root (or app/ subdir in a monorepo).
#
# Produces a distributable .dmg: stages the .app alongside an Applications
# symlink (drag-to-install) and compresses with hdiutil (UDZO).
#
# Note: macOS release builds need code signing config (Developer ID) for
# distribution; without it the .app runs locally only.

set -e
KIT_ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$KIT_ROOT/scripts/common.sh"

SKIP_BUILD=0
[ "$1" = "--skip-build" ] && SKIP_BUILD=1

PROJECT_ROOT=$(resolve_project)
cd "$PROJECT_ROOT"
CONFIG_FILE=$(cfg_file "$PROJECT_ROOT")

APP_NAME=$(cfg_get "app.name" "$CONFIG_FILE")
OUT_DIR=$(cfg_get "output.dir" "$CONFIG_FILE"); [ -z "$OUT_DIR" ] && OUT_DIR=dist
read_version "$PROJECT_ROOT/pubspec.yaml"
[ -z "$APP_NAME" ] && APP_NAME=$(basename "$PROJECT_ROOT")

echo "==> release-kit publish_macos"
echo "    project: $PROJECT_ROOT  app: $APP_NAME ($VERSION)"

if [ "$SKIP_BUILD" = "0" ]; then
  echo "==> flutter build macos --release"
  # shellcheck disable=SC2086
  flutter build macos --release $(dart_defines)
fi

APP_BUNDLE="$PROJECT_ROOT/build/macos/Build/Products/Release/$APP_NAME.app"
if [ ! -d "$APP_BUNDLE" ]; then
  echo "app bundle not found: $APP_BUNDLE" >&2
  exit 1
fi

mkdir -p "$PROJECT_ROOT/$OUT_DIR"
DMG_OUT="$PROJECT_ROOT/$OUT_DIR/$APP_NAME-$VERSION-macos.dmg"

# --- package .app into a drag-to-install .dmg ---
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP_BUNDLE" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# UDZO zlib compression, store as UDIF (classic HFS+ read-write fallback)
if ! hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" \
     -ov -format UDZO "$DMG_OUT"; then
  echo "hdiutil create failed (DMG may be unsupported in this environment)" >&2
  exit 1
fi
rm -rf "$STAGE"
trap - EXIT

print_artifact "$DMG_OUT"
echo "==> done"
