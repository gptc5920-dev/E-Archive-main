import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:e_archive_server/api_handlers.dart';
import 'package:e_archive_server/config.dart';
import 'package:e_archive_server/mysql_store.dart';

Future<void> main() async {
  try {
    await _startServer();
  } catch (error, stackTrace) {
    await _writeStartupLog('API startup failed: $error\n$stackTrace');
    stderr.writeln('E-Archive API startup failed: $error');
    stderr.writeln('Details: ${ServerConfig.startupLogFile.path}');
    exitCode = 1;
  }
}

Future<void> _startServer() async {
  final baseUrl = 'http://${ServerConfig.apiHost}:${ServerConfig.apiPort}';

  if (await _isOurApiAlreadyRunning(baseUrl)) {
    stdout.writeln('E-Archive API is already running at $baseUrl');
    stdout.writeln(
        'Use the app as-is, or stop that process before starting again.');
    return;
  }

  final uploadsDir = Directory(
    '${ServerConfig.dataDirectory.path}${Platform.pathSeparator}uploads',
  );

  final store = MySqlStore();
  try {
    await store.open(uploadsDir);
  } catch (e) {
    final message =
        'Failed to open MySQL database (${ServerConfig.mysqlDsn}): $e';
    stderr.writeln(message);
    stderr
        .writeln('Check MySQL is running and set E_ARCHIVE_MYSQL_* if needed.');
    await _writeStartupLog(
      '$message\nCheck MySQL is running and set E_ARCHIVE_MYSQL_* if needed.',
    );
    rethrow;
  }

  final apiHandler = createApiHandler(store, uploadsDir);
  final uploadsHandler = createUploadsHandler(uploadsDir);
  final handler =
      Pipeline().addMiddleware(logRequests()).addHandler((Request request) {
    final path = request.requestedUri.path;
    if (path.startsWith('/uploads/')) {
      return uploadsHandler(request);
    }
    return apiHandler(request);
  });

  try {
    await shelf_io.serve(
      handler,
      ServerConfig.apiHost,
      ServerConfig.apiPort,
    );
  } on SocketException catch (e) {
    if (e.osError?.errorCode == 10048) {
      stderr.writeln(
        'Port ${ServerConfig.apiPort} is already in use on ${ServerConfig.apiHost}.',
      );
      stderr.writeln('');
      stderr
          .writeln('Fix: close the other program using that port, then retry.');
      stderr.writeln(
          '  1. Find PID:  netstat -ano | findstr :${ServerConfig.apiPort}');
      stderr.writeln('  2. Stop it:   taskkill /F /PID <pid>');
      stderr.writeln('');
      stderr.writeln('Or run stop_server.bat from the server folder.');
    } else {
      stderr.writeln('Could not start server: $e');
    }
    rethrow;
  }

  stdout.writeln('E-Archive API running at $baseUrl');
  stdout.writeln('Database (MySQL): ${ServerConfig.mysqlDsn}');
  stdout.writeln('Data: ${ServerConfig.dataDirectory.path}');
  await _writeStartupLog(
    'E-Archive API running at $baseUrl\n'
    'Database (MySQL): ${ServerConfig.mysqlDsn}\n'
    'Data: ${ServerConfig.dataDirectory.path}',
  );
}

Future<void> _writeStartupLog(String message) async {
  try {
    final logFile = ServerConfig.startupLogFile;
    await logFile.parent.create(recursive: true);
    await logFile.writeAsString(
      '[${DateTime.now().toIso8601String()}] $message\n',
      mode: FileMode.append,
      flush: true,
    );
  } on Object {
    // Logging must never hide the actual startup result.
  }
}

Future<bool> _isOurApiAlreadyRunning(String baseUrl) async {
  final client = HttpClient();
  try {
    final request = await client
        .getUrl(Uri.parse('$baseUrl/api/health'))
        .timeout(const Duration(seconds: 2));
    final response = await request.close().timeout(const Duration(seconds: 2));
    if (response.statusCode != 200) return false;
    final body = await response.transform(utf8.decoder).join();
    return body.contains('"status":"ok"') || body.contains('"status": "ok"');
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}
