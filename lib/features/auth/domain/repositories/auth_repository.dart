import '../../../../models/user_role.dart';

abstract class AuthRepository {
  Future<UserRole?> login({
    required String username,
    required String password,
  });
}
