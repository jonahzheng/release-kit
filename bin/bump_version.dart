import 'dart:convert';
import 'dart:io';

/// Auto-bumps the version in `pubspec.yaml` based on the staged changes.
///
/// Heuristics (in priority order, from `git diff --cached`):
///   1. major — deleting an entire source file (breaking change).
///   2. minor — new source files, or >= 40 added lines in changed source files.
///   3. patch — anything else (small edits, docs, config).
/// The build number (+N) is always incremented by 1.
///
/// Usage (run from the repo root or project dir):
///   dart run bin/bump_version.dart [--pubspec <path>] [--build-only]
///
/// Path resolution:
///   - `--pubspec <path>`  explicit pubspec path (highest priority)
///   - auto-detect: `app/pubspec.yaml` (monorepo) -> `<cwd>/pubspec.yaml`
///
/// Exit code 0 on success; non-zero (with a message) on failure.
Future<void> main(List<String> args) async {
  var buildOnly = false;
  String? pubspecArg;
  String? msgFile;
  for (final a in args) {
    if (a == '--build-only') {
      buildOnly = true;
    } else if (a == '--pubspec') {
      // handled below via index
    } else if (a.startsWith('--pubspec=')) {
      pubspecArg = a.substring('--pubspec='.length);
    } else if (!a.startsWith('-')) {
      msgFile = a;
    }
  }
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--pubspec' && i + 1 < args.length) {
      pubspecArg = args[i + 1];
    }
  }

  final pubspecPath = _resolvePubspec(pubspecArg);
  if (pubspecPath == null) {
    stderr.writeln(
        'pubspec.yaml not found. Use --pubspec <path> or run from the project root.');
    exit(2);
  }

  final content = File(pubspecPath).readAsStringSync();
  final re = RegExp(r'^version:\s*(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?\s*$',
      multiLine: true);
  final match = re.firstMatch(content);
  if (match == null) {
    stderr.writeln('version: line not found in $pubspecPath');
    exit(2);
  }

  var major = int.parse(match.group(1)!);
  var minor = int.parse(match.group(2)!);
  var patch = int.parse(match.group(3)!);
  final build = (match.group(4) == null ? 0 : int.parse(match.group(4)!)) + 1;

  var label = 'build';
  if (!buildOnly) {
    final kind = _inferBumpKind(msgFile);
    switch (kind) {
      case 'major':
        major++;
        minor = 0;
        patch = 0;
        break;
      case 'minor':
        minor++;
        patch = 0;
        break;
      default:
        patch++;
    }
    label = kind;
  }

  final newVersion = '$major.$minor.$patch+$build';
  final updated = content.replaceFirst(re, 'version: $newVersion\n', 0);
  File(pubspecPath).writeAsStringSync(updated, flush: true);
  stdout.writeln('version $newVersion ($label)');
}

/// Infers the bump kind from the commit message and the staged diff.
String _inferBumpKind(String? msgFile) {
  if (msgFile != null && File(msgFile).existsSync()) {
    final lines = File(msgFile).readAsLinesSync();
    final subject =
        lines.firstWhere((l) => l.trim().isNotEmpty, orElse: () => '').trim();
    if (subject.contains('!') ||
        subject.toUpperCase().contains('BREAKING CHANGE')) {
      return 'major';
    }
  }

  final diff = _stagedDiff();
  final deletedFiles = _deletedFilePaths();
  var added = 0;
  var newSourceFiles = 0;
  var changedSourceFiles = 0;

  for (final line in diff) {
    final m = RegExp(r'^(\d+)\s+(\d+)\s+(.+)$').firstMatch(line);
    if (m == null) continue;
    final a = int.tryParse(m.group(1)!) ?? 0;
    final d = int.tryParse(m.group(2)!) ?? 0;
    final path = m.group(3)!;
    final isSource = path.endsWith('.dart') ||
        path.endsWith('.ts') ||
        path.endsWith('.tsx') ||
        path.endsWith('.go') ||
        path.endsWith('.py') ||
        path.endsWith('.rs') ||
        path.endsWith('.js') ||
        path.endsWith('.kt') ||
        path.endsWith('.swift');
    final isAppSource = isSource &&
        (path.startsWith('lib/') ||
            path.startsWith('app/lib/') ||
            path.startsWith('android/app/') ||
            path.startsWith('ios/') ||
            path.startsWith('macos/'));
    added += a;
    if (isAppSource) {
      changedSourceFiles++;
      if (a > 0 && d == 0 && _isAddedFile(path)) {
        newSourceFiles++;
      }
    }
  }

  if (deletedFiles.any((p) =>
      p.startsWith('lib/') ||
      p.startsWith('app/lib/') ||
      p.startsWith('android/app/') ||
      p.startsWith('ios/') ||
      p.startsWith('macos/'))) {
    return 'major';
  }
  if (newSourceFiles > 0 || (changedSourceFiles > 0 && added >= 40)) {
    return 'minor';
  }
  return 'patch';
}

List<String> _deletedFilePaths() {
  final r = Process.runSync('git', ['diff', '--cached', '--name-status']);
  if (r.exitCode != 0) return const [];
  final out = <String>[];
  for (final line in LineSplitter.split(r.stdout as String)) {
    if (line.startsWith('D\t')) out.add(line.substring(2));
  }
  return out;
}

bool _isAddedFile(String path) {
  final r = Process.runSync('git', ['diff', '--cached', '--name-status']);
  if (r.exitCode != 0) return false;
  for (final line in LineSplitter.split(r.stdout as String)) {
    final parts = line.split('\t');
    if (parts.length >= 2 && parts[1] == path) {
      return parts[0].startsWith('A');
    }
  }
  return false;
}

List<String> _stagedDiff() {
  final r = Process.runSync('git', ['diff', '--cached', '--numstat']);
  if (r.exitCode != 0) return const [];
  return (r.stdout as String)
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .toList();
}

/// Locates `pubspec.yaml`: explicit path > `app/pubspec.yaml` > cwd.
String? _resolvePubspec(String? explicit) {
  if (explicit != null && explicit.isNotEmpty) {
    final f = File(explicit);
    if (f.existsSync()) return f.absolute.path;
    final f2 = File('app${Platform.pathSeparator}$explicit');
    if (f2.existsSync()) return f2.absolute.path;
    return null;
  }
  final cwd = Directory.current.absolute;
  final inApp = File('${cwd.path}${Platform.pathSeparator}app${Platform.pathSeparator}pubspec.yaml');
  if (inApp.existsSync()) return inApp.path;
  final direct = File('${cwd.path}${Platform.pathSeparator}pubspec.yaml');
  if (direct.existsSync()) return direct.path;
  return null;
}
