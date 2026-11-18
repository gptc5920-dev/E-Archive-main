import 'dart:io';

class ApiConfig {
  const ApiConfig._();

  static const _compiledBaseUrl = String.fromEnvironment(
    'E_ARCHIVE_API_BASE_URL',
  );

  static String get baseUrl {
    final runtimeBaseUrl =
        Platform.environment['E_ARCHIVE_API_BASE_URL']?.trim() ?? '';
    final configuredBaseUrl =
        runtimeBaseUrl.isNotEmpty ? runtimeBaseUrl : _compiledBaseUrl.trim();
    final value =
        configuredBaseUrl.isEmpty ? 'http://127.0.0.1:8080' : configuredBaseUrl;
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  static Uri endpoint(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath');
  }

  static bool get usesLocalServer {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null) return false;
    return uri.host == '127.0.0.1' ||
        uri.host == 'localhost' ||
        uri.host == '::1';
  }
}
