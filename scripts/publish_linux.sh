#!/bin/sh
# release-kit: publish Linux build (config-driven) — SKELETON
# Not yet verified on a Linux host; refine as needed.
# Usage: ./publish_linux.sh [--skip-build]
#
# Linux builds produce a self-contained bundle under
#   build/linux/x64/release/bundle
# Distribute as tar.gz (works everywhere) or AppImage (needs linuxdeploy).

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

echo "==> release-kit publish_linux (skeleton)"
echo "    project: $PROJECT_ROOT  app: $APP_NAME ($VERSION)"

if [ "$SKIP_BUILD" = "0" ]; then
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

# TODO(linux): tar.gz the bundle (portable), or build an AppImage with
#   linuxdeploy --appdir bundle -o appimage
tar -czf "$TGZ" -C "$(dirname "$BUNDLE")" "$(basename "$BUNDLE")"
print_artifact "$TGZ"
