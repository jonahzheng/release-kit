#!/bin/sh
# release-kit: publish iOS build (config-driven)
# Usage:
#   ./publish_ios.sh [--skip-build] [--obfuscate] [--export-method <method>] [--no-codesign]
# Run from the Flutter project root (or app/ subdir in a monorepo).
#
# Requires:
#   - macOS + Xcode + iOS signing (Apple Developer cert/profile)
#   - Produces an .ipa for distribution (TestFlight / App Store).
#
# Flags:
#   --skip-build               reuse existing build outputs, just collect the .ipa
#   --obfuscate                Dart obfuscated build (symbols in build/obfuscate_symbols)
#   --export-method <method>   ad-hoc | development | enterprise | app-store (default: app-store)
#   --no-codesign              build without code signing (CI / local smoke test)

set -e
KIT_ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$KIT_ROOT/scripts/common.sh"

SKIP_BUILD=0
OBFUSCATE=0
NO_CODESIGN=0
EXPORT_METHOD=""
while [ $# -gt 0 ]; do
  case "$1" in
    --skip-build) SKIP_BUILD=1; shift ;;
    --obfuscate) OBFUSCATE=1; shift ;;
    --no-codesign) NO_CODESIGN=1; shift ;;
    --export-method) EXPORT_METHOD="$2"; shift 2 ;;
    *) echo "usage: $0 [--skip-build] [--obfuscate] [--export-method <method>] [--no-codesign]" >&2; exit 2 ;;
  esac
done
case "$EXPORT_METHOD" in
  ""|ad-hoc|development|enterprise|app-store) ;;
  *) echo "invalid --export-method: $EXPORT_METHOD (ad-hoc|development|enterprise|app-store)" >&2; exit 2 ;;
esac

PROJECT_ROOT=$(resolve_project)
cd "$PROJECT_ROOT"
CONFIG_FILE=$(cfg_file "$PROJECT_ROOT")

APP_NAME=$(cfg_get "app.name" "$CONFIG_FILE")
BUNDLE_ID=$(cfg_get "app.bundleId" "$CONFIG_FILE")
OUT_DIR=$(cfg_get "output.dir" "$CONFIG_FILE"); [ -z "$OUT_DIR" ] && OUT_DIR=dist
read_version "$PROJECT_ROOT/pubspec.yaml"
[ -z "$APP_NAME" ] && APP_NAME=$(basename "$PROJECT_ROOT")

echo "==> release-kit publish_ios"
echo "    project: $PROJECT_ROOT  app: $APP_NAME ($VERSION)  bundle: $BUNDLE_ID"
echo "    obfuscate: $(if [ "$OBFUSCATE" = 1 ]; then printf 'on'; else printf 'off'; fi)  export-method: ${EXPORT_METHOD:-app-store}"

if [ "$SKIP_BUILD" = "0" ]; then
  OBF_ARGS=""
  if [ "$OBFUSCATE" = "1" ]; then
    OBF_ARGS="--obfuscate --split-debug-info=./build/obfuscate_symbols"
  fi
  EXPORT_ARGS=""
  if [ "$NO_CODESIGN" = "1" ]; then
    EXPORT_ARGS="--no-codesign"
  elif [ -n "$EXPORT_METHOD" ]; then
    EXPORT_ARGS="--export-method=$EXPORT_METHOD"
  fi
  echo "==> flutter build ipa --release"
  # shellcheck disable=SC2086
  flutter build ipa --release $OBF_ARGS $EXPORT_ARGS $(version_defines) $(dart_defines)
fi

mkdir -p "$PROJECT_ROOT/$OUT_DIR"

if [ "$NO_CODESIGN" = "1" ]; then
  # --no-codesign stops at the .xcarchive (no .ipa is produced)
  ARCHIVE=$(find "$PROJECT_ROOT/build/ios/archive" -maxdepth 1 -type d -name "*.xcarchive" -print 2>/dev/null | sort | tail -n1)
  if [ -z "$ARCHIVE" ] || [ ! -d "$ARCHIVE" ]; then
    echo "xcarchive not found under $PROJECT_ROOT/build/ios/archive" >&2
    exit 1
  fi
  ARCHIVE_OUT="$PROJECT_ROOT/$OUT_DIR/$APP_NAME-$VERSION-ios.xcarchive"
  cp -R "$ARCHIVE" "$ARCHIVE_OUT"
  echo "==> artifact: $ARCHIVE_OUT"
  echo "    size: $(du -sh "$ARCHIVE_OUT" | awk '{print $1}')"
  echo "    (unsigned build - codesign manually to deploy)"
else
  # the .ipa's filename comes from the Xcode product name (not app.name),
  # so locate it robustly under build/ios/ipa
  IPA=$(find "$PROJECT_ROOT/build/ios/ipa" -maxdepth 1 -name "*.ipa" -print 2>/dev/null | sort | tail -n1)
  if [ -z "$IPA" ] || [ ! -f "$IPA" ]; then
    echo "ipa not found under $PROJECT_ROOT/build/ios/ipa" >&2
    exit 1
  fi
  IPA_OUT="$PROJECT_ROOT/$OUT_DIR/$APP_NAME-$VERSION-ios.ipa"
  cp "$IPA" "$IPA_OUT"
  print_artifact "$IPA_OUT"
fi
echo "==> done"
