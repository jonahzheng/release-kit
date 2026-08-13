import 'dart:io';

import 'bump.dart';
import 'locate.dart';
import 'process.dart';

/// Parses [args] and dispatches to `init` / `publish` / `bump`.
/// Returns the process exit code (0 = success).
Future<int> runCli(List<String> args) async {
  final cmd = args.isEmpty ? '' : args.first;
  final rest = args.skip(1).toList();
  switch (cmd) {
    case 'init':
      return _cmdInit(rest);
    case 'publish':
      return _cmdPublish(rest);
    case 'bump':
      return runBump(rest);
    default:
      _usage();
      return 1;
  }
}

void _usage() {
  stdout.writeln('''
release-kit <command>

  init                        copy config template (release-kit.yaml) + install hook
  publish <platform> [args]   build & package (windows|android|macos|linux|ios)
  bump [--build-only]         auto-increment version in pubspec.yaml

  -p <project-root>           optional: target another project from anywhere
''');
}

// --- helpers ---

/// Strips `-p/--project <root>` (allowed anywhere in the args) out of [args].
({String project, List<String> rest}) _extractProject(List<String> args) {
  var project = '';
  final keep = <String>[];
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if ((a == '-p' || a == '--project') && i + 1 < args.length) {
      project = args[i + 1];
      i++;
    } else {
      keep.add(a);
    }
  }
  return (project: project, rest: keep);
}

String _resolveProjectRoot(String explicit) =>
    explicit.isNotEmpty ? explicit : Directory.current.absolute.path;

bool _hasPubspec(String root) =>
    File('$root${Platform.pathSeparator}pubspec.yaml').existsSync() ||
    File('$root${Platform.pathSeparator}app${Platform.pathSeparator}pubspec.yaml')
        .existsSync();

bool _failProjectRoot(String root) {
  stderr.writeln('release-kit: no pubspec.yaml found under $root');
  stderr.writeln(
      '  run from your Flutter project root, or pass -p <project-root>');
  return true;
}

// --- init ---

Future<int> _cmdInit(List<String> args) async {
  final extracted = _extractProject(args);
  final project = extracted.project;
  final root = _resolveProjectRoot(project);
  if (!_hasPubspec(root)) {
    _failProjectRoot(root);
    return 1;
  }
  final sep = Platform.pathSeparator;
  final pubspecRel = File('$root${sep}pubspec.yaml').existsSync()
      ? 'pubspec.yaml'
      : 'app${sep}pubspec.yaml';
  final pubspecAbs = File('$root$sep$pubspecRel').absolute.path;

  final cfgTarget = File('$root${sep}release-kit.yaml');
  if (!cfgTarget.existsSync()) {
    final src = File(await assetPath('config.yaml'));
    cfgTarget.parent.createSync(recursive: true);
    cfgTarget.writeAsStringSync(src.readAsStringSync());
    stdout.writeln('==> created ${cfgTarget.path} (edit it to match your app)');
  } else {
    stdout.writeln('==> ${cfgTarget.path} already exists, keeping it');
  }

  final hookDir = Directory('$root${sep}.githooks')..createSync(recursive: true);
  final template = File(await assetPath('pre-commit.hook')).readAsStringSync();
  // Forward slashes: git-bash on Windows interprets backslash paths literally,
  // so the hook must use C:/... style paths.
  String fwd(String p) => p.replaceAll('\\', '/');
  final hook = template
      .replaceAll('{SMART_BUMP_PATH}', '')
      .replaceAll('{PUBSPEC_PATH}', fwd(pubspecAbs))
      .replaceAll('{REPO_ROOT}', fwd(root));
  final hookFile = File('${hookDir.path}${sep}pre-commit');
  hookFile.writeAsStringSync(hook, flush: true);
  if (!Platform.isWindows) {
    Process.runSync('chmod', ['+x', hookFile.path]);
  }
  stdout.writeln('==> hook written: ${hookFile.path}');

  final g = await Process.run(
      'git', ['config', 'core.hooksPath', '.githooks'],
      workingDirectory: root);
  if (g.exitCode != 0) {
    stderr.writeln('git config core.hooksPath failed: ${g.stderr}');
    return 1;
  }
  stdout.writeln('==> core.hooksPath set to .githooks');
  stdout.writeln('Done. Skip bump with: git commit --no-verify');
  return 0;
}

