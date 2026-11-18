import 'package:flutter/material.dart';

import '../../../../models/user_role.dart';
import '../../domain/auth_exception.dart';
import '../../domain/usecases/login_usecase.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this._loginUseCase);

  final LoginUseCase _loginUseCase;
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  UserRole? authenticatedRole;
  bool isLoading = false;
  String? message;
  bool loginSuccess = false;

  Future<void> submit() async {
    if (usernameController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      message = 'Please enter your email or username and password.';
      loginSuccess = false;
      notifyListeners();
      return;
    }

    isLoading = true;
    message = null;
    notifyListeners();

    try {
      final result = await _loginUseCase(
        username: usernameController.text,
        password: passwordController.text,
      );
      authenticatedRole = result;
      loginSuccess = result != null;
      message = result != null
          ? 'Login successful. Opening ${result.label} access.'
          : 'Invalid email, username, or password.';
    } on AuthException catch (error) {
      authenticatedRole = null;
      loginSuccess = false;
      message = error.message;
    } on Object {
      authenticatedRole = null;
      loginSuccess = false;
      message = 'Login could not be completed. Please try again.';
    } finally {
      isLoading = false;
    }
    notifyListeners();
  }

  void setRoleMismatch(UserRole expectedRole) {
    authenticatedRole = null;
    loginSuccess = false;
    message =
        'This account is not authorized for ${expectedRole.label} access.';
    notifyListeners();
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
