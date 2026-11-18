part of '../../dashboard_shell_page.dart';

class _UserManagementPage extends StatefulWidget {
  const _UserManagementPage({required this.isAdmin});
  final bool isAdmin;

  @override
  State<_UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<_UserManagementPage> {
  final _db = AppDatabase.instance;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _search = '';
  String? _updatingId;
  bool _isLoading = true;
  String? _loadError;
  _RoleChangeRequest? _confirmChange;
  _UserToast? _toast;

  final List<_ManagedUser> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAdmin) {
      return const _TemplatePagePlaceholder(
        title: 'User Management',
        subtitle: 'Admins only.',
      );
    }

    final filtered = _filteredUsers();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // const _PageHeader(
        //   title: 'Users',
        //   subtitle: 'Manage accounts and roles.',
        // ),
        if (_toast != null) ...[
          _UserToastBanner(toast: _toast!),
          const SizedBox(height: 10),
        ],
        _RecordListCard(
          child: Column(
            children: [
              _RecordListToolbar(
                search: _RecordSearchField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  onChanged: (value) => setState(() => _search = value),
                  hintText: 'Search by name, user no, or email…',
                  focusColor: _UserManagementTheme.accent,
                ),
                trailing: [
                  _RecordCountBadge(
                    icon: HugeIcons.strokeRoundedUserGroup,
                    label: '${filtered.length} of ${_users.length}',
                  ),
                  IconButton(
                    tooltip: 'Refresh users',
                    onPressed: _isLoading ? null : _loadUsers,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(HugeIcons.strokeRoundedRefresh),
                  ),
                  _RecordPrimaryButton(
                    label: 'Add user',
                    onPressed: _addUser,
                    color: _UserManagementTheme.accent,
                  ),
                ],
              ),
              const Divider(height: 1, color: _RecordListTheme.border),
              if (_loadError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    _loadError!,
                    style: const TextStyle(
                      color: _UserManagementTheme.deleteIcon,
                    ),
                  ),
                )
              else if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 26),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 26),
                  child: Text(
                    'No users found.',
                    style: TextStyle(color: _UserManagementTheme.textMuted),
                  ),
                )
              else
                SizedBox(
                  height: 38 + (filtered.length * 54),
                  child: DataTable2(
                    columnSpacing: 12,
                    horizontalMargin: 10,
                    headingRowHeight: 38,
                    dataRowHeight: 54,
                    fixedTopRows: 1,
                    minWidth: 980,
                    dividerThickness: 1,
                    headingRowColor: WidgetStateProperty.all(
                      _UserManagementTheme.headerBg,
                    ),
                    dataRowColor:
                        WidgetStateProperty.resolveWith<Color?>((states) {
                      if (states.contains(WidgetState.hovered)) {
                        return const Color(0xFFF8FAFC);
                      }
                      return Colors.transparent;
                    }),
                    border: const TableBorder(
                      horizontalInside: BorderSide(
                        color: _UserManagementTheme.border,
                      ),
                    ),
                    columns: const [
                      DataColumn2(
                        label: Text('User No.', style: _userTableHeaderStyle),
                        fixedWidth: 108,
                      ),
                      DataColumn2(
                        label: Text('Name', style: _userTableHeaderStyle),
                        size: ColumnSize.L,
                      ),
                      DataColumn2(
                        label: Text('Username', style: _userTableHeaderStyle),
                        size: ColumnSize.M,
                      ),
                      DataColumn2(
                        label: Text('Role', style: _userTableHeaderStyle),
                        fixedWidth: 108,
                      ),
                      DataColumn2(
                        label: Text('Status', style: _userTableHeaderStyle),
                        fixedWidth: 108,
                      ),
                      DataColumn2(
                        label: Text('Last Login', style: _userTableHeaderStyle),
                        size: ColumnSize.M,
                      ),
                      DataColumn2(
                        label: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Actions',
                            style: _userTableHeaderStyle,
                          ),
                        ),
                        fixedWidth: 136,
                      ),
                    ],
                    rows: filtered.map((user) {
                      final isUpdating = _updatingId == user.id;
                      return DataRow2(
                        cells: [
                          DataCell(
                            Text(
                              user.id,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _UserManagementTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          DataCell(
                            _UserTwoLineCell(
                              primary: user.fullName,
                              secondary: user.email.isEmpty
                                  ? user.position
                                  : user.email,
                            ),
                          ),
                          DataCell(
                            Text(
                              user.username,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _UserManagementTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          DataCell(_RoleChip(role: user.role)),
                          DataCell(_StatusChip(status: user.status)),
                          DataCell(
                            Text(
                              _formatUserDate(user.lastLoginAt),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _UserManagementTheme.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: isUpdating
                                        ? null
                                        : () => _editUser(user),
                                    icon: isUpdating
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            HugeIcons.strokeRoundedEdit02,
                                            size: 16,
                                            color:
                                                _UserManagementTheme.editIcon,
                                          ),
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Change role',
                                  ),
                                  IconButton(
                                    onPressed: isUpdating
                                        ? null
                                        : () => _toggleUserStatus(user),
                                    icon: Icon(
                                      user.status.toLowerCase() == 'active'
                                          ? HugeIcons.strokeRoundedToggleOn
                                          : HugeIcons.strokeRoundedToggleOff,
                                      size: 18,
                                      color: _UserManagementTheme.editIcon,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Toggle status',
                                  ),
                                  IconButton(
                                    onPressed: () => _deleteUser(user),
                                    icon: const Icon(
                                      HugeIcons.strokeRoundedDelete02,
                                      size: 16,
                                      color: _UserManagementTheme.deleteIcon,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Remove user',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
        if (_confirmChange != null) ...[
          const SizedBox(height: 14),
          _UserRoleConfirmCard(
            change: _confirmChange!,
            isUpdating: _updatingId == _confirmChange!.user.id,
            onCancel: () => setState(() => _confirmChange = null),
            onConfirm: () => _applyRoleChange(_confirmChange!),
          ),
        ],
      ],
    );
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final rows = await _db.fetchUsers();
      if (!mounted) return;
      setState(() {
        _users
          ..clear()
          ..addAll(rows.map(_ManagedUser.fromMap));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load users: $e';
        _isLoading = false;
      });
    }
  }

  List<_ManagedUser> _filteredUsers() {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return List<_ManagedUser>.from(_users);
    return _users.where((user) {
      return user.id.toLowerCase().contains(q) ||
          user.username.toLowerCase().contains(q) ||
          user.fullName.toLowerCase().contains(q) ||
          user.email.toLowerCase().contains(q) ||
          user.status.toLowerCase().contains(q) ||
          user.position.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _addUser() async {
    final result = await _showUserDialog();
    if (result == null) return;
    try {
      final row = await _db.insertUser(
        userNo: result.userNo,
        username: result.username,
        fullName: result.fullName,
        email: result.email,
        role: result.role,
        password: result.password,
        status: result.status,
        position: result.position,
      );
      if (!mounted) return;
      setState(() {
        _users.insert(0, _ManagedUser.fromMap(row));
        _toast = _UserToast(
          kind: _UserToastKind.ok,
          msg: '${result.fullName} added.',
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _toast = _UserToast(kind: _UserToastKind.err, msg: 'Add failed: $e');
      });
    }
  }

  Future<void> _editUser(_ManagedUser user) async {
    final result = await _showUserDialog(user: user);
    if (result == null) return;
    setState(() => _updatingId = user.id);
    try {
      final row = await _db.updateUserAccount(
        userNo: user.id,
        username: result.username,
        fullName: result.fullName,
        email: result.email,
        role: result.role,
        password: result.password,
        status: result.status,
        position: result.position,
      );
      if (!mounted) return;
      final idx = _users.indexWhere((u) => u.id == user.id);
      if (idx != -1) {
        _users[idx] = _ManagedUser.fromMap(row);
      }
      setState(() {
        _updatingId = null;
        _toast = _UserToast(
          kind: _UserToastKind.ok,
          msg: '${result.fullName} updated.',
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _updatingId = null;
        _toast = _UserToast(kind: _UserToastKind.err, msg: 'Update failed: $e');
      });
    }
  }

  void _requestRoleChange(_ManagedUser user) {
    final nextRole = _nextManagedUserRole(user.role);
    setState(() {
      _confirmChange = _RoleChangeRequest(user: user, role: nextRole);
    });
  }

  Future<void> _applyRoleChange(_RoleChangeRequest request) async {
    setState(() => _updatingId = request.user.id);

    try {
      final row = await _db.updateUserRole(
        userNo: request.user.id,
        role: request.role,
      );
      if (!mounted) return;
      final idx = _users.indexWhere((u) => u.id == request.user.id);
      if (idx != -1) {
        _users[idx] = _ManagedUser.fromMap(row);
      }
      setState(() {
        _updatingId = null;
        _confirmChange = null;
        _toast = _UserToast(
          kind: _UserToastKind.ok,
          msg: 'Role updated to ${request.role}',
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _updatingId = null;
        _toast = _UserToast(
          kind: _UserToastKind.err,
          msg: 'Role update failed: $e',
        );
      });
    }
  }

  Future<void> _toggleUserStatus(_ManagedUser user) async {
    final nextStatus =
        user.status.toLowerCase() == 'active' ? 'inactive' : 'active';
    setState(() => _updatingId = user.id);
    try {
      final row = await _db.updateUserStatus(
        userNo: user.id,
        status: nextStatus,
      );
      if (!mounted) return;
      final idx = _users.indexWhere((u) => u.id == user.id);
      if (idx != -1) {
        _users[idx] = _ManagedUser.fromMap(row);
      }
      setState(() {
        _updatingId = null;
        _toast = _UserToast(
          kind: _UserToastKind.ok,
          msg: '${user.fullName} marked $nextStatus.',
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _updatingId = null;
        _toast = _UserToast(
          kind: _UserToastKind.err,
          msg: 'Status update failed: $e',
        );
      });
    }
  }

  Future<void> _deleteUser(_ManagedUser user) async {
    try {
      final ok = await _db.deleteUser(user.id);
      if (!mounted) return;
      setState(() {
        if (ok) {
          _users.removeWhere((u) => u.id == user.id);
        }
        _toast = _UserToast(
          kind: ok ? _UserToastKind.ok : _UserToastKind.err,
          msg: ok ? '${user.fullName} removed.' : 'User not found.',
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _toast = _UserToast(kind: _UserToastKind.err, msg: 'Remove failed: $e');
      });
    }
  }

  Future<_NewManagedUser?> _showUserDialog({_ManagedUser? user}) async {
    final editing = user != null;
    final userNoController = TextEditingController(text: user?.id ?? '');
    final usernameController =
        TextEditingController(text: user?.username ?? '');
    final nameController = TextEditingController(text: user?.fullName ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final positionController = TextEditingController(
      text: (user?.position.trim().isNotEmpty ?? false)
          ? user!.position
          : 'Registrar Staff',
    );
    final passwordController = TextEditingController();
    var role = user?.role.trim().toLowerCase() == 'admin' ? 'admin' : 'staff';
    var status =
        user?.status.trim().toLowerCase() == 'inactive' ? 'inactive' : 'active';
    var permissions = _defaultRbacPermissions(role);
    String? validationMessage;

    try {
      final result = await showDialog<_NewManagedUser>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                title: Text(editing ? 'Edit User' : 'Add User'),
                content: SizedBox(
                  width: 900,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (validationMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _UserManagementTheme.toastErrBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _UserManagementTheme.toastErrBorder,
                              ),
                            ),
                            child: Text(
                              validationMessage!,
                              style: const TextStyle(
                                color: _UserManagementTheme.toastErrFg,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 760;
                            final accountPanel = _AddUserPanel(
                              title: 'Account details',
                              child: Column(
                                children: [
                                  TextField(
                                    controller: userNoController,
                                    readOnly: editing,
                                    decoration: const InputDecoration(
                                      labelText: 'User No.',
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: usernameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Username',
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: nameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Full Name',
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: emailController,
                                    decoration: const InputDecoration(
                                      labelText: 'Email',
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  DropdownButtonFormField<String>(
                                    initialValue: status,
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'active',
                                        child: Text('Active'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'inactive',
                                        child: Text('Inactive'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setDialogState(
                                        () => status = value ?? 'active',
                                      );
                                    },
                                    decoration: const InputDecoration(
                                      labelText: 'Status',
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  DropdownButtonFormField<String>(
                                    initialValue: const [
                                      'Encoder',
                                      'Clerk',
                                      'Registrar Staff'
                                    ].contains(positionController.text)
                                        ? positionController.text
                                        : 'Registrar Staff',
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'Encoder',
                                        child: Text('Encoder'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Clerk',
                                        child: Text('Clerk'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Registrar Staff',
                                        child: Text('Registrar Staff'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      positionController.text =
                                          value ?? 'Registrar Staff';
                                    },
                                    decoration: const InputDecoration(
                                      labelText: 'Position',
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: passwordController,
                                    obscureText: true,
                                    decoration: InputDecoration(
                                      labelText: editing
                                          ? 'New password (optional)'
                                          : 'Password',
                                    ),
                                  ),
                                ],
                              ),
                            );
                            final accessPanel = _AddUserPanel(
                              title: 'Module access role',
                              child: Column(
                                children: [
                                  InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Effective role',
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          role == 'admin'
                                              ? Icons
                                                  .admin_panel_settings_outlined
                                              : HugeIcons.strokeRoundedId,
                                          size: 18,
                                          color: _UserManagementTheme.accent,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          role == 'admin'
                                              ? 'Administrator'
                                              : 'Staff',
                                          style: const TextStyle(
                                            color: _UserManagementTheme
                                                .textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: () {
                                            setDialogState(() {
                                              role = role == 'admin'
                                                  ? 'staff'
                                                  : 'admin';
                                              permissions =
                                                  _defaultRbacPermissions(role);
                                            });
                                          },
                                          child: Text(
                                            role == 'admin'
                                                ? 'Staff defaults'
                                                : 'Admin defaults',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _RbacPermissionChecklist(
                                    permissions: permissions,
                                    onChanged: (key, allowed) {
                                      setDialogState(() {
                                        permissions = {
                                          ...permissions,
                                          key: allowed,
                                        };
                                        role = _roleForRbacPermissions(
                                          permissions,
                                        );
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );

                            if (compact) {
                              return Column(
                                children: [
                                  accountPanel,
                                  const SizedBox(height: 14),
                                  accessPanel,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: accountPanel),
                                const SizedBox(width: 18),
                                Expanded(child: accessPanel),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final user = _NewManagedUser(
                        userNo: userNoController.text.trim(),
                        username: usernameController.text.trim(),
                        fullName: nameController.text.trim(),
                        email: emailController.text.trim(),
                        role: role,
                        status: status,
                        position: positionController.text.trim(),
                        password: passwordController.text,
                        permissions: _enabledRbacPermissionLabels(permissions),
                      );
                      if (!user.isValidForEdit(editing: editing)) {
                        setDialogState(() {
                          validationMessage = editing
                              ? 'User No., username, and full name are required.'
                              : 'User No., username, full name, email, and password are required.';
                        });
                        return;
                      }
                      Navigator.pop(ctx, user);
                    },
                    child: Text(editing ? 'Save changes' : 'Add user'),
                  ),
                ],
              );
            },
          );
        },
      );
      return result;
    } finally {
      userNoController.dispose();
      usernameController.dispose();
      nameController.dispose();
      emailController.dispose();
      positionController.dispose();
      passwordController.dispose();
    }
  }
}

class _AddUserPanel extends StatelessWidget {
  const _AddUserPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _UserManagementTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _UserManagementTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

const _rbacPermissionOptions = [
  _RbacPermissionOption(
    key: 'documents.upload',
    module: 'Documents',
    label: 'Upload documents',
    role: 'staff',
  ),
  _RbacPermissionOption(
    key: 'documents.delete',
    module: 'Documents',
    label: 'Remove documents',
    role: 'admin',
  ),
  _RbacPermissionOption(
    key: 'students.delete',
    module: 'Students',
    label: 'Remove student records',
    role: 'admin',
  ),
  _RbacPermissionOption(
    key: 'analytics.view',
    module: 'Analytics',
    label: 'View analytics',
    role: 'admin',
  ),
  _RbacPermissionOption(
    key: 'users.manage',
    module: 'Users',
    label: 'Manage users and roles',
    role: 'admin',
  ),
  _RbacPermissionOption(
    key: 'compliance.manage',
    module: 'Compliance',
    label: 'Manage compliance',
    role: 'admin',
  ),
  _RbacPermissionOption(
    key: 'backup.restore',
    module: 'Backup',
    label: 'Restore backups',
    role: 'admin',
  ),
  _RbacPermissionOption(
    key: 'disposal.manage',
    module: 'Disposal',
    label: 'Manage disposal',
    role: 'admin',
  ),
];

Map<String, bool> _defaultRbacPermissions(String role) {
  final normalized = role.trim().toLowerCase();
  return {
    for (final option in _rbacPermissionOptions)
      option.key: normalized == 'admin' || option.role == 'staff',
  };
}

String _roleForRbacPermissions(Map<String, bool> permissions) {
  final hasAdminPermission = _rbacPermissionOptions.any(
    (option) => option.role == 'admin' && (permissions[option.key] ?? false),
  );
  return hasAdminPermission ? 'admin' : 'staff';
}

List<String> _enabledRbacPermissionLabels(Map<String, bool> permissions) {
  return [
    for (final option in _rbacPermissionOptions)
      if (permissions[option.key] ?? false) option.label,
  ];
}

class _RbacPermissionOption {
  const _RbacPermissionOption({
    required this.key,
    required this.module,
    required this.label,
    required this.role,
  });

  final String key;
  final String module;
  final String label;
  final String role;
}

class _RbacPermissionChecklist extends StatelessWidget {
  const _RbacPermissionChecklist({
    required this.permissions,
    required this.onChanged,
  });

  final Map<String, bool> permissions;
  final void Function(String key, bool allowed) onChanged;

  @override
  Widget build(BuildContext context) {
    final seenModules = <String>{};
    final modules = <String>[
      for (final option in _rbacPermissionOptions)
        if (seenModules.add(option.module)) option.module,
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: _UserManagementTheme.headerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _UserManagementTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RBAC permissions',
            style: TextStyle(
              color: _UserManagementTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Admin-only permissions assign Administrator access.',
            style: TextStyle(
              color: _UserManagementTheme.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          for (final module in modules) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Text(
                module,
                style: const TextStyle(
                  color: _UserManagementTheme.textBody,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final option
                in _rbacPermissionOptions.where((o) => o.module == module))
              CheckboxListTile(
                value: permissions[option.key] ?? false,
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(option.label),
                subtitle: Text(
                  option.role == 'admin' ? 'Administrator' : 'Staff',
                  style: const TextStyle(fontSize: 11),
                ),
                onChanged: (value) => onChanged(option.key, value ?? false),
              ),
          ],
        ],
      ),
    );
  }
}

class _NewManagedUser {
  const _NewManagedUser({
    required this.userNo,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
    required this.status,
    required this.position,
    required this.password,
    required this.permissions,
  });

  final String userNo;
  final String username;
  final String fullName;
  final String email;
  final String role;
  final String status;
  final String position;
  final String password;
  final List<String> permissions;

  bool get isValid =>
      userNo.isNotEmpty &&
      username.isNotEmpty &&
      fullName.isNotEmpty &&
      email.isNotEmpty &&
      password.isNotEmpty;

  bool isValidForEdit({required bool editing}) {
    return userNo.isNotEmpty &&
        username.isNotEmpty &&
        fullName.isNotEmpty &&
        (editing || email.isNotEmpty) &&
        (editing || password.isNotEmpty);
  }
}
