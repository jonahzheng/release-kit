#!/bin/sh
# release-kit: publish macOS build (config-driven)
# Usage:
#   ./publish_macos.sh [--skip-build] [--obfuscate]
# Run from the Flutter project root (or app/ subdir in a monorepo).
#
# Produces a distributable .dmg: stages the .app alongside an Applications
# symlink (drag-to-install) and compresses with hdiutil (UDZO).
#
# Note: macOS release builds need code signing config (Developer ID) for
# distribution; without it the .app runs locally only. There is no
# --no-codesign flag for `flutter build macos`.
#
# Flags:
#   --skip-build   reuse existing build outputs, just package the .app into a .dmg
#   --obfuscate    Dart obfuscated build (symbols in build/obfuscate_symbols)

set -e
KIT_ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$KIT_ROOT/scripts/common.sh"

SKIP_BUILD=0
OBFUSCATE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --skip-build) SKIP_BUILD=1; shift ;;
    --obfuscate) OBFUSCATE=1; shift ;;
    *) echo "usage: $0 [--skip-build] [--obfuscate]" >&2; exit 2 ;;
  esac
done

PROJECT_ROOT=$(resolve_project)
cd "$PROJECT_ROOT"
CONFIG_FILE=$(cfg_file "$PROJECT_ROOT")

APP_NAME=$(cfg_get "app.name" "$CONFIG_FILE")
OUT_DIR=$(cfg_get "output.dir" "$CONFIG_FILE"); [ -z "$OUT_DIR" ] && OUT_DIR=dist
read_version "$PROJECT_ROOT/pubspec.yaml"
[ -z "$APP_NAME" ] && APP_NAME=$(basename "$PROJECT_ROOT")

echo "==> release-kit publish_macos"
echo "    project: $PROJECT_ROOT  app: $APP_NAME ($VERSION_FULL)"
echo "    obfuscate: $(if [ "$OBFUSCATE" = 1 ]; then printf 'on'; else printf 'off'; fi)"

if [ "$SKIP_BUILD" = "0" ]; then
  OBF_ARGS=""
  if [ "$OBFUSCATE" = "1" ]; then
    OBF_ARGS="--obfuscate --split-debug-info=./build/obfuscate_symbols"
  fi
  echo "==> flutter build macos --release"
  # shellcheck disable=SC2086
  flutter build macos --release $OBF_ARGS $(version_defines) $(dart_defines)
fi

# the .app name comes from the Xcode product name (not app.name), locate robustly
APP_BUNDLE=$(find "$PROJECT_ROOT/build/macos/Build/Products/Release" -maxdepth 1 -name "*.app" -print 2>/dev/null | sort | tail -n1)
if [ -z "$APP_BUNDLE" ] || [ ! -d "$APP_BUNDLE" ]; then
  echo "app bundle not found under $PROJECT_ROOT/build/macos/Build/Products/Release" >&2
  exit 1
fi

mkdir -p "$PROJECT_ROOT/$OUT_DIR"
DMG_OUT="$PROJECT_ROOT/$OUT_DIR/$APP_NAME-$VERSION_FULL-macos.dmg"

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

# Also emit an auto-update .zip from the very same .app. In-app updates download
# this zip, strip the single top-level <AppName>.app/ entry, and replace the
# running app's Contents (ZShell's update_controller + updater.sh). Keeping
# --keepParent makes the .app the sole top-level dir so the client strips
# exactly one level to reveal Contents/.
ZIP_OUT="$PROJECT_ROOT/$OUT_DIR/$APP_NAME-$VERSION_FULL-macos.zip"
rm -f "$ZIP_OUT"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_OUT"
print_artifact "$ZIP_OUT"

echo "==> done"
