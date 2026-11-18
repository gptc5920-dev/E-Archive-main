part of '../../dashboard_shell_page.dart';

enum _DisposableSort { years, name, program, status }

class _DisposableRecordsPage extends StatefulWidget {
  const _DisposableRecordsPage({required this.isAdmin});

  final bool isAdmin;

  @override
  State<_DisposableRecordsPage> createState() => _DisposableRecordsPageState();
}

class _DisposableRecordsPageState extends State<_DisposableRecordsPage> {
  static const _accent = Color(0xFF0F766E);

  final _db = AppDatabase.instance;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final List<_DisposableRecord> _records = [];

  String _query = '';
  String _status = 'all';
  _DisposableSort _sort = _DisposableSort.years;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
        title: 'Disposable Records',
        subtitle: 'Administrators only.',
      );
    }

    final rows = _filteredRows();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // const _PageHeader(
        //   title: 'Disposable Records',
        //   subtitle:
        //       'Review student records beyond the 20-year retention period.',
        // ),
        Expanded(
          child: _RecordListCard(
            child: Column(
              children: [
                _RecordListToolbar(
                  search: _RecordSearchField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: (value) => setState(() => _query = value),
                    hintText: 'Search by student, ID, or program...',
                    focusColor: _accent,
                  ),
                  trailing: [
                    _DisposableDropdown<String>(
                      value: _status,
                      tooltip: 'Filter status',
                      icon: HugeIcons.strokeRoundedFilterHorizontal,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(
                            value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(
                            value: 'approved', child: Text('Approved')),
                        DropdownMenuItem(
                            value: 'disposed', child: Text('Disposed')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _status = value);
                      },
                    ),
                    const SizedBox(width: 8),
                    _DisposableDropdown<_DisposableSort>(
                      value: _sort,
                      tooltip: 'Sort records',
                      icon: HugeIcons.strokeRoundedSorting01,
                      items: const [
                        DropdownMenuItem(
                          value: _DisposableSort.years,
                          child: Text('Years'),
                        ),
                        DropdownMenuItem(
                          value: _DisposableSort.name,
                          child: Text('Name'),
                        ),
                        DropdownMenuItem(
                          value: _DisposableSort.program,
                          child: Text('Program'),
                        ),
                        DropdownMenuItem(
                          value: _DisposableSort.status,
                          child: Text('Status'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _sort = value);
                      },
                    ),
                    const SizedBox(width: 8),
                    _RecordCountBadge(
                      icon: HugeIcons.strokeRoundedPackage,
                      label: '${rows.length} of ${_records.length}',
                      accentColor: _accent,
                    ),
                    IconButton(
                      tooltip: 'Refresh records',
                      onPressed: _isLoading ? null : _load,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(HugeIcons.strokeRoundedRefresh),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _showReport,
                      icon: const Icon(HugeIcons.strokeRoundedFile02, size: 18),
                      label: const Text('Report'),
                    ),
                  ],
                ),
                const Divider(height: 1, color: _RecordListTheme.border),
                Expanded(child: _buildBody(rows)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(List<_DisposableRecord> rows) {
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Color(0xFFB91C1C)),
        ),
      );
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'No disposable records found.',
          style: TextStyle(color: _RecordListTheme.textMuted),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) {
          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) => _DisposableRecordCard(
              record: rows[index],
              onApprove: () => _confirmApprove(rows[index]),
              onDispose: () => _confirmDispose(rows[index]),
            ),
          );
        }

        return Column(
          children: [
            const _DisposableTableHeader(),
            Expanded(
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (_, index) => _DisposableTableRow(
                  record: rows[index],
                  onApprove: () => _confirmApprove(rows[index]),
                  onDispose: () => _confirmDispose(rows[index]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<_DisposableRecord> _filteredRows() {
    final q = _query.trim().toLowerCase();
    final rows = _records.where((record) {
      if (_status != 'all' && record.status != _status) return false;
      if (q.isEmpty) return true;
      return record.studentName.toLowerCase().contains(q) ||
          record.studentId.toLowerCase().contains(q) ||
          record.program.toLowerCase().contains(q);
    }).toList();

    rows.sort((a, b) {
      switch (_sort) {
        case _DisposableSort.name:
          return a.studentName.compareTo(b.studentName);
        case _DisposableSort.program:
          return a.program.compareTo(b.program);
        case _DisposableSort.status:
          return a.status.compareTo(b.status);
        case _DisposableSort.years:
          return b.yearsStored.compareTo(a.yearsStored);
      }
    });
    return rows;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final rows = await _db.fetchDisposableStudentRecords();
      if (!mounted) return;
      setState(() {
        _records
          ..clear()
          ..addAll(rows.map(_DisposableRecord.fromMap));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load disposable records: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmApprove(_DisposableRecord record) async {
    if (record.status != 'pending') return;
    final ok = await _confirm(
      title: 'Approve disposal?',
      message:
          'Approve ${record.studentName} (${record.studentId}) for disposal review?',
      action: 'Approve',
    );
    if (ok != true) return;
    await _runAction(
      () => _db.approveStudentDisposal(record.studentId),
      'Record approved for disposal.',
    );
  }

  Future<void> _confirmDispose(_DisposableRecord record) async {
    if (record.status == 'disposed') return;
    final ok = await _confirm(
      title: 'Mark as disposed?',
      message:
          'Mark ${record.studentName} (${record.studentId}) as disposed? The record will stay archived for audit trail.',
      action: 'Dispose',
      destructive: true,
    );
    if (ok != true) return;
    await _runAction(
      () => _db.markStudentDisposed(record.studentId),
      'Record marked disposed.',
    );
  }

  Future<void> _runAction(
    Future<Object?> Function() action,
    String success,
  ) async {
    try {
      await action();
      await _load();
      if (!mounted) return;
      _showInfo(context, success);
    } catch (e) {
      if (!mounted) return;
      _showInfo(context, 'Action failed: $e');
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

  Future<void> _showReport() async {
    try {
      final report = await _db.fetchDisposableStudentReport();
      if (!mounted) return;
      final pending = report['pending'] ?? 0;
      final approved = report['approved'] ?? 0;
      final disposed = report['disposed'] ?? 0;
      final total = report['total'] ?? 0;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Disposal Report'),
          content: Text(
            'Total: $total\nPending: $pending\nApproved: $approved\nDisposed: $disposed',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showInfo(context, 'Report failed: $e');
    }
  }
}

class _DisposableRecord {
  const _DisposableRecord({
    required this.studentName,
    required this.studentId,
    required this.program,
    required this.retentionDate,
    required this.retentionBasis,
    required this.yearsStored,
    required this.status,
  });

  final String studentName;
  final String studentId;
  final String program;
  final String retentionDate;
  final String retentionBasis;
  final int yearsStored;
  final String status;

  factory _DisposableRecord.fromMap(Map<String, Object?> row) {
    return _DisposableRecord(
      studentName: (row['student_name'] ?? '').toString(),
      studentId: (row['student_id'] ?? '').toString(),
      program: (row['course_program'] ?? '').toString(),
      retentionDate: (row['graduation_last_enrollment_date'] ?? '').toString(),
      retentionBasis: (row['retention_basis'] ?? '').toString(),
      yearsStored: int.tryParse('${row['years_stored'] ?? 0}') ?? 0,
      status: (row['disposal_status'] ?? 'pending').toString().toLowerCase(),
    );
  }
}

class _DisposableTableHeader extends StatelessWidget {
  const _DisposableTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      color: _RecordListTheme.headerBg,
      child: const Row(
        children: [
          _DisposableCell(flex: 3, text: 'Student'),
          _DisposableCell(flex: 2, text: 'Student ID'),
          _DisposableCell(flex: 3, text: 'Program'),
          _DisposableCell(flex: 2, text: 'Date'),
          _DisposableCell(flex: 2, text: 'Years'),
          _DisposableCell(flex: 2, text: 'Status'),
          _DisposableCell(flex: 3, text: 'Actions', alignEnd: true),
        ],
      ),
    );
  }
}

class _DisposableTableRow extends StatelessWidget {
  const _DisposableTableRow({
    required this.record,
    required this.onApprove,
    required this.onDispose,
  });

  final _DisposableRecord record;
  final VoidCallback onApprove;
  final VoidCallback onDispose;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _RecordListTheme.border)),
      ),
      child: Row(
        children: [
          _DisposableCell(flex: 3, text: record.studentName, bold: true),
          _DisposableCell(flex: 2, text: record.studentId),
          _DisposableCell(flex: 3, text: record.program),
          _DisposableCell(
            flex: 2,
            text: record.retentionDate,
            subtext: record.retentionBasis,
          ),
          _DisposableCell(flex: 2, text: '${record.yearsStored} years'),
          _DisposableCell(
            flex: 2,
            child: _DisposableStatusChip(status: record.status),
          ),
          Expanded(
            flex: 3,
            child: _DisposableActions(
              record: record,
              onApprove: onApprove,
              onDispose: onDispose,
            ),
          ),
        ],
      ),
    );
  }
}

class _DisposableRecordCard extends StatelessWidget {
  const _DisposableRecordCard({
    required this.record,
    required this.onApprove,
    required this.onDispose,
  });

  final _DisposableRecord record;
  final VoidCallback onApprove;
  final VoidCallback onDispose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _RecordListTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.studentName,
                  style: const TextStyle(
                    color: _RecordListTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _DisposableStatusChip(status: record.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${record.studentId} - ${record.program}',
            style: const TextStyle(color: _RecordListTheme.textMuted),
          ),
          const SizedBox(height: 6),
          Text(
            '${record.retentionDate} - ${record.yearsStored} years stored',
            style: const TextStyle(color: _RecordListTheme.textMuted),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: _DisposableActions(
              record: record,
              onApprove: onApprove,
              onDispose: onDispose,
            ),
          ),
        ],
      ),
    );
  }
}

