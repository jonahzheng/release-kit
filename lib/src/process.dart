import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Runs [executable] with [args], streaming its stdout/stderr through to this
/// process (so users see the same output as the plain scripts).
///
/// Returns the child process exit code.
Future<int> runStreamed(
  String executable,
  List<String> args, {
  String? workingDirectory,
}) async {
  final proc = await Process.start(executable, args,
      workingDirectory: workingDirectory, runInShell: false);
  final draining = <Future<void>>[
    proc.stdout.transform(utf8.decoder).forEach(stdout.write),
    proc.stderr.transform(utf8.decoder).forEach(stderr.write),
  ];
  await Future.wait(draining);
  return proc.exitCode;
}
