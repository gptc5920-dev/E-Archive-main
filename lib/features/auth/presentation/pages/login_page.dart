import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/widgets/app_asset_image.dart';
import '../../../../models/user_role.dart';
import '../../domain/usecases/login_usecase.dart';
import 'role_login_page.dart';

/// Role-choice landing page shown after the splash screen.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key, required this.loginUseCase});

  final LoginUseCase loginUseCase;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF6FBFF), Color(0xFFFFFAEE)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 900;
              final narrow = constraints.maxWidth < 520;
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: narrow ? 12 : (compact ? 22 : 56),
                  vertical: narrow ? 12 : (compact ? 18 : 28),
                ),
                child: Column(
                  children: [
                    _LandingHeader(compact: narrow),
                    Expanded(
                      child: compact
                          ? _CompactLandingBody(
                              loginUseCase: loginUseCase,
                              narrow: narrow,
                            )
                          : _WideLandingBody(loginUseCase: loginUseCase),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LandingHeader extends StatelessWidget {
  const _LandingHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HeaderLogoGroup(compact: compact),
        SizedBox(width: compact ? 8 : 12),
        const Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'E-Archive',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'JRMSU Registrar',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF7890AA),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderLogoGroup extends StatelessWidget {
  const _HeaderLogoGroup({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 34.0 : 42.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HeaderLogoImage(
          assetPath: 'assets/images/university-logo.png',
          useCover: true,
          size: size,
        ),
        SizedBox(width: compact ? 5 : 8),
        _HeaderLogoImage(
          assetPath: 'assets/images/bagongpilipinas.png',
          size: size,
        ),
        SizedBox(width: compact ? 5 : 8),
        _HeaderLogoImage(assetPath: 'assets/images/aacup.png', size: size),
      ],
    );
  }
}

class _HeaderLogoImage extends StatelessWidget {
  const _HeaderLogoImage({
    required this.assetPath,
    required this.size,
    this.useCover = false,
  });

  final String assetPath;
  final double size;
  final bool useCover;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: AppAssetImage(
        assetPath,
        width: size,
        height: size,
        fit: useCover ? BoxFit.cover : BoxFit.contain,
      ),
    );
  }
}

class _WideLandingBody extends StatelessWidget {
  const _WideLandingBody({required this.loginUseCase});

  final LoginUseCase loginUseCase;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 9,
          child: _LandingCopy(loginUseCase: loginUseCase),
        ),
        const SizedBox(width: 48),
        const Expanded(
          flex: 10,
          child: _LandingArt(),
        ),
      ],
    );
  }
}

class _CompactLandingBody extends StatelessWidget {
  const _CompactLandingBody({
    required this.loginUseCase,
    required this.narrow,
  });

  final LoginUseCase loginUseCase;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(top: narrow ? 22 : 36, bottom: 24),
        child: Column(
          children: [
            _LandingCopy(loginUseCase: loginUseCase),
            SizedBox(height: narrow ? 22 : 28),
            SizedBox(height: narrow ? 220 : 300, child: const _LandingArt()),
          ],
        ),
      ),
    );
  }
}

class _LandingCopy extends StatelessWidget {
  const _LandingCopy({required this.loginUseCase});

  final LoginUseCase loginUseCase;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 520;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8B8),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                children: [
                  Icon(
                    HugeIcons.strokeRoundedShieldUser,
                    size: 14,
                    color: Color(0xFF5C4B24),
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Restricted access portal',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF5C4B24),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: narrow ? 16 : 22),
            Text(
              'Student records,\norganized.',
              style: TextStyle(
                color: const Color(0xFF172033),
                fontSize: narrow ? 38 : 54,
                fontWeight: FontWeight.w900,
                height: narrow ? 1.0 : 0.95,
              ),
            ),
            SizedBox(height: narrow ? 14 : 18),
            Text(
              'A friendly, modern records platform for the JRMSU Registrar\'s Office - archiving every document since 2022. Choose your role to begin.',
              style: const TextStyle(
                color: Color(0xFF7890AA),
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
            SizedBox(height: narrow ? 20 : 28),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _RoleOption(
                  compact: narrow,
                  width: narrow ? double.infinity : 220,
                  role: UserRole.admin,
                  icon: HugeIcons.strokeRoundedUserShield01,
                  color: const Color(0xFFF59E0B),
                  onTap: () => _openRoleLogin(context, UserRole.admin),
                ),
                _RoleOption(
                  compact: narrow,
                  width: narrow ? double.infinity : 220,
                  role: UserRole.staff,
                  icon: HugeIcons.strokeRoundedUserGroup,
                  color: const Color(0xFF38BDF8),
                  onTap: () => _openRoleLogin(context, UserRole.staff),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openRoleLogin(BuildContext context, UserRole role) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoleLoginPage(
          loginUseCase: loginUseCase,
          showHomeNavigation: true,
          expectedRole: role,
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.compact,
    required this.width,
    required this.role,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final UserRole role;
  final bool compact;
  final double width;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: compact ? 150 : 210,
      child: Material(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE1E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F0F2E5D),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: compact
                ? Row(
                    children: [
                      _RoleOptionIcon(color: color, icon: icon),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _RoleOptionText(role: role),
                      ),
                      const Icon(
                        HugeIcons.strokeRoundedArrowRight01,
                        color: Color(0xFF1D4B8F),
                        size: 18,
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RoleOptionIcon(color: color, icon: icon),
                      const SizedBox(height: 18),
                      _RoleOptionText(role: role),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _RoleOptionIcon extends StatelessWidget {
  const _RoleOptionIcon({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _RoleOptionText extends StatelessWidget {
  const _RoleOptionText({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          role.label,
          style: const TextStyle(
            color: Color(0xFF172033),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          role.subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF7890AA),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sign in',
          style: TextStyle(
            color: Color(0xFF1D4B8F),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _LandingArt extends StatelessWidget {
  const _LandingArt();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDDF3FF), Color(0xFFFFF2C9), Color(0xFFE8EDF3)],
        ),
      ),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.58,
          child: AppAssetImage(
            'assets/images/login_page_image.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
