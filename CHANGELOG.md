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
