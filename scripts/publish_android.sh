#!/bin/sh
# release-kit: publish Android build (config-driven)
# Usage:
#   ./publish_android.sh [--apk] [--aab] [--skip-build] [--obfuscate]
# Run from the Flutter project root (or app/ subdir in a monorepo).
# Secrets: ANDROID_KEY_PASSWORD / ANDROID_STORE_PASSWORD env vars.
#
# Flags:
#   default     build & collect APK + AAB
#   --apk       only APK   (turns off AAB)
#   --aab       only AAB   (turns off APK)
#   --skip-build  reuse existing build outputs, just collect artifacts
#   --obfuscate   Dart obfuscated build (symbols in build/obfuscate_symbols)

set -e
KIT_ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$KIT_ROOT/scripts/common.sh"

DO_APK=1
DO_AAB=1
SAW_APK=0
SAW_AAB=0
SKIP_BUILD=0
OBFUSCATE=0
for arg in "$@"; do
  case "$arg" in
    --apk) DO_APK=1; SAW_APK=1 ;;
    --aab) DO_AAB=1; SAW_AAB=1 ;;
    --skip-build) SKIP_BUILD=1 ;;
    --obfuscate) OBFUSCATE=1 ;;
    *) echo "usage: $0 [--apk] [--aab] [--skip-build] [--obfuscate]" >&2; exit 2 ;;
  esac
done
# "--apk" alone means APK only; "--aab" alone means AAB only; both given = both
if [ "$SAW_APK" = "1" ] && [ "$SAW_AAB" = "0" ]; then DO_AAB=0; fi
if [ "$SAW_AAB" = "1" ] && [ "$SAW_APK" = "0" ]; then DO_APK=0; fi

PROJECT_ROOT=$(resolve_project)
cd "$PROJECT_ROOT"
CONFIG_FILE=$(cfg_file "$PROJECT_ROOT")

APP_NAME=$(cfg_get "app.name" "$CONFIG_FILE")
BUNDLE_ID=$(cfg_get "app.bundleId" "$CONFIG_FILE")
OUT_DIR=$(cfg_get "output.dir" "$CONFIG_FILE"); [ -z "$OUT_DIR" ] && OUT_DIR=dist
KEYSTORE=$(cfg_get "android.keystore" "$CONFIG_FILE")
KEY_ALIAS=$(cfg_get "android.keyAlias" "$CONFIG_FILE")
KEY_PASS="${ANDROID_KEY_PASSWORD:-}"
STORE_PASS="${ANDROID_STORE_PASSWORD:-}"

PUBSPEC="$PROJECT_ROOT/pubspec.yaml"
read_version "$PUBSPEC"
[ -z "$APP_NAME" ] && APP_NAME=$(basename "$PROJECT_ROOT")

echo "==> release-kit publish_android"
echo "    project: $PROJECT_ROOT"
echo "    app: $APP_NAME ($VERSION)  bundle: $BUNDLE_ID"
echo "    targets: $(if [ "$DO_APK" = 1 ]; then printf 'apk '; fi)$(if [ "$DO_AAB" = 1 ]; then printf 'aab'; fi)  obfuscate: $(if [ "$OBFUSCATE" = 1 ]; then printf 'on'; else printf 'off'; fi)"

DEFINES=$(dart_defines)
OBF_ARGS=""
if [ "$OBFUSCATE" = "1" ]; then
  OBF_ARGS="--obfuscate --split-debug-info=./build/obfuscate_symbols"
fi

if [ "$SKIP_BUILD" = "0" ]; then
  if [ "$DO_APK" = "1" ]; then
    echo "==> flutter build apk --release"
    # shellcheck disable=SC2086
    flutter build apk --release $OBF_ARGS $DEFINES
  fi
  if [ "$DO_AAB" = "1" ]; then
    echo "==> flutter build appbundle --release"
    # shellcheck disable=SC2086
    flutter build appbundle --release $OBF_ARGS $DEFINES
  fi
fi

APK_DIR="$PROJECT_ROOT/build/app/outputs/flutter-apk"
mkdir -p "$PROJECT_ROOT/$OUT_DIR"

if [ "$DO_APK" = "1" ]; then
  if [ -f "$APK_DIR/app-release.apk" ]; then
    APK_OUT="$PROJECT_ROOT/$OUT_DIR/$APP_NAME-$VERSION-android.apk"
    cp "$APK_DIR/app-release.apk" "$APK_OUT"
    print_artifact "$APK_OUT"
  fi
fi

if [ "$DO_AAB" = "1" ]; then
  if [ -f "$APK_DIR/app-release.aab" ]; then
    AAB_OUT="$PROJECT_ROOT/$OUT_DIR/$APP_NAME-$VERSION-android.aab"
    cp "$APK_DIR/app-release.aab" "$AAB_OUT"
    print_artifact "$AAB_OUT"
  fi
fi

echo "==> done"
