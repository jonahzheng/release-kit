#!/bin/sh
# release-kit: generate platform launcher icons from a single source image
#
# Reads `app.logo` from the resolved config (release-kit.yaml > config.yaml
# > tool default). If unset or the file is missing, prints a warning and
# exits 0 (icons are optional). Otherwise drives flutter_launcher_icons to
# regenerate Android / iOS / macOS / Windows icons.
#
# Usage: ./generate_icons.sh [-p <project-root>]  (or run from project root)
set -e

KIT_ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$KIT_ROOT/scripts/common.sh"

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

# ensure flutter_launcher_icons is available as a dev dependency
if ! grep -q 'flutter_launcher_icons' pubspec.yaml; then
  echo "==> adding flutter_launcher_icons dev dependency..."
  flutter pub add --dev flutter_launcher_icons
fi

FLIC="flutter_launcher_icons.yaml"
cat > "$FLIC" <<EOF
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "$LOGO"
  windows:
    generate: true
    image_path: "$LOGO"
    icon_size: 256
  macos:
    generate: true
    image_path: "$LOGO"
EOF

echo "==> generating icons from $LOGO ..."
dart run flutter_launcher_icons:generate -f "$FLIC"
rm -f "$FLIC"
echo "==> icons regenerated"
