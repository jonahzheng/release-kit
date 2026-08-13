#!/bin/sh
# release-kit: publish Linux build (config-driven)
# Usage:
#   ./publish_linux.sh [--skip-build] [--appimage]
# Run from the Flutter project root (or app/ subdir in a monorepo).
#
# Produces a portable tar.gz from the release bundle. With --appimage,
# also builds an AppImage via linuxdeploy (must be installed; see
# https://github.com/linuxdeploy/linuxdeploy).

set -e
KIT_ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$KIT_ROOT/scripts/common.sh"

SKIP_BUILD=0
DO_APPIMAGE=0
for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    --appimage) DO_APPIMAGE=1 ;;
    *) echo "usage: $0 [--skip-build] [--appimage]" >&2; exit 2 ;;
  esac
done

PROJECT_ROOT=$(resolve_project)
cd "$PROJECT_ROOT"
CONFIG_FILE=$(cfg_file "$PROJECT_ROOT")

APP_NAME=$(cfg_get "app.name" "$CONFIG_FILE")
OUT_DIR=$(cfg_get "output.dir" "$CONFIG_FILE"); [ -z "$OUT_DIR" ] && OUT_DIR=dist
read_version "$PROJECT_ROOT/pubspec.yaml"
[ -z "$APP_NAME" ] && APP_NAME=$(basename "$PROJECT_ROOT")

echo "==> release-kit publish_linux"
echo "    project: $PROJECT_ROOT  app: $APP_NAME ($VERSION)"

if [ "$SKIP_BUILD" = "0" ]; then
  echo "==> flutter build linux --release"
  # shellcheck disable=SC2086
  flutter build linux --release $(dart_defines)
fi

BUNDLE="$PROJECT_ROOT/build/linux/x64/release/bundle"
if [ ! -d "$BUNDLE" ]; then
  echo "bundle not found: $BUNDLE" >&2
  exit 1
fi

mkdir -p "$PROJECT_ROOT/$OUT_DIR"
TGZ="$PROJECT_ROOT/$OUT_DIR/$APP_NAME-$VERSION-linux-x64.tar.gz"

tar -czf "$TGZ" -C "$(dirname "$BUNDLE")" "$(basename "$BUNDLE")"
print_artifact "$TGZ"

if [ "$DO_APPIMAGE" = "1" ]; then
  if ! command -v linuxdeploy >/dev/null 2>&1; then
    echo "release-kit: linuxdeploy not found on PATH (needed for --appimage)" >&2
    exit 1
  fi
  echo "==> building AppImage ..."
  linuxdeploy --appdir "$BUNDLE" -o appimage
  APPRUN="$PROJECT_ROOT/$OUT_DIR/$APP_NAME-$VERSION-linux-x86_64.AppImage"
  # linuxdeploy writes the AppImage next to the bundle; move it if present
  for f in "$(dirname "$BUNDLE")"/"$APP_NAME"*.AppImage; do
    if [ -f "$f" ]; then
      cp "$f" "$APPRUN"
      print_artifact "$APPRUN"
      break
    fi
  done
fi

echo "==> done"
