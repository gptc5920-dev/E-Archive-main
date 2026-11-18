part of '../../dashboard_shell_page.dart';

class _DocumentArchivePage extends StatefulWidget {
  const _DocumentArchivePage({
    required this.rows,
    required this.students,
    required this.colleges,
    required this.isAdmin,
    required this.isLoading,
    required this.loadError,
    required this.studentFilter,
    required this.onStudentFilterChanged,
    required this.onRefreshRequested,
    required this.onRestoreDoc,
    required this.onDeleteDoc,
    required this.onDeleteDocs,
    required this.onRestoreStudent,
    required this.onDeleteStudent,
    required this.onRestoreCollege,
    required this.onDeleteCollege,
  });
  final List<_DocRow> rows;
  final List<_StudentRow> students;
  final List<_CollegeRow> colleges;
  final bool isAdmin;
  final bool isLoading;
  final String? loadError;
  final String? studentFilter;
  final ValueChanged<String?> onStudentFilterChanged;
  final Future<void> Function() onRefreshRequested;
  final Future<bool> Function(_DocRow doc) onRestoreDoc;
  final Future<bool> Function(_DocRow doc) onDeleteDoc;
  final Future<int> Function(List<_DocRow> docs) onDeleteDocs;
  final Future<bool> Function(_StudentRow student) onRestoreStudent;
  final Future<String?> Function(_StudentRow student) onDeleteStudent;
  final Future<bool> Function(_CollegeRow college) onRestoreCollege;
  final Future<String?> Function(_CollegeRow college) onDeleteCollege;

  @override
  State<_DocumentArchivePage> createState() => _DocumentArchivePageState();
}

