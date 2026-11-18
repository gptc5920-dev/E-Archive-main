import '../../../../models/user_role.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<UserRole?> call({
    required String username,
    required String password,
  }) {
    return _repository.login(username: username, password: password);
  }
}