class _DisposableCell extends StatelessWidget {
  const _DisposableCell({
    required this.flex,
    this.text,
    this.subtext,
    this.child,
    this.bold = false,
    this.alignEnd = false,
  });

  final int flex;
  final String? text;
  final String? subtext;
  final Widget? child;
  final bool bold;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Align(
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: child ??
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: alignEnd
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    text ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _RecordListTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (subtext != null && subtext!.isNotEmpty)
                    Text(
                      subtext!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _RecordListTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
        ),
      ),
    );
  }
}

class _DisposableStatusChip extends StatelessWidget {
  const _DisposableStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' => const Color(0xFF2563EB),
      'disposed' => const Color(0xFF64748B),
      _ => const Color(0xFFEA580C),
    };
    final label = status.isEmpty
        ? 'Pending'
        : '${status[0].toUpperCase()}${status.substring(1)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DisposableActions extends StatelessWidget {
  const _DisposableActions({
    required this.record,
    required this.onApprove,
    required this.onDispose,
  });

  final _DisposableRecord record;
  final VoidCallback onApprove;
  final VoidCallback onDispose;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      alignment: WrapAlignment.end,
      children: [
        Tooltip(
          message: 'Approve disposal',
          child: IconButton(
            onPressed: record.status == 'pending' ? onApprove : null,
            icon: const Icon(HugeIcons.strokeRoundedCheckmarkBadge02, size: 18),
          ),
        ),
        Tooltip(
          message: 'Mark disposed',
          child: IconButton(
            onPressed: record.status == 'disposed' ? null : onDispose,
            icon: const Icon(HugeIcons.strokeRoundedArchive, size: 18),
          ),
        ),
      ],
    );
  }
}

class _DisposableDropdown<T> extends StatelessWidget {
  const _DisposableDropdown({
    required this.value,
    required this.tooltip,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final String tooltip;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _RecordListTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: _RecordListTheme.textMuted),
            const SizedBox(width: 6),
            DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                items: items,
                onChanged: onChanged,
                style: const TextStyle(
                  color: _RecordListTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