// --- publish ---

Future<int> _cmdPublish(List<String> args) async {
  if (args.isEmpty) {
    _usage();
    return 1;
  }
  final extracted = _extractProject(args);
  final project = extracted.project;
  final rest = extracted.rest;
  if (rest.isEmpty) {
    _usage();
    return 1;
  }
  final platform = rest.first;
  final flags = rest.skip(1).toList();
  final root = _resolveProjectRoot(project);
  if (!_hasPubspec(root)) {
    _failProjectRoot(root);
    return 1;
  }

  var skipIcons = false;
  final filtered = <String>[];
  for (final f in flags) {
    if (f == '--no-icons') {
      skipIcons = true;
    } else {
      filtered.add(f);
    }
  }

  if (!skipIcons) {
    final rc = await _runIconGen(platform, root);
    if (rc != 0) return rc;
  }

  final scriptsDir = await assetPath('scripts');
  switch (platform) {
    case 'windows':
      return _publishWindows(scriptsDir, filtered, root);
    case 'android':
    case 'macos':
    case 'linux':
    case 'ios':
      return _publishShell(scriptsDir, platform, filtered, root);
    default:
      stderr.writeln('unknown platform: $platform');
      _usage();
      return 1;
  }
}

Future<int> _runIconGen(String platform, String root) async {
  final scriptsDir = await assetPath('scripts');
  if (Platform.isWindows) {
    final ps = File('$scriptsDir${Platform.pathSeparator}generate_icons.ps1')
        .path;
    return runStreamed('powershell',
        ['-ExecutionPolicy', 'Bypass', '-File', ps, '-Platform', platform],
        workingDirectory: root);
  }
  final sh =
      File('$scriptsDir${Platform.pathSeparator}generate_icons.sh').path;
  return runStreamed('sh', [sh, '-p', platform], workingDirectory: root);
}

Future<int> _publishWindows(
    String scriptsDir, List<String> flags, String root) async {
  final ps =
      File('$scriptsDir${Platform.pathSeparator}publish_windows.ps1').path;
  var obf = false, skp = false, nor = false, hrd = false, cln = false,
      srv = false;
  var outDir = '';
  for (var i = 0; i < flags.length; i++) {
    switch (flags[i]) {
      case '-Obfuscate':
        obf = true;
        break;
      case '-SkipBuild':
        skp = true;
        break;
      case '-NoRename':
        nor = true;
        break;
      case '-Harden':
        hrd = true;
        break;
      case '-CleanFlutter':
        cln = true;
        break;
      case '-SkipVerify':
        srv = true;
        break;
      case '-OutputDir':
        if (i + 1 < flags.length) {
          outDir = flags[i + 1];
          i++;
        }
        break;
    }
  }
  final args = <String>[
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    ps,
    '-Obfuscate:${obf ? 'true' : 'false'}',
    '-SkipBuild:${skp ? 'true' : 'false'}',
    '-NoRename:${nor ? 'true' : 'false'}',
    '-Harden:${hrd ? 'true' : 'false'}',
    '-CleanFlutter:${cln ? 'true' : 'false'}',
    '-SkipVerify:${srv ? 'true' : 'false'}',
  ];
  if (outDir.isNotEmpty) args.addAll(['-OutputDir', outDir]);
  return runStreamed('powershell', args, workingDirectory: root);
}

Future<int> _publishShell(String scriptsDir, String platform, List<String> flags,
    String root) async {
  final shPath = File(
          '$scriptsDir${Platform.pathSeparator}publish_$platform.sh')
      .path
      .replaceAll('\\', '/');
  if (Platform.isWindows) {
    final bash = _findBash();
    if (bash == null) {
      stderr.writeln(
          'bash not found (needed for shell scripts). Install Git for Windows.');
      return 1;
    }
    return runStreamed(bash, [shPath, ...flags], workingDirectory: root);
  }
  return runStreamed('sh', [shPath, ...flags], workingDirectory: root);
}

String? _findBash() {
  const candidates = [
    'C:\\Program Files\\Git\\bin\\bash.exe',
    'C:\\Program Files\\Git\\usr\\bin\\bash.exe',
  ];
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  return null;
}
