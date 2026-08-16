#!/bin/sh
# release-kit: publish Linux build (config-driven)
# Usage:
#   ./publish_linux.sh [--skip-build] [--obfuscate] [--deb] [--rpm] [--appimage]
# Run from the Flutter project root (or app/ subdir in a monorepo).
#
# Always produces a portable tar.gz from the release bundle. Optional extras:
#   --deb        build a .deb (dpkg-deb) with desktop entry + icons
#   --rpm        build an .rpm (rpmbuild) with desktop entry + icons
#   --appimage   build an AppImage via linuxdeploy (see
#                https://github.com/linuxdeploy/linuxdeploy)
#   --skip-build reuse existing build outputs, just package artifacts
#   --obfuscate  Dart obfuscated build (symbols in build/obfuscate_symbols)

set -e
KIT_ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$KIT_ROOT/scripts/common.sh"

SKIP_BUILD=0
OBFUSCATE=0
DO_DEB=0
DO_RPM=0
DO_APPIMAGE=0
for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    --obfuscate) OBFUSCATE=1 ;;
    --deb) DO_DEB=1 ;;
    --rpm) DO_RPM=1 ;;
    --appimage) DO_APPIMAGE=1 ;;
    *) echo "usage: $0 [--skip-build] [--obfuscate] [--deb] [--rpm] [--appimage]" >&2; exit 2 ;;
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
echo "    obfuscate: $(if [ "$OBFUSCATE" = 1 ]; then printf 'on'; else printf 'off'; fi)"
echo "    packages: $(if [ "$DO_DEB" = 1 ]; then printf 'deb '; fi)$(if [ "$DO_RPM" = 1 ]; then printf 'rpm '; fi)$(if [ "$DO_APPIMAGE" = 1 ]; then printf 'appimage'; fi)"

if [ "$SKIP_BUILD" = "0" ]; then
  OBF_ARGS=""
  if [ "$OBFUSCATE" = "1" ]; then
    OBF_ARGS="--obfuscate --split-debug-info=./build/obfuscate_symbols"
  fi
  echo "==> flutter build linux --release"
  # shellcheck disable=SC2086
  flutter build linux --release $OBF_ARGS $(version_defines) $(dart_defines)
fi

BUNDLE="$PROJECT_ROOT/build/linux/x64/release/bundle"
if [ ! -d "$BUNDLE" ]; then
  echo "bundle not found: $BUNDLE" >&2
  exit 1
fi

