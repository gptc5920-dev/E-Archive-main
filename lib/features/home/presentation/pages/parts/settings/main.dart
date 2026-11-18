part of '../../dashboard_shell_page.dart';

class _SystemSettingsPage extends StatefulWidget {
  const _SystemSettingsPage({
    required this.accountName,
    required this.role,
    required this.auditRows,
    required this.isLoadingAudit,
    required this.onRefreshLogs,
  });

  final String accountName;
  final UserRole role;
  final List<_AuditRow> auditRows;
  final bool isLoadingAudit;
  final Future<void> Function() onRefreshLogs;

  @override
  State<_SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<_SystemSettingsPage> {
  final _backupLocationController = TextEditingController();
  bool _cloudBackup = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBackupLocation());
  }

  Future<void> _loadBackupLocation() async {
    final location = await AppDatabase.instance.backupLocation();
    if (!mounted) return;
    _backupLocationController.text = location;
  }

  @override
  void dispose() {
    _backupLocationController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final backupPath = _backupLocationController.text.trim();
    if (backupPath.isEmpty) {
      _showInfo(context, 'Choose a backup location before saving.');
      return;
    }

    try {
      await Directory(backupPath).create(recursive: true);
      await AppDatabase.instance.configureBackupLocation(backupPath);
      if (!mounted) return;
      _backupLocationController.text =
          await AppDatabase.instance.backupLocation();
      if (!mounted) return;
      _showInfo(context, 'Backup location saved.');
    } catch (e) {
      if (!mounted) return;
      _showInfo(context, 'Could not use that backup location: $e');
    }
  }

  Future<void> _chooseBackupLocation() async {
    final currentPath = _backupLocationController.text.trim();
    final initialDirectory =
        currentPath.isNotEmpty && Directory(currentPath).existsSync()
            ? currentPath
            : Directory.current.path;
    final selectedPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select backup location',
      initialDirectory: initialDirectory,
    );
    if (selectedPath == null || selectedPath.trim().isEmpty) return;
    if (!mounted) return;
    setState(() {
      _backupLocationController.text = selectedPath;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          breadcrumbs: const ['Settings'],
          title: 'Settings',
          subtitle: 'Configure backup, retention, and system activity.',
          trailing: FilledButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(HugeIcons.strokeRoundedFloppyDisk, size: 18),
            label: const Text('Save changes'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1D4B8F),
              foregroundColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SettingsSectionCard(
                      icon: HugeIcons.strokeRoundedHardDrive,
                      title: 'Backup Settings',
                      children: [
                        _SettingsTextRow(
                          label: 'Backup Location',
                          controller: _backupLocationController,
                          onBrowse: _chooseBackupLocation,
                        ),
                        _SettingsSwitchRow(
                          label: 'Enable Cloud Backup',
                          value: _cloudBackup,
                          onChanged: (value) {
                            setState(() => _cloudBackup = value);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SettingsSectionCard(
                      icon: HugeIcons.strokeRoundedTimeSchedule,
                      title: 'Trash Retention',
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            'Items in Trash are kept until an administrator '
                            'manually removes them.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF1D4B8F)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsTextRow extends StatelessWidget {
  const _SettingsTextRow({
    required this.label,
    required this.controller,
    this.onBrowse,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    return _SettingsFieldRow(
      label: label,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: _settingsInputDecoration.copyWith(
                prefixIcon:
                    const Icon(HugeIcons.strokeRoundedFolder01, size: 18),
                hintText: 'Choose a local backup folder',
              ),
            ),
          ),
          if (onBrowse != null) ...[
            const SizedBox(width: 10),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: onBrowse,
                icon: const Icon(HugeIcons.strokeRoundedFolderOpen, size: 18),
                label: const Text('Browse'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsFieldRow(
      label: label,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: const Color(0xFF1D4B8F),
        ),
      ),
    );
  }
}

class _SettingsFieldRow extends StatelessWidget {
  const _SettingsFieldRow({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 620;
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(label, style: _settingsLabelStyle),
                const SizedBox(height: 8),
                child,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 290,
                child: Text(label, style: _settingsLabelStyle),
              ),
              Expanded(child: child),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsAccountSummary extends StatelessWidget {
  const _SettingsAccountSummary({
    required this.accountName,
    required this.roleLabel,
  });

  final String accountName;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(HugeIcons.strokeRoundedUser03, color: Color(0xFF1D4B8F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              accountName.trim().isEmpty ? roleLabel : accountName.trim(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            roleLabel,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsLogRow extends StatelessWidget {
  const _SettingsLogRow({required this.row, required this.isLast});

  final _AuditRow row;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
      ),
      child: Row(
        children: [
          const Icon(
            HugeIcons.strokeRoundedTransactionHistory,
            size: 18,
            color: Color(0xFF64748B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${row.actor} ${row.action}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            row.date,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

const _settingsLabelStyle = TextStyle(
  color: Color(0xFF1F2937),
  fontSize: 14,
  fontWeight: FontWeight.w600,
);

final _settingsInputDecoration = InputDecoration(
  isDense: true,
  filled: true,
  fillColor: const Color(0xFFF8FAFC),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: Color(0xFF1D4B8F)),
  ),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
);

/// Settings area: add, edit, and delete colleges.
class _SettingsCollegesPage extends StatefulWidget {
  const _SettingsCollegesPage({
    required this.rows,
    required this.isLoading,
    required this.loadError,
    required this.onRefresh,
    required this.onAddCollege,
    required this.onUpdateCollege,
    required this.onDeleteCollege,
    this.courseCountByCollegeId,
  });

  final List<_CollegeRow> rows;
  final bool isLoading;
  final String? loadError;
  final VoidCallback onRefresh;
  final Future<String?> Function({required String name}) onAddCollege;
  final Future<String?> Function({
    required _CollegeRow college,
    required String name,
  }) onUpdateCollege;
  final Future<String?> Function(_CollegeRow college) onDeleteCollege;
  final Map<int, int>? courseCountByCollegeId;

  @override
  State<_SettingsCollegesPage> createState() => _SettingsCollegesPageState();
}

class _SettingsCollegesPageState extends State<_SettingsCollegesPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<_CollegeRow> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return widget.rows;
    return widget.rows.where((row) {
      final name = row.name.toLowerCase();
      final label = _collegeAddOptionLabel(row.name).toLowerCase();
      final display = _parseCollegeDisplayLabel(row.name);
      return name.contains(q) ||
          label.contains(q) ||
          display.code.toLowerCase().contains(q) ||
          display.fullName.toLowerCase().contains(q);
    }).toList();
  }

  bool get _hasSearchFilter => _searchController.text.trim().isNotEmpty;

  void _resetFilters() {
    setState(_searchController.clear);
  }

  Future<void> _openCollegeDialog({_CollegeRow? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _CollegeFormDialog(
        existing: existing,
        onAddCollege: widget.onAddCollege,
        onUpdateCollege: widget.onUpdateCollege,
      ),
    );

    if (saved == true && mounted) {
      _showInfo(
        context,
        existing == null
            ? 'College added to the database.'
            : 'College updated.',
      );
    }
  }

  Future<void> _confirmDelete(_CollegeRow college) async {
    final confirmed = await _showCollegeDeleteDialog(
      context,
      collegeName: college.name,
    );

    if (confirmed != true || !mounted) return;

    final error = await widget.onDeleteCollege(college);
    if (!mounted) return;

    if (error != null) {
      _showInfo(context, error);
      return;
    }

    _showInfo(context, 'College moved to Trash.');
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final showEmpty = !widget.isLoading && filtered.isEmpty;
    final countLabel =
        filtered.length == 1 ? '1 college' : '${filtered.length} colleges';

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.slash): () {
          _searchFocus.requestFocus();
        },
      },
      child: Focus(
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // const _PageHeader(
            //   breadcrumbs: ['Settings', 'Colleges'],
            //   title: 'Manage colleges',
            //   subtitle:
            //       'Add, edit, or remove colleges here. Student Records uses these entries for browsing only.',
            // ),
            if (widget.isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            if (widget.loadError != null)
              _RecordLoadBanner(
                message: widget.loadError!,
                onRetry: widget.onRefresh,
              ),
            Expanded(
              child: _RecordListCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RecordListToolbar(
                      search: _RecordSearchField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        onChanged: (_) => setState(() {}),
                        hintText: 'Search colleges…',
                        focusColor: _collegeTeal,
                      ),
                      trailing: [
                        if (!showEmpty)
                          _RecordCountBadge(
                            icon: HugeIcons.strokeRoundedUniversity,
                            label: countLabel,
                            accentColor: _collegeTeal,
                          ),
                        const SizedBox(width: 8),
                        _RecordPrimaryButton(
                          label: 'Add college',
                          onPressed: widget.isLoading
                              ? null
                              : () => _openCollegeDialog(),
                          color: const Color.fromARGB(255, 17, 25, 94),
                        ),
                      ],
                    ),
                    const Divider(height: 3, color: _RecordListTheme.border),
                    if (showEmpty)
                      _CollegesEmptyState(
                        canEdit: true,
                        hasSearchFilter: _hasSearchFilter,
                        onAdd: () => _openCollegeDialog(),
                        onResetFilters: _resetFilters,
                        addButtonLabel: 'Add college',
                      )
                    else
                      Expanded(
                        child: DefaultTextStyle.merge(
                          style: const TextStyle(fontSize: 16),
                          child: _CollegesSettingsList(
                            rows: filtered,
                            courseCountByCollegeId:
                                widget.courseCountByCollegeId,
                            onEdit: (college) =>
                                _openCollegeDialog(existing: college),
                            onDelete: _confirmDelete,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
