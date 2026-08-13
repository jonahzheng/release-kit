import 'dart:io';

import 'package:release_kit/release_kit.dart';

Future<void> main(List<String> args) async {
  exitCode = await runCli(args);
}
