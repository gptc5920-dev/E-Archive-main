import 'dart:io';

/// API and MySQL connection configuration.
class ServerConfig {
  static String get apiHost =>
      Platform.environment['E_ARCHIVE_API_HOST']?.trim().isNotEmpty == true
          ? Platform.environment['E_ARCHIVE_API_HOST']!.trim()
          : '127.0.0.1';

  static int get apiPort =>
      int.tryParse(Platform.environment['E_ARCHIVE_API_PORT'] ?? '') ?? 8080;
  static String? databaseNameOverride;

  static String get mysqlHost =>
      Platform.environment['E_ARCHIVE_MYSQL_HOST']?.trim().isNotEmpty == true
          ? Platform.environment['E_ARCHIVE_MYSQL_HOST']!.trim()
          : '127.0.0.1';

  static int get mysqlPort =>
      int.tryParse(Platform.environment['E_ARCHIVE_MYSQL_PORT'] ?? '') ?? 3306;

  static String get mysqlUser =>
      Platform.environment['E_ARCHIVE_MYSQL_USER']?.trim().isNotEmpty == true
          ? Platform.environment['E_ARCHIVE_MYSQL_USER']!.trim()
          : 'root';

  static String? get mysqlPassword {
    final value = Platform.environment['E_ARCHIVE_MYSQL_PASSWORD'];
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static String get mysqlDatabase {
    final override = databaseNameOverride;
    if (override != null && override.trim().isNotEmpty) {
      return override.trim();
    }

    final fromEnv = Platform.environment['E_ARCHIVE_MYSQL_DATABASE'];
    if (fromEnv != null && fromEnv.trim().isNotEmpty) {
      return fromEnv.trim();
    }
    return 'e_archive';
  }

  static String get mysqlDsn =>
      '$mysqlUser@$mysqlHost:$mysqlPort/$mysqlDatabase';

  /// Writable root for uploads, backups, and API startup diagnostics.
  ///
  /// Installed Windows applications normally live under Program Files, which
  /// standard users cannot write to. Keep mutable data in the user's local app
  /// data directory instead of relying on [Directory.current].
  static Directory get dataDirectory {
    final override = Platform.environment['E_ARCHIVE_DATA_DIR']?.trim() ?? '';
    if (override.isNotEmpty) return Directory(override);

    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA']?.trim() ?? '';
      if (localAppData.isNotEmpty) {
        return Directory(_join(localAppData, 'E-Archive'));
      }
      final appData = Platform.environment['APPDATA']?.trim() ?? '';
      if (appData.isNotEmpty) {
        return Directory(_join(appData, 'E-Archive'));
      }
    }

    final home = Platform.environment['HOME']?.trim() ?? '';
    if (home.isNotEmpty) {
      if (Platform.isMacOS) {
        return Directory(
          _join(
            _join(_join(home, 'Library'), 'Application Support'),
            'E-Archive',
          ),
        );
      }
      final xdgDataHome = Platform.environment['XDG_DATA_HOME']?.trim() ?? '';
      final dataHome = xdgDataHome.isNotEmpty
          ? xdgDataHome
          : _join(_join(home, '.local'), 'share');
      return Directory(_join(dataHome, 'e-archive'));
    }

    return Directory(_join(Directory.systemTemp.path, 'E-Archive'));
  }

  static File get startupLogFile =>
      File(_join(_join(dataDirectory.path, 'logs'), 'api-startup.log'));

  static String _join(String parent, String child) {
    if (parent.endsWith(Platform.pathSeparator)) return '$parent$child';
    return '$parent${Platform.pathSeparator}$child';
  }
}
