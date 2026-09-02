# Changelog

## 0.1.18

- Fix `.deb`/`.rpm` packages shipping only the launcher binary (missing `lib/` + `data/`, so the installed app could not run). They now bundle the full release bundle under `/usr/lib/<id>/` and expose the binary via a `/usr/bin` symlink.

## 0.1.17

- Fix `--appimage`: `linuxdeploy` requires a `.desktop` file and an `AppRun` inside the AppDir, but the raw Flutter bundle has neither, so AppImage packaging failed with `Desktop file not found`. The AppImage path now stages the bundle, injects the desktop entry + `AppRun` (the binary stays at the AppDir root so it can still locate `lib/`/`data/`), bundles the icon, and copies the resulting `.AppImage` to `dist/`.

## 0.1.16

- Linux `publish` now always emits a portable `.zip` (`dist/<app>-<version>+<build>-linux.zip`, single top-level `<app>/` dir) as the default artifact — the same shape the Windows/macOS packs and in-app auto-update use. The previous `.tar.gz` default is removed; `--deb` / `--rpm` / `--appimage` still produce the distro install packages on top of the zip.

## 0.1.15

- Fix garbled non-ASCII text in the generated `dist/CHANGELOG-<version>+<build>.md` on Windows: read the project `CHANGELOG.md` as UTF-8, decode `git log` output as UTF-8, and write the result as UTF-8 without BOM.

## 0.1.14

- Every `publish` now emits a standard, versioned changelog alongside the artifacts: `dist/CHANGELOG-<version>+<build>.md`. The content is extracted from the project's `CHANGELOG.md` (the Keep-a-Changelog section matching the current version); when there is no `CHANGELOG.md` (or no section for the version), it falls back to grouping the `git log` since the last tag by conventional-commit type (`feat:` → Added, `fix:` → Fixed, everything else → Changed).

## 0.1.13

- macOS and Linux package filenames now include the build number, matching the Windows convention: `dist/<app>-<version>+<build>-macos.dmg` / `.zip`, `dist/<app>-<version>+<build>-linux-x64.tar.gz` / `.deb` / `.rpm` (e.g. `ZShell-1.41.2+79-macos.zip`). `read_version` now also exports `VERSION_FULL` (`x.y.z+build`).

## 0.1.12

- Windows installer zip now includes the build number: `dist/<app>-<version>+<build>-win64.zip` (e.g. `ZShell-1.41.2+79-win64.zip`).

## 0.1.11

- macOS `publish` now also emits an auto-update `.zip` next to the `.dmg`, built from the very same signed `.app` (`ditto -c -k --sequesterRsrc --keepParent` keeps `<AppName>.app` as the sole top-level entry so in-app updaters that strip one directory can replace the running app's `Contents`). Output: `dist/<app>-<version>-macos.dmg` + `dist/<app>-<version>-macos.zip`.

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
