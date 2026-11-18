import 'dart:io';

import 'package:e_archive_server/api_handlers.dart';
import 'package:e_archive_server/mysql_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

class _PolicyStore extends MySqlStore {
  @override
  Future<List<Map<String, Object?>>> fetchAccessRules() async => [
        {
          'role': 'staff',
          'resource': 'students',
          'action': 'delete',
          'allowed': 0,
        },
      ];
}

void main() {
  group('API authorization boundary', () {
    late Handler handler;

    setUp(() {
      handler = createApiHandler(MySqlStore(), Directory.systemTemp);
    });

    test('allows the public health endpoint without identity headers',
        () async {
      final response = await handler(
        Request('GET', Uri.parse('http://localhost/api/health')),
      );

      expect(response.statusCode, HttpStatus.ok);
    });

    test('rejects protected endpoints without identity headers', () async {
      final response = await handler(
        Request('GET', Uri.parse('http://localhost/api/users')),
      );

      expect(response.statusCode, HttpStatus.unauthorized);
      expect(await response.readAsString(),
          contains('Authentication is required'));
    });

    test('returns a client error for malformed login JSON', () async {
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/auth/login'),
          body: '{not valid json',
        ),
      );

      expect(response.statusCode, HttpStatus.badRequest);
      expect(await response.readAsString(), contains('Invalid JSON'));
    });

    test('blocks staff from restoring a deleted student', () async {
      final policyHandler = createApiHandler(
        _PolicyStore(),
        Directory.systemTemp,
      );
      final response = await policyHandler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/trash/students/1/restore'),
          headers: {'x-user-role': 'staff'},
        ),
      );

      expect(response.statusCode, HttpStatus.forbidden);
    });
  });
}
