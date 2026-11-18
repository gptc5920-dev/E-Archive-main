import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../models/user_role.dart';
import '../../../home/presentation/pages/dashboard_shell_page.dart';
import '../../domain/usecases/login_usecase.dart';
import '../viewmodels/login_view_model.dart';

class RoleLoginPage extends StatefulWidget {
  const RoleLoginPage({
    super.key,
    required this.loginUseCase,
    this.showHomeNavigation = false,
    this.expectedRole,
  });

  final LoginUseCase loginUseCase;
  final bool showHomeNavigation;
  final UserRole? expectedRole;

  @override
  State<RoleLoginPage> createState() => _RoleLoginPageState();
}

class _RoleLoginPageState extends State<RoleLoginPage> {
  late final LoginViewModel _viewModel;
  late UserRole _activeRole;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _activeRole = widget.expectedRole ?? UserRole.admin;
    _viewModel = LoginViewModel(widget.loginUseCase);
    _viewModel.addListener(_refresh);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);
    _viewModel.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ColoredBox(
        color: const Color(0xFFF8FAFC),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxHeight < 740 || constraints.maxWidth < 520;
              final narrow = constraints.maxWidth < 380;

              if (!compact) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 32,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: _buildLoginCard(
                          compact: compact,
                          narrow: false,
                        ),
                      ),
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 4,
                        child: _LoginFooter(),
                      ),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                clipBehavior: Clip.none,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth,
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: narrow ? 10 : 18,
                      vertical: narrow ? 10 : 18,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLoginCard(compact: compact, narrow: narrow),
                        const Padding(
                          padding: EdgeInsets.only(top: 18, bottom: 4),
                          child: _LoginFooter(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard({
    required bool compact,
    required bool narrow,
  }) {
    final isAdmin = _activeRole == UserRole.admin;
    final accentColor =
        isAdmin ? const Color(0xFFF59E0B) : const Color(0xFF0EA5E9);
    final roleIcon = isAdmin
        ? HugeIcons.strokeRoundedUserShield01
        : HugeIcons.strokeRoundedUserGroup;
    final oppositeRole = isAdmin ? UserRole.staff : UserRole.admin;
    final cardPadding = EdgeInsets.fromLTRB(
      narrow ? 16 : (compact ? 22 : 36),
      narrow ? 16 : (compact ? 22 : 36),
      narrow ? 16 : (compact ? 22 : 36),
      narrow ? 16 : (compact ? 22 : 28),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 446),
      child: Container(
        padding: cardPadding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFD8E1EC)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F0F172A),
              blurRadius: 30,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: narrow ? 44 : (compact ? 52 : 56),
                height: narrow ? 44 : (compact ? 52 : 56),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  roleIcon,
                  color: accentColor,
                  size: narrow ? 23 : (compact ? 26 : 30),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: _AccessBadge(
                label: '${_activeRole.label} Access',
                color: accentColor,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '${_activeRole.label} Login',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF172033),
                  fontSize: narrow ? 24 : (compact ? 28 : 30),
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                isAdmin
                    ? 'Sign in to manage the E-Archive System'
                    : 'Sign in to access daily registrar operations',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6F819A),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: narrow ? 18 : (compact ? 24 : 28)),
            const _FieldLabel('Email or username'),
            const SizedBox(height: 8),
            TextField(
              controller: _viewModel.usernameController,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              decoration: _inputDecoration(
                'you@jrmsu.edu.ph or username',
                compact: compact,
              ).copyWith(
                prefixIcon: const Icon(HugeIcons.strokeRoundedMail01,
                    color: Color(0xFF607895)),
              ),
            ),
            SizedBox(height: compact ? 14 : 18),
            const _FieldLabel('Password'),
            const SizedBox(height: 8),
            TextField(
              controller: _viewModel.passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_viewModel.isLoading) _handleSignIn();
              },
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration:
                  _inputDecoration('Enter your password', compact: compact)
                      .copyWith(
                prefixIcon: const Icon(
                  HugeIcons.strokeRoundedLock,
                  color: Color(0xFF607895),
                ),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword
                        ? HugeIcons.strokeRoundedView
                        : HugeIcons.strokeRoundedViewOff,
                    color: const Color(0xFF607895),
                    size: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPasswordDialog,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1D4B8F),
                  minimumSize: const Size(0, 32),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            SizedBox(height: compact ? 12 : 14),
            SizedBox(
              width: double.infinity,
              height: compact ? 46 : 52,
              child: ElevatedButton(
                onPressed: _viewModel.isLoading ? null : _handleSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4B8F),
                  foregroundColor: Colors.white,
                  elevation: 7,
                  shadowColor: const Color(0x401D4B8F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _viewModel.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Sign in as ${isAdmin ? 'Admin' : 'Staff'}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 14 : 15,
                        ),
                      ),
              ),
            ),
            if (_viewModel.message != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: (_viewModel.loginSuccess
                          ? AppColors.success
                          : AppColors.error)
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _viewModel.message!,
                  style: TextStyle(
                    color: _viewModel.loginSuccess
                        ? const Color(0xFF15803D)
                        : const Color(0xFFB91C1C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            SizedBox(height: compact ? 18 : 24),
            const Divider(color: Color(0xFFD8E1EC), height: 1),
            SizedBox(height: compact ? 18 : 20),
            SizedBox(
              width: double.infinity,
              height: compact ? 44 : 48,
              child: OutlinedButton.icon(
                onPressed: () => _switchRole(oppositeRole),
                icon: const Icon(HugeIcons.strokeRoundedShieldUser, size: 18),
                label: Text(
                  'Switch to ${oppositeRole.label} Login',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF172033),
                  side: const BorderSide(color: Color(0xFFD8E1EC)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                'Access is restricted to administrators and registrar staff only.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF7A8DA6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _switchRole(UserRole role) {
    setState(() {
      _activeRole = role;
    });
  }

  Future<void> _handleSignIn() async {
    await _viewModel.submit();
    final role = _viewModel.authenticatedRole;

    if (!mounted || !_viewModel.loginSuccess || role == null) return;

    if (role != _activeRole) {
      _viewModel.setRoleMismatch(_activeRole);
      return;
    }

    await windowManager.restore();
    await windowManager.maximize();
    await windowManager.focus();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DashboardShellPage(
          role: role,
          loginUseCase: widget.loginUseCase,
          accountName: _viewModel.usernameController.text.trim(),
        ),
      ),
    );
  }

  Future<void> _showForgotPasswordDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Password recovery',
          style: TextStyle(
            color: Color(0xFF172033),
            fontWeight: FontWeight.w900,
          ),
        ),
        content: const SizedBox(
          width: 420,
          child: Text(
            'For account security, password resets require administrator '
            'verification. Contact an administrator to reset your password '
            'through User Management.',
            style: TextStyle(
              color: Color(0xFF607895),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {bool compact = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: compact ? 13 : 15,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD8E1EC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF93C5FD)),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _AccessBadge extends StatelessWidget {
  const _AccessBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(HugeIcons.strokeRoundedShieldUser, color: color, size: 13),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginFooter extends StatelessWidget {
  const _LoginFooter();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '© 2026 JRMSU Registrar\'s Office',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Color(0xFF607895),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF172033),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
