import 'dart:async';
import 'dart:io';

import 'package:e_archive_server/config.dart';
import 'package:path/path.dart' as p;

import 'api_config.dart';

class ApiServerBootstrap {
  const ApiServerBootstrap._();

  static const _startupTimeout = Duration(seconds: 30);
  static const _healthPollInterval = Duration(milliseconds: 500);

  static Future<bool>? _startup;

  static Future<bool> ensureRunning() {
    return _startup ??= _ensureRunning().whenComplete(() => _startup = null);
  }

  static String unavailableMessage(String baseUrl) {
    if (!ApiConfig.usesLocalServer) {
      return 'Cannot connect to the E-Archive API at $baseUrl. '
          'Check the API address and try again.';
    }

    return 'The local E-Archive API could not start. Make sure MySQL is '
        'running, then try again. Startup details: '
        '${ServerConfig.startupLogFile.path}';
  }

  static Future<bool> _ensureRunning() async {
    if (await _isHealthy()) return true;
    if (!Platform.isWindows || !ApiConfig.usesLocalServer) return false;

    final launchTarget = _findLaunchTarget();
    if (launchTarget == null) return false;

    try {
      await Process.start(
        launchTarget.executable.path,
        const [],
        workingDirectory: launchTarget.workingDirectory.path,
        environment: {
          ...Platform.environment,
          'E_ARCHIVE_DATA_DIR': ServerConfig.dataDirectory.path,
        },
        mode: ProcessStartMode.detached,
      );
    } on ProcessException {
      return false;
    }

    final startupDeadline = DateTime.now().add(_startupTimeout);
    while (DateTime.now().isBefore(startupDeadline)) {
      if (await _isHealthy()) return true;

      final timeRemaining = startupDeadline.difference(DateTime.now());
      if (timeRemaining <= Duration.zero) break;
      await Future<void>.delayed(
        timeRemaining < _healthPollInterval
            ? timeRemaining
            : _healthPollInterval,
      );
    }
    return false;
  }

  static _ApiLaunchTarget? _findLaunchTarget() {
    final appDirectory = File(Platform.resolvedExecutable).parent;
    final currentDirectory = Directory.current;
    final sourceServerDirectory = Directory(
      p.join(currentDirectory.path, 'server'),
    );
    final candidates = <_ApiLaunchTarget>[
      _ApiLaunchTarget(
        executable: File(
          p.join(appDirectory.path, 'api', 'bin', 'server.exe'),
        ),
        workingDirectory: appDirectory,
      ),
      _ApiLaunchTarget(
        executable: File(
          p.join(currentDirectory.path, 'api', 'bin', 'server.exe'),
        ),
        workingDirectory: currentDirectory,
      ),
      _ApiLaunchTarget(
        executable: File(
          p.join(
            sourceServerDirectory.path,
            'build',
            'api_release',
            'bundle',
            'bin',
            'server.exe',
          ),
        ),
        workingDirectory: sourceServerDirectory,
      ),
    ];

    for (final candidate in candidates) {
      if (candidate.executable.existsSync()) return candidate;
    }
    return null;
  }

  static Future<bool> _isHealthy() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
    try {
      final request = await client
          .getUrl(ApiConfig.endpoint('/api/health'))
          .timeout(const Duration(seconds: 1));
      final response =
          await request.close().timeout(const Duration(seconds: 1));
      await response.drain<void>().timeout(const Duration(seconds: 1));
      return response.statusCode == HttpStatus.ok;
    } on Object {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}

class _ApiLaunchTarget {
  const _ApiLaunchTarget({
    required this.executable,
    required this.workingDirectory,
  });

  final File executable;
  final Directory workingDirectory;
}
