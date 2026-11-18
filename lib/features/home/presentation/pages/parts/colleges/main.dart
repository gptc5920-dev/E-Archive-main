part of '../../dashboard_shell_page.dart';

class _CollegesPage extends StatefulWidget {
  const _CollegesPage({
    required this.rows,
    required this.canEdit,
    required this.isLoading,
    required this.loadError,
    required this.onRefresh,
    required this.onAddCollege,
    required this.onUpdateCollege,
    required this.onDeleteCollege,
    this.onCollegeSelected,
    this.courseCountByCollegeId,
    this.breadcrumbs,
    this.pageTitle,
    this.pageSubtitle,
  });

  final List<_CollegeRow> rows;
  final bool canEdit;
  final bool isLoading;
  final String? loadError;
  final VoidCallback onRefresh;
  final Future<String?> Function({required String name}) onAddCollege;
  final Future<String?> Function({
    required _CollegeRow college,
    required String name,
  }) onUpdateCollege;
  final Future<String?> Function(_CollegeRow college) onDeleteCollege;
  final ValueChanged<_CollegeRow>? onCollegeSelected;
  final Map<int, int>? courseCountByCollegeId;
  final List<String>? breadcrumbs;
  final String? pageTitle;
  final String? pageSubtitle;

  @override
  State<_CollegesPage> createState() => _CollegesPageState();
}

class _CollegesPageState extends State<_CollegesPage> {
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
    return widget.rows
        .where(
          (row) =>
              row.name.toLowerCase().contains(q) ||
              _collegeAddOptionLabel(row.name).toLowerCase().contains(q),
        )
        .toList();
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
        existing != null
            ? 'College updated.'
            : 'College added to the database.',
      );
    }
  }

  Future<void> _confirmDelete(_CollegeRow college) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Move college to Trash?'),
        content: Text(
          'Move ${_collegeAddOptionLabel(college.name)} to Trash? You can restore it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
            ),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
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
            _PageHeader(
              breadcrumbs: widget.breadcrumbs ?? const ['Records', 'Colleges'],
              title: widget.pageTitle ?? 'Colleges',
              subtitle: widget.pageSubtitle ??
                  'Manage college units for browsing student records.',
            ),
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
                        if (widget.canEdit)
                          _RecordPrimaryButton(
                            label: 'Add college',
                            onPressed: widget.isLoading
                                ? null
                                : () => _openCollegeDialog(),
                            color: _collegeTealDark,
                          ),
                      ],
                    ),
                    const Divider(height: 1, color: _RecordListTheme.border),
                    if (showEmpty)
                      _CollegesEmptyState(
                        canEdit: widget.canEdit,
                        hasSearchFilter: _hasSearchFilter,
                        onAdd: () => _openCollegeDialog(),
                        onResetFilters: _resetFilters,
                      )
                    else
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.all(20),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 360,
                            mainAxisExtent: 190,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final college = filtered[index];
                            final courseCount = college.id != null
                                ? (widget
                                        .courseCountByCollegeId?[college.id!] ??
                                    0)
                                : 0;
                            return _CollegeCard(
                              college: college,
                              courseCount: courseCount,
                              onTap: widget.onCollegeSelected == null
                                  ? null
                                  : () => widget.onCollegeSelected!(college),
                              onEdit: widget.canEdit
                                  ? () => _openCollegeDialog(existing: college)
                                  : null,
                              onDelete: widget.canEdit
                                  ? () => _confirmDelete(college)
                                  : null,
                            );
                          },
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
