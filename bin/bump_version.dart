import 'dart:io';

import '../lib/src/bump.dart';

Future<void> main(List<String> args) async {
  exitCode = await runBump(args);
}
