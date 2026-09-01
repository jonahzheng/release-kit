#!/bin/sh
# release-kit: Linux publish smoke test
# Verifies publish_linux.sh packaging + linux icon generation without a real
# Flutter SDK: a stub `flutter` on PATH fakes the build, and a pre-made bundle
# stands in for build output.
#
# Usage: sh test/publish_linux_test.sh
# Requirements: sh + tar (dpkg-deb optional: tested only when present)

set -e
KIT_ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
SCRIPTS="$KIT_ROOT/lib/assets/scripts"

fail() { echo "FAIL: $*" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
PROJ="$TMP/proj"
mkdir -p "$PROJ/linux/runner" "$PROJ/build/linux/x64/release/bundle" "$TMP/bin"

# --- fake project ---
cat > "$PROJ/pubspec.yaml" <<'EOF'
name: smoke_app
version: 1.2.3+4
EOF
cat > "$PROJ/release-kit.yaml" <<'EOF'
app.name: SmokeApp
app.logo: assets/logo.png
output.dir: dist
EOF
mkdir -p "$PROJ/assets"
printf 'PNG-DATA' > "$PROJ/assets/logo.png"
# fake built executable (as CMake BINARY_NAME would produce)
printf 'ELF' > "$PROJ/build/linux/x64/release/bundle/smoke_app"
chmod +x "$PROJ/build/linux/x64/release/bundle/smoke_app"

# --- stub flutter: record args, "build" nothing (bundle already exists) ---
cat > "$TMP/bin/flutter" <<'EOF'
#!/bin/sh
echo "$@" > "$FLUTTER_ARGS_LOG"
exit 0
EOF
chmod +x "$TMP/bin/flutter"

echo "==> publish_linux.sh --skip-build (tar.gz)"
export FLUTTER_ARGS_LOG="$TMP/flutter-args.log"
(
  cd "$PROJ"
  PATH="$TMP/bin:$PATH" sh "$SCRIPTS/publish_linux.sh" --skip-build >/dev/null
)
[ -f "$PROJ/dist/SmokeApp-1.2.3+4-linux-x64.tar.gz" ] || fail "tar.gz artifact missing"
grep -q "smoke_app" <(tar -tzf "$PROJ/dist/SmokeApp-1.2.3+4-linux-x64.tar.gz") || fail "bundle not in tar.gz"
echo "ok"

echo "==> --obfuscate forwarded to flutter"
(
  cd "$PROJ"
  PATH="$TMP/bin:$PATH" sh "$SCRIPTS/publish_linux.sh" --obfuscate >/dev/null
)
grep -q -- "--obfuscate" "$FLUTTER_ARGS_LOG" || fail "--obfuscate not forwarded"
grep -q -- "--split-debug-info" "$FLUTTER_ARGS_LOG" || fail "--split-debug-info not forwarded"
echo "ok"

echo "==> linux icon generated from app.logo"
(
  cd "$PROJ"
  sh "$SCRIPTS/generate_icons.sh" -p linux >/dev/null
)
[ -f "$PROJ/linux/runner/my_icon.png" ] || fail "linux/runner/my_icon.png missing"
echo "ok"

echo "==> --deb (requires dpkg-deb)"
if command -v dpkg-deb >/dev/null 2>&1; then
  (
    cd "$PROJ"
    sh "$SCRIPTS/publish_linux.sh" --skip-build --deb >/dev/null
  )
  [ -f "$PROJ/dist/SmokeApp-1.2.3+4-linux-x64.deb" ] || fail "deb artifact missing"
  dpkg-deb -c "$PROJ/dist/SmokeApp-1.2.3+4-linux-x64.deb" | grep -q "usr/bin/smoke_app" || fail "deb lacks binary"
  dpkg-deb -c "$PROJ/dist/SmokeApp-1.2.3+4-linux-x64.deb" | grep -q "smokeapp.desktop" || fail "deb lacks desktop entry"
  echo "ok"
else
  echo "skip (dpkg-deb not installed)"
fi

echo "==> --rpm (requires rpmbuild)"
if command -v rpmbuild >/dev/null 2>&1; then
  (
    cd "$PROJ"
    sh "$SCRIPTS/publish_linux.sh" --skip-build --rpm >/dev/null
  )
  [ -f "$PROJ/dist/SmokeApp-1.2.3+4-linux-x64.rpm" ] || fail "rpm artifact missing"
  echo "ok"
else
  echo "skip (rpmbuild not installed)"
fi

echo "==> all linux publish tests passed"
