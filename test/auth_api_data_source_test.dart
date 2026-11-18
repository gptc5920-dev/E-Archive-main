import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:e_archive/features/auth/data/datasources/auth_api_data_source.dart';
import 'package:e_archive/features/auth/domain/auth_exception.dart';
import 'package:e_archive/models/user_role.dart';

void main() {
  test('authenticates an admin using the API response', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    server.listen((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/auth/login');
      final payload = jsonDecode(await utf8.decoder.bind(request).join());
      expect(payload['username'], 'admin@gmail.com');
      expect(payload['password'], 'admin123');
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'authenticated': true, 'role': 'admin'}));
      await request.response.close();
    });

    final dataSource = AuthApiDataSource(
      baseUrl: 'http://127.0.0.1:${server.port}',
      ensureApiAvailable: () async => true,
    );

    final role = await dataSource.validate(
      username: ' admin@gmail.com ',
      password: 'admin123',
    );

    expect(role, UserRole.admin);
  });

  test('returns null when the API rejects the credentials', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    server.listen((request) async {
      await request.drain<void>();
      request.response
        ..statusCode = HttpStatus.unauthorized
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'authenticated': false}));
      await request.response.close();
    });

    final dataSource = AuthApiDataSource(
      baseUrl: 'http://127.0.0.1:${server.port}',
      ensureApiAvailable: () async => true,
    );

    final role = await dataSource.validate(
      username: 'wrong',
      password: 'wrong',
    );

    expect(role, isNull);
  });

  test('reports a startup failure before making the login request', () async {
    final dataSource = AuthApiDataSource(
      baseUrl: 'http://127.0.0.1:8080',
      ensureApiAvailable: () async => false,
    );

    expect(
      () => dataSource.validate(username: 'admin', password: 'admin123'),
      throwsA(
        isA<AuthConnectionException>().having(
          (error) => error.message,
          'message',
          contains('API could not start'),
        ),
      ),
    );
  });
}
