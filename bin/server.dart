import 'dart:io';

/// Starts the API from [server/]. Safe to run from the E-Archive project root:
/// `dart run bin/server.dart`
Future<void> main(List<String> args) async {
  final root = Directory.current;
  final serverDir = Directory('${root.path}${Platform.pathSeparator}server');
  final entry = File(
    '${serverDir.path}${Platform.pathSeparator}bin'
    '${Platform.pathSeparator}server.dart',
  );

  if (!entry.existsSync()) {
    stderr.writeln('Could not find server/bin/server.dart');
    stderr.writeln('Expected: ${entry.path}');
    stderr.writeln(
      'Run this from the E-Archive folder (the one that contains server/).',
    );
    exit(1);
  }

  final process = await Process.start(
    Platform.executable,
    ['run', 'bin/server.dart', ...args],
    workingDirectory: serverDir.path,
    mode: ProcessStartMode.inheritStdio,
  );

  exit(await process.exitCode);
}
