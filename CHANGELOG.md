# Changelog

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
