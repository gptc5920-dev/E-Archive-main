import '../../../../models/user_role.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_api_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthApiDataSource apiDataSource,
  }) : _apiDataSource = apiDataSource;

  final AuthApiDataSource _apiDataSource;

  @override
  Future<UserRole?> login({
    required String username,
    required String password,
  }) {
    return _apiDataSource.validate(
      username: username,
      password: password,
    );
  }
}
