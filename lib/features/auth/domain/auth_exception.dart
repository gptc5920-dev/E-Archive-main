abstract class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthConnectionException extends AuthException {
  const AuthConnectionException(super.message);
}

class AuthServerException extends AuthException {
  const AuthServerException(super.message);
}
