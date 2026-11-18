part of '../../dashboard_shell_page.dart';

class _BackupRestorePage extends StatefulWidget {
  const _BackupRestorePage({required this.isAdmin});

  final bool isAdmin;

  @override
  State<_BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<_BackupRestorePage> {
  static const _accent = Color(0xFF2563EB);

  final _db = AppDatabase.instance;
  final List<Map<String, Object?>> _backups = [];

  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBackups());
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAdmin) {
      return const _TemplatePagePlaceholder(
        title: 'Backup & Restore',
        subtitle: 'Administrators only.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageHeader(
          title: 'Backup & Restore',
          subtitle: 'Create, download, and restore archive database backups.',
        ),
        Expanded(
          child: _RecordListCard(
            child: Column(
              children: [
                _RecordListToolbar(
                  search: _RecordCountBadge(
                    icon: HugeIcons.strokeRoundedDatabaseRestore,
                    label: '${_backups.length} backups',
                    accentColor: _accent,
                  ),
                  trailing: [
                    IconButton(
                      tooltip: 'Refresh backups',
                      onPressed: _busy || _loading ? null : _loadBackups,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(HugeIcons.strokeRoundedRefresh),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _pickAndRestoreBackup,
                      icon:
                          const Icon(HugeIcons.strokeRoundedUpload01, size: 18),
                      label: const Text('Upload Restore'),
                    ),
                    FilledButton.icon(
                      onPressed: _busy ? null : _confirmCreateBackup,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(HugeIcons.strokeRoundedDatabaseExport,
                              size: 18),
                      label: const Text('Create Backup'),
                    ),
                  ],
                ),
                const Divider(height: 1, color: _RecordListTheme.border),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFB91C1C)),
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_backups.isEmpty) {
      return const Center(
        child: Text(
          'No backups yet. Create one to protect your archive data.',
          style: TextStyle(color: _RecordListTheme.textMuted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: _backups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final backup = _backups[index];
        final label = '${backup['label'] ?? 'backup'}';
        return _BackupHistoryTile(
          backup: backup,
          busy: _busy,
          onDownload: () => _downloadBackup(backup),
          onRestore: () => _confirmRestore(label),
        );
      },
    );
  }

  Future<void> _loadBackups() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _db.fetchBackups();
      if (!mounted) return;
      setState(() {
        _backups
          ..clear()
          ..addAll(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load backups: $e';
        _loading = false;
      });
    }
  }

  Future<void> _confirmCreateBackup() async {
    final ok = await _confirm(
      title: 'Create backup?',
      message: 'Create a new backup of the database and uploaded files?',
      action: 'Create',
    );
    if (ok == true) {
      await _runBusyAction(
        action: _db.createBackup,
        success: 'Backup created successfully.',
        reload: true,
      );
    }
  }

  Future<void> _confirmRestore(String label) async {
    final ok = await _confirm(
      title: 'Restore backup?',
      message:
          'This will replace the current database and uploads with "$label". Continue?',
      action: 'Restore',
      destructive: true,
    );
    if (ok == true) {
      await _runBusyAction(
        action: () => _db.restoreBackup(label),
        success: 'Backup restored successfully.',
        reload: true,
      );
    }
  }

  Future<void> _pickAndRestoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select backup database file',
      type: FileType.custom,
      allowedExtensions: const ['sql'],
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null || path.trim().isEmpty) return;

    final fileName = p.basename(path);
    final ok = await _confirm(
      title: 'Restore uploaded backup?',
      message:
          'Restore from "$fileName"? This will replace the current database. If the selected file came from a full backup folder, its uploads folder will be restored too.',
      action: 'Restore',
      destructive: true,
    );
    if (ok != true) return;

    await _runBusyAction(
      action: () => _db.restoreBackupFromFile(File(path)),
      success: 'Uploaded backup restored successfully.',
      reload: true,
    );
  }

  Future<void> _downloadBackup(Map<String, Object?> backup) async {
    if (_busy) return;
    await _runBusyAction(
      action: () async {
        final label = (backup['label'] ?? 'backup').toString();
        final backupPath = (backup['backup_path'] ?? '').toString();
        final dumpName = (backup['database_dump'] ?? 'database.sql').toString();
        final source = File(p.join(backupPath, dumpName));
        if (!await source.exists()) {
          throw StateError('Backup database file is missing.');
        }
        final target = await FilePicker.platform.saveFile(
          dialogTitle: 'Save backup database',
          fileName: '$label-database${p.extension(dumpName)}',
        );
        if (target == null) return null;
        return source.copy(target);
      },
      success: 'Backup file downloaded.',
    );
  }

  Future<void> _runBusyAction({
    required Future<Object?> Function() action,
    required String success,
    bool reload = false,
  }) async {
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await action();
      if (reload) await _loadBackups();
      if (!mounted) return;
      _showInfo(context, success);
    } catch (e) {
      if (!mounted) return;
      _showInfo(context, 'Action failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
  }
}

class _BackupHistoryTile extends StatelessWidget {
  const _BackupHistoryTile({
    required this.backup,
    required this.busy,
    required this.onDownload,
    required this.onRestore,
  });

  final Map<String, Object?> backup;
  final bool busy;
  final VoidCallback onDownload;
  final VoidCallback onRestore;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final label = '${backup['label'] ?? 'Backup'}';
    final createdAt = '${backup['created_at'] ?? ''}'.split('T').first;
    final rowCount = backup['row_count'] ?? 0;
    final databaseBytes = _intValue(backup['database_bytes']);
    final uploadBytes = _intValue(backup['uploads_bytes']);
    final totalBytes = _intValue(backup['size_bytes']);
    final path = '${backup['backup_path'] ?? ''}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _RecordListTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _BackupRestorePageState._accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              HugeIcons.strokeRoundedPackage,
              color: _BackupRestorePageState._accent,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _RecordListTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$createdAt - $rowCount rows - '
                  '${_formatBytes(totalBytes)} total',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _RecordListTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Database: ${_formatBytes(databaseBytes)} - '
                  'Uploads: ${_formatBytes(uploadBytes)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _RecordListTheme.textMuted,
                  ),
                ),
                if (path.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _RecordListTheme.textHint,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Wrap(
            spacing: 6,
            children: [
              IconButton(
                tooltip: 'Download database backup',
                onPressed: busy ? null : onDownload,
                icon: const Icon(HugeIcons.strokeRoundedDownload01),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onRestore,
                icon: const Icon(HugeIcons.strokeRoundedDatabaseRestore,
                    size: 17),
                label: const Text('Restore'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
