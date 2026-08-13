import 'dart:io';
import 'dart:isolate';

/// Resolves the absolute path of the package's `lib/assets/` directory.
///
/// Works both from source (`dart run`) and after `dart pub global activate`,
/// because package: URIs are resolved against the activated package.
Future<String> assetRoot() async {
  final uri = await Isolate.resolvePackageUri(
      Uri.parse('package:release_kit/assets/'));
  if (uri == null) {
    throw StateError('cannot resolve package:release_kit/assets/');
  }
  return _stripTrailingSeparator(uri.toFilePath());
}

/// Resolves `lib/assets/<relative>` (e.g. `scripts/publish_android.sh`) to an
/// absolute filesystem path.
Future<String> assetPath(String relative) async {
  final root = await assetRoot();
  if (relative.isEmpty) return root;
  final parts = relative.split('/');
  return root + Platform.pathSeparator + parts.join(Platform.pathSeparator);
}

String _stripTrailingSeparator(String p) {
  final sep = Platform.pathSeparator;
  while (p.length > 1 && p.endsWith(sep)) {
    p = p.substring(0, p.length - 1);
  }
  return p;
}
