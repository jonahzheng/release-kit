#!/bin/sh
# release-kit: publish iOS build (config-driven) — SKELETON
# Not yet verified on a macOS host with Xcode; refine as needed.
# Usage: ./publish_ios.sh [--skip-build]
#
# Requires:
#   - Xcode + iOS signing (Apple Developer cert/profile)
#   - Run on macOS. Produces an .ipa for distribution (TestFlight/App Store).
#
# Typical flow:
#   flutter build ipa --release   # builds archive + ipa
#   output: build/ios/ipa/<name>.ipa

set -e
KIT_ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$KIT_ROOT/scripts/common.sh"

APP_NAME=$(cfg_get "app.name")
OUT_DIR=$(cfg_get "output.dir"); [ -z "$OUT_DIR" ] && OUT_DIR=dist
SKIP_BUILD=0
[ "$1" = "--skip-build" ] && SKIP_BUILD=1

PROJECT_ROOT=$(resolve_project)
cd "$PROJECT_ROOT"
read_version "$PROJECT_ROOT/pubspec.yaml"
[ -z "$APP_NAME" ] && APP_NAME=$(basename "$PROJECT_ROOT")

echo "==> release-kit publish_ios (skeleton)"
echo "    project: $PROJECT_ROOT  app: $APP_NAME ($VERSION)"

if [ "$SKIP_BUILD" = "0" ]; then
  # shellcheck disable=SC2086
  flutter build ipa --release $(dart_defines)
fi

IPA="$PROJECT_ROOT/build/ios/ipa/$APP_NAME.ipa"
if [ ! -f "$IPA" ]; then
  echo "ipa not found: $IPA" >&2
  exit 1
fi

mkdir -p "$PROJECT_ROOT/$OUT_DIR"
IPA_OUT="$PROJECT_ROOT/$OUT_DIR/$APP_NAME-$VERSION-ios.ipa"
cp "$IPA" "$IPA_OUT"
print_artifact "$IPA_OUT"
