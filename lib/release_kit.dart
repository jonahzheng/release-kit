/// release-kit — Flutter release toolkit CLI.
///
/// Commands:
/// - `release-kit init`        copy config template + install pre-commit hook
/// - `release-kit publish`     build & package a platform
/// - `release-kit bump`        auto-increment the version in pubspec.yaml
library;

export 'src/cli.dart' show runCli;
