part of '../../dashboard_shell_page.dart';

class _UserHeaderCell extends StatelessWidget {
  const _UserHeaderCell({
    required this.flex,
    required this.label,
    this.alignEnd = false,
  });

  final int flex;
  final String label;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Align(
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(label, style: _userTableHeaderStyle),
        ),
      ),
    );
  }
}

class _UserDataRow extends StatelessWidget {
  const _UserDataRow({
    required this.user,
    required this.isUpdating,
    required this.onEdit,
    required this.onStatusToggle,
    required this.onDelete,
  });

  final _ManagedUser user;
  final bool isUpdating;
  final VoidCallback onEdit;
  final VoidCallback onStatusToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _UserManagementTheme.border)),
      ),
      child: Row(
        children: [
          _UserCell(flex: 2, text: user.id, bold: true),
          _UserCell(
            flex: 3,
            child: _UserTwoLineCell(
              primary: user.fullName,
              secondary: user.email.isEmpty ? user.position : user.email,
            ),
          ),
          _UserCell(flex: 2, text: user.username),
          _UserCell(
            flex: 2,
            child: _RoleChip(role: user.role),
          ),
          _UserCell(
            flex: 2,
            child: _StatusChip(status: user.status),
          ),
          _UserCell(
            flex: 2,
            text: _formatUserDate(user.lastLoginAt),
            textColor: _UserManagementTheme.textMuted,
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: isUpdating ? null : onEdit,
                      icon: isUpdating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              HugeIcons.strokeRoundedEdit02,
                              size: 16,
                              color: _UserManagementTheme.editIcon,
                            ),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Change role',
                    ),
                    IconButton(
                      onPressed: isUpdating ? null : onStatusToggle,
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
                      onPressed: onDelete,
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
          ),
        ],
      ),
    );
  }
}

class _UserTwoLineCell extends StatelessWidget {
  const _UserTwoLineCell({required this.primary, required this.secondary});

  final String primary;
  final String secondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          primary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _UserManagementTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          secondary.isEmpty ? 'No email' : secondary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _UserManagementTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _UserCell extends StatelessWidget {
  const _UserCell({
    required this.flex,
    this.text,
    this.child,
    this.bold = false,
    this.textColor = _UserManagementTheme.textPrimary,
  });

  final int flex;
  final String? text;
  final Widget? child;
  final bool bold;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: child ??
            Text(
              text ?? '',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final active = status.toLowerCase() == 'active';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          active ? 'Active' : 'Inactive',
          style: TextStyle(
            color: active ? const Color(0xFF166534) : const Color(0xFFB91C1C),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final colors = _userRoleChipColors(role);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          role,
          style: TextStyle(
            color: colors.fg,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _UserRoleConfirmCard extends StatelessWidget {
  const _UserRoleConfirmCard({
    required this.change,
    required this.isUpdating,
    required this.onCancel,
    required this.onConfirm,
  });

  final _RoleChangeRequest change;
  final bool isUpdating;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 520,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _UserManagementTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Confirm Role Change', style: _userConfirmTitleStyle),
          const SizedBox(height: 8),
          Text(
            "Change ${change.user.fullName} role from ${change.user.role} to ${change.role}?",
            style: const TextStyle(color: _UserManagementTheme.textBody),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: isUpdating ? null : onConfirm,
                icon: isUpdating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(HugeIcons.strokeRoundedCheckmarkCircle02,
                        size: 16),
                label: const Text('Confirm'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserToastBanner extends StatelessWidget {
  const _UserToastBanner({required this.toast});
  final _UserToast toast;

  @override
  Widget build(BuildContext context) {
    final ok = toast.kind == _UserToastKind.ok;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: ok
            ? _UserManagementTheme.toastOkBg
            : _UserManagementTheme.toastErrBg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: ok
              ? _UserManagementTheme.toastOkBorder
              : _UserManagementTheme.toastErrBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            ok
                ? HugeIcons.strokeRoundedCheckmarkCircle02
                : HugeIcons.strokeRoundedAlertCircle,
            size: 17,
            color: ok
                ? _UserManagementTheme.toastOkFg
                : _UserManagementTheme.toastErrFg,
          ),
          const SizedBox(width: 8),
          Text(
            toast.msg,
            style: TextStyle(
              color: ok
                  ? _UserManagementTheme.toastOkFg
                  : _UserManagementTheme.toastErrFg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
