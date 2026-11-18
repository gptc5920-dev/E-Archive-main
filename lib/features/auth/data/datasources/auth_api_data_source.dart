import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../../core/network/api_config.dart';
import '../../../../core/network/api_server_bootstrap.dart';
import '../../../../models/user_role.dart';
import '../../domain/auth_exception.dart';

class AuthApiDataSource {
  AuthApiDataSource({
    String? baseUrl,
    Future<bool> Function()? ensureApiAvailable,
  })  : _baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _ensureApiAvailable =
            ensureApiAvailable ?? ApiServerBootstrap.ensureRunning;

  final String _baseUrl;
  final Future<bool> Function() _ensureApiAvailable;

  Future<UserRole?> validate({
    required String username,
    required String password,
  }) async {
    final apiAvailable = await _ensureApiAvailable();
    if (!apiAvailable) {
      throw AuthConnectionException(
        ApiServerBootstrap.unavailableMessage(_baseUrl),
      );
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client
          .postUrl(Uri.parse('$_baseUrl/api/auth/login'))
          .timeout(const Duration(seconds: 6));
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      request.write(
        jsonEncode({
          'username': username.trim(),
          'password': password,
        }),
      );

      final response =
          await request.close().timeout(const Duration(seconds: 8));
      final responseBody = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == HttpStatus.unauthorized) return null;
      if (response.statusCode != HttpStatus.ok) {
        throw const AuthServerException(
          'The E-Archive API could not process the login request.',
        );
      }

      final payload = jsonDecode(responseBody);
      if (payload is! Map<String, dynamic>) {
        throw const AuthServerException(
          'The E-Archive API returned an invalid login response.',
        );
      }
      if (payload['authenticated'] != true) return null;

      final role = '${payload['role'] ?? ''}'.trim().toLowerCase();
      return switch (role) {
        'admin' => UserRole.admin,
        'staff' => UserRole.staff,
        _ => throw const AuthServerException(
            'The authenticated account has an unsupported role.',
          ),
      };
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw AuthConnectionException(
        'The E-Archive API at $_baseUrl did not respond. Start the API and try again.',
      );
    } on SocketException {
      throw AuthConnectionException(
        'Cannot connect to the E-Archive API at $_baseUrl. Start the API and try again.',
      );
    } on HttpException {
      throw AuthConnectionException(
        'Cannot connect to the E-Archive API at $_baseUrl. Check the API address and try again.',
      );
    } on FormatException {
      throw const AuthServerException(
        'The E-Archive API returned an invalid login response.',
      );
    } finally {
      client.close(force: true);
    }
  }
}