# the executable name inside the bundle comes from the CMake BINARY_NAME
# (not app.name); locate it robustly
BIN_NAME=$(find "$BUNDLE" -maxdepth 1 -type f -perm -u+x -print 2>/dev/null | sed "s|^$BUNDLE/||" | head -n1)
if [ -z "$BIN_NAME" ]; then
  BIN_NAME=$(basename "$BUNDLE"/* 2>/dev/null | head -n1)
fi
BIN="$BUNDLE/$BIN_NAME"
if [ -z "$BIN_NAME" ] || [ ! -f "$BIN" ]; then
  echo "executable not found under $BUNDLE" >&2
  exit 1
fi

# lower-case + no-spaces package id for deb/rpm
PKG_ID=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')

mkdir -p "$PROJECT_ROOT/$OUT_DIR"
TGZ="$PROJECT_ROOT/$OUT_DIR/$APP_NAME-$VERSION-linux-x64.tar.gz"

tar -czf "$TGZ" -C "$(dirname "$BUNDLE")" "$(basename "$BUNDLE")"
print_artifact "$TGZ"

# --- .deb package (dpkg-deb) ---
if [ "$DO_DEB" = "1" ]; then
  if ! command -v dpkg-deb >/dev/null 2>&1; then
    echo "release-kit: dpkg-deb not found (needed for --deb)" >&2
    exit 1
  fi
  STAGE=$(mktemp -d)
  trap 'rm -rf "$STAGE"' EXIT
  mkdir -p "$STAGE/DEBIAN" "$STAGE/usr/bin" "$STAGE/usr/share/applications"
  cp "$BIN" "$STAGE/usr/bin/$BIN_NAME"

  DESKTOP_CATEGORIES=$(cfg_get "linux.desktopCategories" "$CONFIG_FILE")
  [ -z "$DESKTOP_CATEGORIES" ] && DESKTOP_CATEGORIES="Utility;"
  {
    echo "[Desktop Entry]"
    echo "Type=Application"
    echo "Name=$APP_NAME"
    echo "Comment=Release build of $APP_NAME"
    echo "Exec=$BIN_NAME"
    echo "Icon=$PKG_ID"
    echo "Terminal=false"
    echo "Categories=$DESKTOP_CATEGORIES"
  } > "$STAGE/usr/share/applications/$PKG_ID.desktop"

  # best available icon: linux/runner/my_icon.png (generated from app.logo)
  if [ -f "$PROJECT_ROOT/linux/runner/my_icon.png" ]; then
    mkdir -p "$STAGE/usr/share/icons/hicolor/512x512/apps"
    cp "$PROJECT_ROOT/linux/runner/my_icon.png" "$STAGE/usr/share/icons/hicolor/512x512/apps/$PKG_ID.png"
  fi

  SIZE=$(du -sk "$STAGE/usr" | awk '{print $1}')
  {
    echo "Package: $PKG_ID"
    echo "Version: $VERSION"
    echo "Section: utils"
    echo "Priority: optional"
    echo "Architecture: amd64"
    echo "Maintainer: release-kit <maintainer@localhost>"
    echo "Installed-Size: $SIZE"
    echo "Depends: libgtk-3-0, libstdc++6, libx11-6, libxcb1, libxext6, libxi6, libxkbcommon0, libgl1"
    echo "Description: $APP_NAME"
    echo " Release build of $APP_NAME (flutter linux)."
  } > "$STAGE/DEBIAN/control"

  DEB_OUT="$PROJECT_ROOT/$OUT_DIR/$APP_NAME-$VERSION-linux-x64.deb"
  dpkg-deb --build "$STAGE" "$DEB_OUT"
  rm -rf "$STAGE"
  trap - EXIT
  print_artifact "$DEB_OUT"
fi

# --- .rpm package (rpmbuild) ---
if [ "$DO_RPM" = "1" ]; then
  if ! command -v rpmbuild >/dev/null 2>&1; then
    echo "release-kit: rpmbuild not found (needed for --rpm)" >&2
    exit 1
  fi
  STAGE=$(mktemp -d)
  trap 'rm -rf "$STAGE"' EXIT
  mkdir -p "$STAGE/RPMS" "$STAGE/SOURCES" "$STAGE/SPECS" "$STAGE/BUILD" "$STAGE/BUILDROOT"
  mkdir -p "$STAGE/approot/usr/bin" "$STAGE/approot/usr/share/applications"

  cp "$BIN" "$STAGE/approot/usr/bin/$BIN_NAME"

  DESKTOP_CATEGORIES=$(cfg_get "linux.desktopCategories" "$CONFIG_FILE")
  [ -z "$DESKTOP_CATEGORIES" ] && DESKTOP_CATEGORIES="Utility;"
  {
    echo "[Desktop Entry]"
    echo "Type=Application"
    echo "Name=$APP_NAME"
    echo "Comment=Release build of $APP_NAME"
    echo "Exec=$BIN_NAME"
    echo "Icon=$PKG_ID"
    echo "Terminal=false"
    echo "Categories=$DESKTOP_CATEGORIES"
  } > "$STAGE/approot/usr/share/applications/$PKG_ID.desktop"

  if [ -f "$PROJECT_ROOT/linux/runner/my_icon.png" ]; then
    mkdir -p "$STAGE/approot/usr/share/icons/hicolor/512x512/apps"
    cp "$PROJECT_ROOT/linux/runner/my_icon.png" "$STAGE/approot/usr/share/icons/hicolor/512x512/apps/$PKG_ID.png"
  fi

  {
    echo "Name: $PKG_ID"
    echo "Version: $VERSION"
    echo "Release: 1"
    echo "Summary: $APP_NAME"
    echo "License: Proprietary"
    echo "BuildArch: x86_64"
    echo "Requires: libgtk-3.so.0()(64bit), libstdc++.so.6()(64bit)"
    echo ""
    echo "%description"
    echo "Release build of $APP_NAME (flutter linux)."
    echo ""
    echo "%files"
    echo "/usr/bin/$BIN_NAME"
    echo "/usr/share/applications/$PKG_ID.desktop"
    echo "%config /usr/share/icons/hicolor/512x512/apps/$PKG_ID.png"
  } > "$STAGE/SPECS/$PKG_ID.spec"

  # shellcheck disable=SC2086
  rpmbuild --define "_topdir $STAGE" --buildroot "$STAGE/approot" \
    -bb "$STAGE/SPECS/$PKG_ID.spec"
  RPM_FILE=$(find "$STAGE/RPMS" -name "*.rpm" -print 2>/dev/null | head -n1)
  if [ -z "$RPM_FILE" ]; then
    echo "rpmbuild produced no rpm" >&2
    exit 1
  fi
  RPM_OUT="$PROJECT_ROOT/$OUT_DIR/$APP_NAME-$VERSION-linux-x64.rpm"
  cp "$RPM_FILE" "$RPM_OUT"
  rm -rf "$STAGE"
  trap - EXIT
  print_artifact "$RPM_OUT"
fi

# --- AppImage (linuxdeploy) ---
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