class _DocumentArchivePageState extends State<_DocumentArchivePage> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _type = 'All';
  bool _bulkMode = false;
  final Set<String> _selectedDocIds = <String>{};
  final Set<String> _expandedStudents = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _docId(_DocRow doc) => doc.id.isNotEmpty
      ? doc.id
      : '${doc.title}|${doc.student}|${doc.uploaded}';

  void _openDocumentViewer(_DocRow doc) {
    if (!_canPreviewDocument(doc)) {
      _showInfo(context, 'Preview is not available for this document.');
      return;
    }

    _showResizableDocumentViewer(context, document: doc);
  }

  Map<String, List<_DocRow>> _groupByStudent(List<_DocRow> docs) {
    final grouped = <String, List<_DocRow>>{};
    for (final doc in docs) {
      final student =
          doc.student.trim().isEmpty ? 'Unknown student' : doc.student.trim();
      grouped.putIfAbsent(student, () => []).add(doc);
    }
    return grouped;
  }

  Future<void> _confirmDeleteAll(
    BuildContext context,
    List<_DocRow> docs,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remove all documents?'),
            content: Text(
              'Permanently remove ${docs.length} document${docs.length == 1 ? '' : 's'} from trash?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                ),
                child: const Text('Remove all'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final deleted = await widget.onDeleteDocs(docs);
    if (!context.mounted) return;
    _showInfo(
      context,
      deleted == docs.length
          ? 'All documents removed.'
          : 'Removed $deleted of ${docs.length} document(s).',
    );
  }

  Future<void> _deleteSelectedFiltered(List<_DocRow> filtered) async {
    final docsToDelete =
        filtered.where((doc) => _selectedDocIds.contains(_docId(doc))).toList();
    if (docsToDelete.isEmpty) return;

    final deleted = await widget.onDeleteDocs(docsToDelete);
    if (!mounted) return;
    setState(() {
      _selectedDocIds.removeWhere(
        (id) => docsToDelete.any((d) => _docId(d) == id),
      );
    });
    _showInfo(
      context,
      deleted == docsToDelete.length
          ? 'Removed $deleted document(s).'
          : 'Removed $deleted of ${docsToDelete.length} document(s).',
    );
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _type = 'All';
      widget.onStudentFilterChanged(null);
    });
  }

  Future<void> _confirmEntityDelete({
    required String label,
    required Future<String?> Function() onDelete,
  }) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remove permanently?'),
            content: Text(
              'Permanently remove $label from Trash? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                ),
                child: const Text('Remove permanently'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final error = await onDelete();
    if (!mounted) return;
    _showInfo(context, error ?? 'Item removed permanently.');
  }

  Widget _buildDeletedEntityItems() {
    final itemCount = widget.students.length + widget.colleges.length;
    if (itemCount == 0) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 240),
      child: ListView(
        shrinkWrap: true,
        children: [
          if (widget.students.isNotEmpty)
            const _TrashEntityHeader(label: 'Students'),
          for (final student in widget.students)
            _TrashEntityRow(
              icon: HugeIcons.strokeRoundedUser,
              title: student.fullName,
              subtitle: '${student.studentNo} · ${student.course}',
              isAdmin: widget.isAdmin,
              onRestore: () async {
                final restored = await widget.onRestoreStudent(student);
                if (!mounted) return;
                _showInfo(
                  context,
                  restored ? 'Student restored.' : 'Restore failed.',
                );
              },
              onDelete: () => _confirmEntityDelete(
                label: student.fullName,
                onDelete: () => widget.onDeleteStudent(student),
              ),
            ),
          if (widget.colleges.isNotEmpty)
            const _TrashEntityHeader(label: 'Colleges'),
          for (final college in widget.colleges)
            _TrashEntityRow(
              icon: HugeIcons.strokeRoundedBuilding03,
              title: college.name,
              subtitle: 'College',
              isAdmin: widget.isAdmin,
              onRestore: () async {
                final restored = await widget.onRestoreCollege(college);
                if (!mounted) return;
                _showInfo(
                  context,
                  restored ? 'College restored.' : 'Restore failed.',
                );
              },
              onDelete: () => _confirmEntityDelete(
                label: college.name,
                onDelete: () => widget.onDeleteCollege(college),
              ),
            ),
        ],
      ),
    );
  }

  List<_DocRow> _filteredRows() {
    final studentFilter = widget.studentFilter?.trim();
    final hasStudentFilter = studentFilter != null && studentFilter.isNotEmpty;
    final q = _searchController.text.trim().toLowerCase();
    return widget.rows.where((d) {
      if (hasStudentFilter &&
          d.student.trim().toLowerCase() != studentFilter.toLowerCase()) {
        return false;
      }
      if (_type != 'All' &&
          !d.type.toLowerCase().contains(_type.toLowerCase())) {
        return false;
      }
      return _documentMatchesSearch(d, q);
    }).toList();
  }

  Widget _buildDocRows(List<_DocRow> docs, {bool nested = false}) {
    if (docs.isEmpty) return const SizedBox.shrink();

    return ListView.builder(
      shrinkWrap: nested,
      physics: nested ? const NeverScrollableScrollPhysics() : null,
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final d = docs[index];
        return _ArchiveDataRow(
          doc: d,
          isAdmin: widget.isAdmin,
          bulkMode: _bulkMode,
          selected: _selectedDocIds.contains(_docId(d)),
          isLast: index == docs.length - 1,
          canViewImage: _canPreviewDocument(d),
          onToggleSelected: (selected) {
            final id = _docId(d);
            setState(() {
              if (selected) {
                _selectedDocIds.add(id);
              } else {
                _selectedDocIds.remove(id);
              }
            });
          },
          onViewImage: () => _openDocumentViewer(d),
          onDownload: () => _showInfo(
            context,
            'Download is not available yet.',
          ),
          onRestore: () async {
            final restored = await widget.onRestoreDoc(d);
            if (!context.mounted) return;
            _showInfo(
              context,
              restored ? 'Document restored.' : 'Restore failed. Try again.',
            );
          },
          onDelete: () async {
            final deleted = await widget.onDeleteDoc(d);
            if (!context.mounted) return;
            _showInfo(
              context,
              deleted ? 'Document removed.' : 'Remove failed. Try again.',
            );
          },
        );
      },
    );
  }

  Widget _buildGroupedByStudent(List<_DocRow> docs) {
    final grouped = _groupByStudent(docs);
    final students = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return ListView.builder(
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return _StudentDocumentGroup(
          student: student,
          docs: grouped[student]!,
          expanded: _expandedStudents.contains(student),
          onToggle: () {
            setState(() {
              if (_expandedStudents.contains(student)) {
                _expandedStudents.remove(student);
              } else {
                _expandedStudents.add(student);
              }
            });
          },
          child: _buildDocRows(grouped[student]!, nested: true),
        );
      },
    );
  }

  Widget _buildTableBody(List<_DocRow> filtered) {
    final hasStudentFilter = widget.studentFilter?.trim().isNotEmpty ?? false;
    if (hasStudentFilter || _bulkMode) {
      return _buildDocRows(filtered);
    }
    return _buildGroupedByStudent(filtered);
  }

  @override
  Widget build(BuildContext context) {
    final studentFilter = widget.studentFilter?.trim();
    final hasStudentFilter = studentFilter != null && studentFilter.isNotEmpty;
    final filtered = _filteredRows();
    final filteredIds = filtered.map(_docId).toList();
    final selectedInFiltered =
        filteredIds.where((id) => _selectedDocIds.contains(id)).length;
    final canSelectAll = filtered.isNotEmpty;
    final isAllFilteredSelected =
        canSelectAll && selectedInFiltered == filtered.length;
    final studentGroupCount =
        hasStudentFilter ? 0 : _groupByStudent(filtered).length;
    final otherItemCount = widget.students.length + widget.colleges.length;
    final showEmpty = !widget.isLoading && filtered.isEmpty;
    final hasActiveFilters = _searchController.text.trim().isNotEmpty ||
        _type != 'All' ||
        hasStudentFilter;
    final countLabel = hasStudentFilter
        ? (filtered.length == 1 ? '1 document' : '${filtered.length} documents')
        : (filtered.length == 1
            ? '1 document · 1 student'
            : '${filtered.length} documents · $studentGroupCount students');
    final breadcrumbs = hasStudentFilter
        ? ['Records', 'Trash', studentFilter]
        : const ['Records', 'Trash'];

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
            _PageHeader(
              breadcrumbs: breadcrumbs,
              onBack: hasStudentFilter
                  ? () => widget.onStudentFilterChanged(null)
                  : null,
              title: 'Trash',
              subtitle: hasStudentFilter
                  ? 'Documents for $studentFilter.'
                  : 'Removed documents, students, and colleges.',
              trailing: TextButton.icon(
                onPressed: widget.isLoading ? null : widget.onRefreshRequested,
                icon: const Icon(HugeIcons.strokeRoundedRefresh, size: 18),
                label: const Text('Refresh'),
                style: TextButton.styleFrom(
                  foregroundColor: _RecordListTheme.textMuted,
                ),
              ),
            ),
            if (widget.isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            if (widget.loadError != null)
              _RecordLoadBanner(
                message: widget.loadError!,
                onRetry: widget.onRefreshRequested,
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
                        hintText: hasStudentFilter
                            ? 'Search this student\'s documents…'
                            : 'Search by title or student…',
                        focusColor: _archiveAccent,
                      ),
                      trailing: [
                        if (!showEmpty)
                          _RecordCountBadge(
                            icon: HugeIcons.strokeRoundedDelete02,
                            label: countLabel,
                            accentColor: _archiveAccent,
                          ),
                      ],
                    ),
                    const Divider(height: 1, color: _RecordListTheme.border),
                    _buildDeletedEntityItems(),
                    if (otherItemCount > 0)
                      const Divider(
                        height: 1,
                        color: _RecordListTheme.border,
                      ),
                    _ArchiveFilterBar(
                      type: _type,
                      bulkMode: _bulkMode,
                      isAdmin: widget.isAdmin,
                      canDeleteAll: filtered.isNotEmpty,
                      onTypeChanged: (v) => setState(() => _type = v),
                      onBulkModeToggle: () {
                        setState(() {
                          _bulkMode = !_bulkMode;
                          if (!_bulkMode) _selectedDocIds.clear();
                        });
                      },
                      onDeleteAll: widget.isAdmin
                          ? () => _confirmDeleteAll(context, filtered)
                          : null,
                    ),
                    if (_bulkMode)
                      _ArchiveBulkBar(
                        selectedCount: selectedInFiltered,
                        canSelectAll: canSelectAll,
                        isAllSelected: isAllFilteredSelected,
                        onToggleSelectAll: () {
                          setState(() {
                            if (isAllFilteredSelected) {
                              _selectedDocIds.removeWhere(
                                filteredIds.contains,
                              );
                            } else {
                              _selectedDocIds.addAll(filteredIds);
                            }
                          });
                        },
                        onDownloadSelected: () => _showInfo(
                          context,
                          'Bulk download is UI-only for $selectedInFiltered document(s).',
                        ),
                        onDeleteSelected:
                            widget.isAdmin && selectedInFiltered > 0
                                ? () => _deleteSelectedFiltered(filtered)
                                : null,
                      ),
                    if (showEmpty)
                      _ArchiveEmptyState(
                        hasFilters: hasActiveFilters,
                        studentFilter: studentFilter,
                        onClearFilters: hasActiveFilters ? _clearFilters : null,
                      )
                    else ...[
                      _ArchiveTableHeader(
                        bulkMode: _bulkMode,
                        canSelectAll: canSelectAll,
                        isAllSelected: isAllFilteredSelected,
                        selectedCount: selectedInFiltered,
                        onSelectAll: canSelectAll
                            ? (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedDocIds.addAll(filteredIds);
                                  } else {
                                    _selectedDocIds.removeWhere(
                                      filteredIds.contains,
                                    );
                                  }
                                });
                              }
                            : null,
                      ),
                      Expanded(child: _buildTableBody(filtered)),
                    ],
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
