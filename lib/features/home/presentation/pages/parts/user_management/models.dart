part of '../../dashboard_shell_page.dart';

class _ManagedUser {
  const _ManagedUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.email,
    required this.status,
    required this.position,
    required this.lastLoginAt,
  });

  final String id;
  final String username;
  final String fullName;
  final String role;
  final String email;
  final String status;
  final String position;
  final String lastLoginAt;

  factory _ManagedUser.fromMap(Map<String, Object?> row) {
    return _ManagedUser(
      id: (row['user_no'] ?? row['id'] ?? '').toString(),
      username: (row['username'] ?? '').toString(),
      fullName: (row['full_name'] ?? '').toString(),
      role: (row['role'] ?? '').toString(),
      email: (row['email'] ?? '').toString(),
      status: (row['status'] ?? 'active').toString(),
      position: (row['position'] ?? '').toString(),
      lastLoginAt: (row['last_login_at'] ?? '').toString(),
    );
  }

  _ManagedUser copyWith({String? role, String? status}) {
    return _ManagedUser(
      id: id,
      username: username,
      fullName: fullName,
      role: role ?? this.role,
      email: email,
      status: status ?? this.status,
      position: position,
      lastLoginAt: lastLoginAt,
    );
  }
}

class _RoleChangeRequest {
  const _RoleChangeRequest({required this.user, required this.role});
  final _ManagedUser user;
  final String role;
}

enum _UserToastKind { ok, err }

class _UserToast {
  const _UserToast({required this.kind, required this.msg});
  final _UserToastKind kind;
  final String msg;
}
