# Changelog

## 0.1.10

- Every `publish` build now auto-injects `--dart-define=APP_VERSION=<x.y.z>` and `--dart-define=APP_BUILD=<build>` from `pubspec.yaml` (all platforms: Windows, Android, macOS, Linux, iOS). Apps can show their real version at runtime via `String.fromEnvironment('APP_VERSION')` / `('APP_BUILD')`; an explicit `build.dartDefine.APP_VERSION`/`APP_BUILD` overrides the auto value.

## 0.1.9

- `publish <platform>` flag matching is now case/hyphen tolerant: `--CleanFlutter`, `--SKIP_BUILD` etc. are accepted and mapped to their canonical form (`--clean-flutter`, `--skip-build`) on every entry point (Dart CLI, `release-kit.ps1`, `publish_windows.ps1`).

## 0.1.8

- Fix `release_kit publish windows`: the Dart CLI invoked `publish_windows.ps1` with `-Obfuscate:true` style switches, which PowerShell `-File` cannot bind (error: `Cannot process argument transformation on parameter 'Obfuscate'`). It now passes bare double-dash flags (`--obfuscate`, `--clean-flutter`, ...), which bind correctly.

## 0.1.7

- All `publish <platform>` flags now use the same double-dash long-flag spelling on every platform (`--obfuscate`, `--skip-build`, `--no-rename`, `--harden`, `--clean-flutter`, `--skip-verify`, `--output-dir`). The old Windows single-dash spellings (`-Obfuscate` etc.) are no longer accepted.

## 0.1.6

- Docs: detailed per-flag reference for every platform in GUIDE (common flags `-p`/`--no-icons` + windows/android/ios/macos/linux tables).

## 0.1.5

- Docs: add pub.dev badge/link to README; document `release-kit bump` and Windows `-NoRename` in README/GUIDE.

## 0.1.4

- Linux publish implemented end-to-end: `--obfuscate`, `--deb` (dpkg-deb), `--rpm` (rpmbuild), `--appimage`; desktop entry + hi-color icon from `linux/runner/my_icon.png`; `linux.desktopCategories` config key.
- Linux window icon generation: resize `app.logo` → `linux/runner/my_icon.png` (ImageMagick when available).
- Smoke test for the Linux path: `test/publish_linux_test.sh`.

## 0.1.3

- Fix iOS/macOS flag parsing infinite loop (missing `shift`).
- iOS `--no-codesign`: collect the `.xcarchive` (Flutter skips `.ipa` generation when unsigned).
- macOS: drop the unsupported `--no-codesign` flag.
- Verified iOS and macOS publishing on a real macOS host.

## 0.1.2

- iOS publish: add `--obfuscate`, `--export-method`, `--no-codesign`; robust `.ipa` discovery.
- macOS publish: add `--obfuscate`, `--no-codesign`; robust `.app` discovery.
- Docs: document iOS/macOS flags in README and GUIDE.

## 0.1.1

- Docs: restructure README and add an English usage guide (`docs/GUIDE.md`); make pub.dev install the primary quick start, with git-clone as an alternative.

## 0.1.0

- Initial release as a Dart CLI package.
- `release-kit init` — copy the config template + install the pre-commit hook.
- `release-kit publish <platform>` — build & package (windows / android / macos / linux / ios).
- `release-kit bump` — auto-increment the version in `pubspec.yaml` from staged changes.
