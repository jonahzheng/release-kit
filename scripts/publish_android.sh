#!/bin/sh
# release-kit: publish Android build (config-driven)
# Usage:
#   ./publish_android.sh [--apk] [--aab] [--skip-build]
# Run from the Flutter project root (or app/ subdir in a monorepo).
# Secrets: ANDROID_KEY_PASSWORD / ANDROID_STORE_PASSWORD env vars.

set -e
KIT_ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$KIT_ROOT/scripts/common.sh"

DO_APK=0
DO_AAB=1
SKIP_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --apk) DO_APK=1 ;;
    --aab) DO_AAB=1 ;;
    --skip-build) SKIP_BUILD=1 ;;
    *) echo "usage: $0 [--apk] [--aab] [--skip-build]" >&2; exit 2 ;;
  esac
done

APP_NAME=$(cfg_get "app.name")
BUNDLE_ID=$(cfg_get "app.bundleId")
OUT_DIR=$(cfg_get "output.dir"); [ -z "$OUT_DIR" ] && OUT_DIR=dist
KEYSTORE=$(cfg_get "android.keystore")
KEY_ALIAS=$(cfg_get "android.keyAlias")
KEY_PASS="${ANDROID_KEY_PASSWORD:-}"
STORE_PASS="${ANDROID_STORE_PASSWORD:-}"

PROJECT_ROOT=$(resolve_project)
cd "$PROJECT_ROOT"

PUBSPEC="$PROJECT_ROOT/pubspec.yaml"
read_version "$PUBSPEC"
[ -z "$APP_NAME" ] && APP_NAME=$(basename "$PROJECT_ROOT")

echo "==> release-kit publish_android"
echo "    project: $PROJECT_ROOT"
echo "    app: $APP_NAME ($VERSION)  bundle: $BUNDLE_ID"

DEFINES=$(dart_defines)

if [ "$SKIP_BUILD" = "0" ]; then
  echo "==> flutter build apk --release"
  # shellcheck disable=SC2086
  flutter build apk --release $DEFINES
  if [ "$DO_AAB" = "1" ]; then
    echo "==> flutter build appbundle --release"
    # shellcheck disable=SC2086
    flutter build appbundle --release $DEFINES
  fi
fi

APK_DIR="$PROJECT_ROOT/build/app/outputs/flutter-apk"
mkdir -p "$PROJECT_ROOT/$OUT_DIR"

if [ "$DO_APK" = "1" ] || [ "$SKIP_BUILD" = "1" ]; then
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
