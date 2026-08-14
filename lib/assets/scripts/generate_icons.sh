#!/bin/sh
# release-kit: generate platform launcher icons from a single source image
#
# Reads `app.logo` from the resolved config (release-kit.yaml > config.yaml
# > tool default). If unset or the file is missing, prints a warning and
# exits 0 (icons are optional). Otherwise drives flutter_launcher_icons to
# regenerate icons for the target platform only (or all, if none given).
#
# Usage: ./generate_icons.sh [-p <platform>]  (windows|android|ios|macos|linux|all)
set -e

KIT_ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$KIT_ROOT/scripts/common.sh"

PLATFORM="all"
while [ $# -gt 0 ]; do
  case "$1" in
    -p) PLATFORM="$2"; shift 2 ;;
    *) echo "usage: $0 [-p <platform>]" >&2; exit 2 ;;
  esac
done

PROJECT_ROOT=$(resolve_project)
CONFIG_FILE=$(cfg_file "$PROJECT_ROOT")

LOGO=$(cfg_get "app.logo" "$CONFIG_FILE")
if [ -z "$LOGO" ]; then
  echo "==> app.logo not set in config - skipping icon generation"
  exit 0
fi

cd "$PROJECT_ROOT"
if [ ! -f "$LOGO" ]; then
  echo "release-kit: app.logo not found: $LOGO" >&2
  echo "  fix the path in your config, or remove app.logo to skip icons" >&2
  exit 1
fi

# skip if icons are already newer than the source logo (nothing changed)
NEED_GEN=0
for ic in \
  "windows/runner/resources/app_icon.ico" \
  "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" \
  "ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json" \
  "macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json" \
  "linux/runner/my_icon.png"; do
  case "$PLATFORM" in
    all) ;;
    windows) case "$ic" in windows/*) ;; *) continue ;; esac ;;
    android) case "$ic" in android/*) ;; *) continue ;; esac ;;
    ios)     case "$ic" in ios/*)     ;; *) continue ;; esac ;;
    macos)   case "$ic" in macos/*)   ;; *) continue ;; esac ;;
    linux)   case "$ic" in linux/*)   ;; *) continue ;; esac ;;
    *) continue ;;
  esac
  if [ ! -f "$ic" ]; then NEED_GEN=1; break; fi
  if [ "$LOGO" -nt "$ic" ]; then NEED_GEN=1; break; fi
done
if [ "$NEED_GEN" = "0" ]; then
  echo "==> icons already up to date (newer than $LOGO) - skipping"
  exit 0
fi

# --- Linux window icon ---
# flutter_launcher_icons has no Linux target; the Flutter Linux runner reads
# its window icon from linux/runner/my_icon.png. Resize the source logo with
# ImageMagick when available, otherwise copy it as-is.
if [ "$PLATFORM" = "all" ] || [ "$PLATFORM" = "linux" ]; then
  mkdir -p "$PROJECT_ROOT/linux/runner"
  LINUX_ICON="$PROJECT_ROOT/linux/runner/my_icon.png"
  if command -v magick >/dev/null 2>&1; then
    echo "==> linux icon: $LINUX_ICON (magick 512x512)"
    magick "$LOGO" -resize 512x512 "$LINUX_ICON"
  elif command -v convert >/dev/null 2>&1 && convert -version 2>/dev/null | grep -qi imagemagick; then
    echo "==> linux icon: $LINUX_ICON (convert 512x512)"
    convert "$LOGO" -resize 512x512 "$LINUX_ICON"
  else
    echo "==> linux icon: $LINUX_ICON (copied as-is, no ImageMagick found)"
    cp "$LOGO" "$LINUX_ICON"
  fi
  if [ "$PLATFORM" = "linux" ]; then
    echo "==> icons regenerated"
    exit 0
  fi
fi

# ensure flutter_launcher_icons is available as a dev dependency
if ! grep -q 'flutter_launcher_icons' pubspec.yaml; then
  echo "==> adding flutter_launcher_icons dev dependency..."
  flutter pub add --dev flutter_launcher_icons
fi

FLIC="flutter_launcher_icons.yaml"

# top-level key differs by package version: 0.11 uses "flutter_icons",
# 0.14+ uses "flutter_launcher_icons". Detect from pubspec.lock.
VER=""
if [ -f pubspec.lock ]; then
  VER=$(awk '/flutter_launcher_icons:/{f=1} f && /version:/{print; exit}' pubspec.lock | sed 's/.*version: "\([0-9.]*\)".*/\1/')
fi
TOP_KEY="flutter_launcher_icons"
case "$VER" in
  0.1[01]*) TOP_KEY="flutter_icons" ;;
esac
echo "==> flutter_launcher_icons $VER (config key: $TOP_KEY)  target: $PLATFORM"

# build config for the target platform only
{
  echo "$TOP_KEY:"
  if [ "$PLATFORM" = "all" ] || [ "$PLATFORM" = "android" ]; then
    echo "  android: true"
  else
    echo "  android: false"
  fi
  if [ "$PLATFORM" = "all" ] || [ "$PLATFORM" = "ios" ]; then
    echo "  ios: true"
  else
    echo "  ios: false"
  fi
  echo "  image_path: \"$LOGO\""
  if [ "$PLATFORM" = "all" ] || [ "$PLATFORM" = "windows" ]; then
    echo "  windows:"
    echo "    generate: true"
    echo "    image_path: \"$LOGO\""
    echo "    icon_size: 256"
  fi
  if [ "$PLATFORM" = "all" ] || [ "$PLATFORM" = "macos" ]; then
    echo "  macos:"
    echo "    generate: true"
    echo "    image_path: \"$LOGO\""
  fi
} > "$FLIC"

echo "==> generating icons from $LOGO ..."
dart run flutter_launcher_icons -f "$FLIC"
rm -f "$FLIC"
echo "==> icons regenerated"
