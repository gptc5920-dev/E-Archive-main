part of '../../dashboard_shell_page.dart';

const _docMutedStyle = TextStyle(
  color: _RecordListTheme.textMuted,
  fontSize: 12,
);

class _DocumentModulePage extends StatefulWidget {
  const _DocumentModulePage({
    required this.rows,
    required this.students,
    required this.courses,
    required this.colleges,
    required this.isLoading,
    required this.loadError,
    required this.studentFilter,
    required this.onStudentFilterChanged,
    required this.onRefreshRequested,
    required this.onQueryChanged,
    required this.onLoadMore,
    required this.hasMore,
    required this.totalCount,
    required this.onUploadDocument,
    required this.onUpdateDocument,
    required this.onDeleteDocument,
    required this.canDelete,
  });

  final List<_DocRow> rows;
  final List<_StudentRow> students;
  final List<_CourseRow> courses;
  final List<_CollegeRow> colleges;
  final bool isLoading;
  final String? loadError;
  final String? studentFilter;
  final ValueChanged<String?> onStudentFilterChanged;
  final Future<void> Function() onRefreshRequested;
  final Future<void> Function({
    String search,
    String schoolYear,
    String college,
    String program,
    String documentType,
  }) onQueryChanged;
  final Future<void> Function() onLoadMore;
  final bool hasMore;
  final int totalCount;
  final Future<bool> Function({
    required String title,
    required String student,
    required String sourceImagePath,
    required String mimeType,
    String studentNo,
    String course,
    String schoolYear,
    String documentType,
    bool isComplete,
    String college,
    String studentCategory,
    String tags,
    String storagePath,
  }) onUploadDocument;
  final Future<_DocRow?> Function({
    required _DocRow document,
    required String title,
    required String documentType,
    required String schoolYear,
    required String program,
    required String studentNo,
    required String storagePath,
    required String college,
    required String tags,
  }) onUpdateDocument;
  final Future<bool> Function(_DocRow document) onDeleteDocument;
  final bool canDelete;

  @override
  State<_DocumentModulePage> createState() => _DocumentModulePageState();
}

class _DocumentModulePageState extends State<_DocumentModulePage> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String? _batchFilter;
  String? _collegeFilter;
  String? _programFilter;
  String? _typeFilter;
  String? _selectedDocumentId;
  bool _sortAz = true;
  bool _previewCollapsed = true;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _runServerQuery() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      widget.onQueryChanged(
        search: _searchController.text.trim(),
        schoolYear: _batchFilter ?? '',
        college: _collegeFilter ?? '',
        program: _programFilter ?? '',
        documentType: _typeFilter ?? '',
      );
    });
  }

  String _key(String value) => value.trim().toLowerCase();

  Map<String, _StudentRow> get _studentsByName => {
        for (final student in widget.students)
          if (student.fullName.trim().isNotEmpty)
            _key(student.fullName): student,
      };

  Map<String, _CourseRow> get _coursesByName => {
        for (final course in widget.courses)
          if (course.name.trim().isNotEmpty) _key(course.name): course,
      };

  Map<int, String> get _collegeNameById => {
        for (final college in widget.colleges)
          if (college.id != null) college.id!: college.name,
      };

  String _batchForDocument(_DocRow doc) {
    if (doc.schoolYear.trim().isNotEmpty) return doc.schoolYear.trim();
    final student = _studentsByName[_key(doc.student)];
    if (student != null) return _schoolYearForStudent(student);
    if (doc.uploaded.length >= 4) return doc.uploaded.substring(0, 4);
    return 'Unknown batch';
  }

  String _programForDocument(_DocRow doc) {
    if (doc.program.trim().isNotEmpty) return doc.program.trim();
    return _studentsByName[_key(doc.student)]?.course.trim() ??
        'Unassigned program';
  }

  String _studentNoForDocument(_DocRow doc) {
    if (doc.studentNo.trim().isNotEmpty) return doc.studentNo.trim();
    return _studentsByName[_key(doc.student)]?.studentNo.trim() ?? '';
  }

  String _collegeForDocument(_DocRow doc) {
    if (doc.college.trim().isNotEmpty) return doc.college.trim();
    final student = _studentsByName[_key(doc.student)];
    if (student == null) return 'Unassigned college';
    final course = _coursesByName[_key(student.course)];
    final collegeId = course?.collegeId;
    if (collegeId == null) return 'Unassigned college';
    final college = _collegeNameById[collegeId]?.trim();
    return college == null || college.isEmpty ? 'Unassigned college' : college;
  }

  String _documentTypeFor(_DocRow doc) {
    if (doc.documentType.trim().isNotEmpty) return doc.documentType.trim();
    final ext = p.extension(doc.title).replaceFirst('.', '').toUpperCase();
    return ext.isEmpty ? doc.type : ext;
  }

  List<String> _uniqueOptions(Iterable<String> values) {
    final list =
        values.map((v) => v.trim()).where((v) => v.isNotEmpty).toSet().toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<String> get _batchOptions =>
      _uniqueOptions(widget.rows.map(_batchForDocument));
  List<String> get _collegeOptions =>
      _uniqueOptions(widget.rows.map(_collegeForDocument));
  List<String> get _programOptions =>
      _uniqueOptions(widget.rows.map(_programForDocument));
  List<String> get _typeOptions =>
      _uniqueOptions(widget.rows.map(_documentTypeFor));

  List<_DocRow> _filteredRows() {
    final q = _searchController.text.trim().toLowerCase();
    final studentFilter = widget.studentFilter?.trim().toLowerCase();
    final rows = widget.rows.where((doc) {
      final batch = _batchForDocument(doc);
      final college = _collegeForDocument(doc);
      final program = _programForDocument(doc);
      final studentNo = _studentNoForDocument(doc);
      final documentType = _documentTypeFor(doc);
      if (studentFilter != null &&
          studentFilter.isNotEmpty &&
          doc.student.trim().toLowerCase() != studentFilter) {
        return false;
      }
      if (_batchFilter != null && batch != _batchFilter) return false;
      if (_collegeFilter != null && college != _collegeFilter) return false;
      if (_programFilter != null && program != _programFilter) return false;
      if (_typeFilter != null && documentType != _typeFilter) return false;
      return _documentMatchesSearch(
        doc,
        q,
        additionalValues: [
          studentNo,
          documentType,
          batch,
          college,
          program,
        ],
      );
    }).toList();

    final uniqueRows = <_DocRow>[];
    final seenDocuments = <Object>{};
    for (final row in rows) {
      final duplicateKey = (
        row.id,
        row.title,
        row.student,
        row.type,
        row.size,
        row.uploaded,
        row.schoolYear,
        row.studentNo,
        row.program,
        row.college,
        row.documentType,
        row.storagePath,
        row.tags,
        row.uploader,
        row.deletedAt,
        row.deletedBy,
        row.localFilePath,
        row.localImagePath,
        row.remoteImageUrl,
      );
      if (seenDocuments.add(duplicateKey)) {
        uniqueRows.add(row);
      }
    }

    rows
      ..clear()
      ..addAll(uniqueRows);

    rows.sort((a, b) {
      final cmp = _documentDisplayName(a)
          .toLowerCase()
          .compareTo(_documentDisplayName(b).toLowerCase());
      return _sortAz ? cmp : -cmp;
    });
    return rows;
  }

  bool get _hasFilters =>
      _searchController.text.trim().isNotEmpty ||
      (widget.studentFilter?.trim().isNotEmpty ?? false) ||
      _batchFilter != null ||
      _collegeFilter != null ||
      _programFilter != null ||
      _typeFilter != null;

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _batchFilter = null;
      _collegeFilter = null;
      _programFilter = null;
      _typeFilter = null;
      widget.onStudentFilterChanged(null);
    });
  }

  Future<void> _openUploadDialog() async {
    final uploaded = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DocumentUploadDialog(
        students: widget.students,
        courses: widget.courses,
        colleges: widget.colleges,
        onUpload: widget.onUploadDocument,
      ),
    );
    if (!mounted || uploaded == null) return;
    await widget.onRefreshRequested();
    if (!mounted) return;
    _showInfo(
      context,
      '$uploaded file${uploaded == 1 ? '' : 's'} uploaded.',
    );
  }

  Future<void> _openEditDialog(_DocRow doc) async {
    final updated = await showDialog<_DocRow?>(
      context: context,
      builder: (context) => _DocumentMetadataDialog(
        document: doc,
        batch: _batchForDocument(doc),
        college: _collegeForDocument(doc),
        program: _programForDocument(doc),
        studentNo: _studentNoForDocument(doc),
        documentType: _documentTypeFor(doc),
        onSave: widget.onUpdateDocument,
      ),
    );
    if (!mounted) return;
    if (updated == null) return;
    await widget.onRefreshRequested();
    if (mounted) _showInfo(context, 'Document updated.');
  }

  Future<void> _replaceDocument(_DocRow doc) async {
    if (!widget.canDelete) {
      _showInfo(context, 'Only administrators can replace documents.');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );
    final path = result?.files.single.path;
    if (path == null || path.trim().isEmpty) return;
    final ok = await widget.onUploadDocument(
      title: p.basename(path),
      student: doc.student,
      sourceImagePath: path,
      mimeType: _mimeFromPath(path),
      studentNo: _studentNoForDocument(doc),
      course: _programForDocument(doc),
      schoolYear: _batchForDocument(doc),
      documentType: _documentTypeFor(doc),
      college: _collegeForDocument(doc),
      tags: doc.tags,
      storagePath: p.dirname(doc.storagePath),
    );
    if (!ok) {
      if (mounted) _showInfo(context, 'Could not upload replacement file.');
      return;
    }
    await widget.onDeleteDocument(doc);
    await widget.onRefreshRequested();
    if (mounted) _showInfo(context, 'Document replaced.');
  }

  Future<void> _deleteDocument(_DocRow doc) async {
    if (!widget.canDelete) {
      _showInfo(context, 'Only administrators can remove documents.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move document to Trash?'),
        content: Text(
          'Move ${_documentDisplayName(doc)} to Trash? You can restore it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
            ),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await widget.onDeleteDocument(doc);
    if (!mounted) return;
    if (!ok) {
      _showInfo(context, 'Could not remove document.');
      return;
    }
    await widget.onRefreshRequested();
    if (mounted) _showInfo(context, 'Document moved to Trash.');
  }

  void _openPreview(List<_DocRow> docs, _DocRow selected) {
    final associated = _associatedDocuments(docs, selected);
    final index =
        math.max(0, associated.indexWhere((doc) => doc.id == selected.id));
    showDialog<void>(
      context: context,
      builder: (context) => _DocumentPreviewDialog(
        documents: associated,
        initialIndex: index,
        batchForDocument: _batchForDocument,
        collegeForDocument: _collegeForDocument,
        programForDocument: _programForDocument,
        studentNoForDocument: _studentNoForDocument,
        documentTypeFor: _documentTypeFor,
      ),
    );
  }

  List<_DocRow> _associatedDocuments(List<_DocRow> docs, _DocRow selected) {
    final selectedStudent = _key(selected.student);
    final selectedBatch = _batchForDocument(selected);
    final selectedProgram = _programForDocument(selected);
    final associated = docs
        .where(
          (doc) =>
              _key(doc.student) == selectedStudent &&
              _batchForDocument(doc) == selectedBatch &&
              _programForDocument(doc) == selectedProgram,
        )
        .toList();
    if (associated.isEmpty) return [selected];
    associated
        .sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return associated;
  }

  Future<void> _downloadDocument(_DocRow doc) async {
    try {
      final sourcePath = doc.localFilePath?.trim() ?? '';
      final localFile = sourcePath.isEmpty ? null : File(sourcePath);
      final hasLocalFile = localFile != null && await localFile.exists();
      final remoteUrl = doc.remoteImageUrl.trim();
      if (!hasLocalFile && remoteUrl.isEmpty) {
        if (mounted) _showInfo(context, 'Document file is not available.');
        return;
      }

      var suggestedName = hasLocalFile ? p.basename(sourcePath) : '';
      if (suggestedName.isEmpty && remoteUrl.isNotEmpty) {
        suggestedName = p.basename(Uri.parse(remoteUrl).path);
      }
      if (suggestedName.isEmpty) suggestedName = doc.title.trim();
      if (suggestedName.isEmpty) suggestedName = 'document';

      final destinationPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save document',
        fileName: suggestedName,
      );
      if (destinationPath == null || destinationPath.trim().isEmpty) return;
      final destination = File(destinationPath);
      await destination.parent.create(recursive: true);
      if (hasLocalFile) {
        await localFile.copy(destination.path);
      } else {
        final client = HttpClient();
        try {
          final request = await client.getUrl(Uri.parse(remoteUrl));
          final response = await request.close();
          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw HttpException(
              'Server returned ${response.statusCode}',
              uri: Uri.parse(remoteUrl),
            );
          }
          await response.pipe(destination.openWrite());
        } finally {
          client.close(force: true);
        }
      }
      if (mounted) _showInfo(context, 'Downloaded to ${destination.path}');
    } catch (error) {
      if (mounted) _showInfo(context, 'Could not download document: $error');
    }
  }

  _DocRow? _selectedDocument(List<_DocRow> docs) {
    if (docs.isEmpty) return null;
    final selectedId = _selectedDocumentId;
    if (selectedId != null) {
      for (final doc in docs) {
        if (doc.id == selectedId) return doc;
      }
    }
    return docs.first;
  }

  void _selectDocument(_DocRow doc) {
    setState(() => _selectedDocumentId = doc.id);
  }

  Widget _buildFilters() {
    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth < 760
              ? constraints.maxWidth
              : (constraints.maxWidth - 36) / 4;
          return Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _DocumentFilterSelect(
                width: width,
                label: 'Batch',
                value: _batchFilter,
                options: _batchOptions,
                onChanged: (value) {
                  setState(() => _batchFilter = value);
                  _runServerQuery();
                },
              ),
              _DocumentFilterSelect(
                width: width,
                label: 'College',
                value: _collegeFilter,
                options: _collegeOptions,
                onChanged: (value) {
                  setState(() => _collegeFilter = value);
                  _runServerQuery();
                },
              ),
              _DocumentFilterSelect(
                width: width,
                label: 'Program',
                value: _programFilter,
                options: _programOptions,
                onChanged: (value) {
                  setState(() => _programFilter = value);
                  _runServerQuery();
                },
              ),
              _DocumentFilterSelect(
                width: width,
                label: 'Type',
                value: _typeFilter,
                options: _typeOptions,
                onChanged: (value) {
                  setState(() => _typeFilter = value);
                  _runServerQuery();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(List<_DocRow> docs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DocumentTableHeader(count: docs.length),
        Expanded(
          child: ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: _RecordListTheme.border),
            itemBuilder: (context, index) => _DocumentManagementRow(
              index: index + 1,
              selected: _selectedDocumentId == docs[index].id,
              document: docs[index],
              batch: _batchForDocument(docs[index]),
              college: _collegeForDocument(docs[index]),
              program: _programForDocument(docs[index]),
              studentNo: _studentNoForDocument(docs[index]),
              documentType: _documentTypeFor(docs[index]),
              onSelect: () => _selectDocument(docs[index]),
              onPreview: () => _openPreview(docs, docs[index]),
              onDownload: () => _downloadDocument(docs[index]),
              onEdit: () => _openEditDialog(docs[index]),
              onReplace: () => _replaceDocument(docs[index]),
              onDelete:
                  widget.canDelete ? () => _deleteDocument(docs[index]) : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            'Showing ${docs.length} of ${widget.totalCount} documents',
            style: const TextStyle(
              color: _RecordListTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (widget.hasMore)
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: widget.isLoading ? null : widget.onLoadMore,
              icon: const Icon(Icons.expand_more),
              label: const Text('Load more documents'),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRows();
    final showEmpty = !widget.isLoading && filtered.isEmpty;
    final hasStudentFilter = widget.studentFilter?.trim().isNotEmpty ?? false;

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
            // _PageHeader(
            //   breadcrumbs: const ['Records', 'Documents'],
            //   title: 'Documents',
            //   subtitle:
            //       'Manage uploads by batch, college, program, student, type, and tags.',
            //   trailing: TextButton.icon(
            //     onPressed: widget.isLoading ? null : widget.onRefreshRequested,
            //     icon: const Icon(HugeIcons.strokeRoundedRefresh, size: 18),
            //     label: const Text('Refresh'),
            //     style: TextButton.styleFrom(
            //       foregroundColor: _RecordListTheme.textMuted,
            //     ),
            //   ),
            // ),
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
                        onChanged: (_) {
                          setState(() {});
                          _runServerQuery();
                        },
                        hintText: hasStudentFilter
                            ? 'Search this student\'s documents'
                            : 'Search filename, tag, student, path, or metadata',
                        focusColor: _archiveAccent,
                      ),
                      trailing: [
                        _DocumentSegmentedButton(
                          selected: _sortAz,
                          firstLabel: 'A-Z',
                          secondLabel: 'Z-A',
                          onChanged: (value) => setState(() => _sortAz = value),
                        ),
                        const SizedBox(width: 8),
                        // _RecordCountBadge(
                        //   icon: HugeIcons.strokeRoundedFolder03,
                        //   label:
                        //       '${filtered.length} document${filtered.length == 1 ? '' : 's'}',
                        //   accentColor: _archiveAccent,
                        // ),
                        OutlinedButton.icon(
                          onPressed: () => setState(
                            () => _previewCollapsed = !_previewCollapsed,
                          ),
                          icon: Icon(
                            _previewCollapsed
                                ? HugeIcons.strokeRoundedView
                                : HugeIcons.strokeRoundedViewOff,
                            size: 18,
                          ),
                          label: Text(
                            _previewCollapsed ? 'Show preview' : 'Hide preview',
                          ),
                        ),
                      ],
                    ),
                    _buildFilters(),
                    const Divider(height: 1, color: _RecordListTheme.border),
                    if (showEmpty)
                      Expanded(
                        child: _DocumentEmptyState(
                          hasFilters: _hasFilters,
                          onClear: _clearFilters,
                          onUpload: _openUploadDialog,
                        ),
                      )
                    else
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final selected = _selectedDocument(filtered);
                            final stacked = constraints.maxWidth < 1050;
                            final list = _buildList(filtered);
                            final preview = _DocumentSidePreview(
                              documents: _associatedDocuments(
                                filtered,
                                selected!,
                              ),
                              selected: selected,
                              batch: _batchForDocument(selected),
                              college: _collegeForDocument(selected),
                              program: _programForDocument(selected),
                              studentNo: _studentNoForDocument(selected),
                              documentType: _documentTypeFor(selected),
                              onSelected: _selectDocument,
                              onPrevious: () {
                                final index = filtered.indexOf(selected);
                                if (index > 0) {
                                  _selectDocument(filtered[index - 1]);
                                }
                              },
                              onNext: () {
                                final index = filtered.indexOf(selected);
                                if (index < filtered.length - 1) {
                                  _selectDocument(filtered[index + 1]);
                                }
                              },
                              onDownload: () => _downloadDocument(selected),
                              onEdit: () => _openEditDialog(selected),
                              onOpenModal: () =>
                                  _openPreview(filtered, selected),
                              canGoPrevious: filtered.indexOf(selected) > 0,
                              canGoNext: filtered.indexOf(selected) <
                                  filtered.length - 1,
                              onToggleCollapsed: () => setState(
                                () => _previewCollapsed = !_previewCollapsed,
                              ),
                            );
                            if (stacked) {
                              if (_previewCollapsed) {
                                return Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: list,
                                );
                              }
                              return SingleChildScrollView(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: math.max(
                                        300,
                                        constraints.maxHeight * 0.55,
                                      ),
                                      child: list,
                                    ),
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      height: math.max(
                                        420,
                                        constraints.maxHeight * 0.70,
                                      ),
                                      child: preview,
                                    ),
                                  ],
                                ),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Expanded(flex: 7, child: list),
                                  if (!_previewCollapsed) ...[
                                    const SizedBox(width: 14),
                                    SizedBox(width: 430, child: preview),
                                  ],
                                ],
                              ),
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

class _DocumentFilterSelect extends StatelessWidget {
  const _DocumentFilterSelect({
    required this.width,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final double width;
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String?>(
        initialValue: value != null && options.contains(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text('All $label'),
          ),
          ...options.map(
            (item) => DropdownMenuItem<String?>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _DocumentUploadDialog extends StatefulWidget {
  const _DocumentUploadDialog({
    required this.students,
    required this.courses,
    required this.colleges,
    required this.onUpload,
  });

  final List<_StudentRow> students;
  final List<_CourseRow> courses;
  final List<_CollegeRow> colleges;
  final Future<bool> Function({
    required String title,
    required String student,
    required String sourceImagePath,
    required String mimeType,
    String studentNo,
    String course,
    String schoolYear,
    String documentType,
    bool isComplete,
    String college,
    String studentCategory,
    String tags,
    String storagePath,
  }) onUpload;

  @override
  State<_DocumentUploadDialog> createState() => _DocumentUploadDialogState();
}

class _DocumentUploadDialogState extends State<_DocumentUploadDialog> {
  final _scannerService = ScannerService();
  final _tagsController = TextEditingController();
  final _storagePathController = TextEditingController();
  final _customTypeController = TextEditingController();
  final List<XFile> _files = [];
  final List<Directory> _scannerTempDirectories = [];
  String? _studentName;
  String? _documentType;
  bool _dragging = false;
  bool _saving = false;

  static const _types = [
    'Form 137',
    'Transcript',
    'Birth certificate',
    'ID',
    'Medical record',
    'Clearance',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.students.isNotEmpty) {
      _studentName = widget.students.first.fullName;
    }
    _documentType = _types.first;
  }

  @override
  void dispose() {
    _tagsController.dispose();
    _storagePathController.dispose();
    _customTypeController.dispose();
    for (final directory in _scannerTempDirectories) {
      _scannerService.cleanup(directory);
    }
    super.dispose();
  }

  String get _resolvedDocumentType {
    if (_documentType == 'Other') {
      return _customTypeController.text.trim();
    }
    return (_documentType ?? '').trim();
  }

  _StudentRow? get _student {
    final target = _studentName?.trim();
    if (target == null || target.isEmpty) return null;
    for (final student in widget.students) {
      if (student.fullName == target) return student;
    }
    return null;
  }

  String get _college {
    final student = _student;
    if (student == null) return '';
    final course = widget.courses.firstWhere(
      (course) => course.name == student.course,
      orElse: () => const _CourseRow(name: ''),
    );
    final collegeId = course.collegeId;
    if (collegeId == null) return '';
    return widget.colleges
        .firstWhere(
          (college) => college.id == collegeId,
          orElse: () => const _CollegeRow(name: ''),
        )
        .name
        .trim();
  }

  void _addFiles(Iterable<XFile> files) {
    const supported = {'.pdf', '.jpg', '.jpeg', '.png', '.tif', '.tiff'};
    setState(() {
      for (final file in files) {
        if (file.path.trim().isEmpty) continue;
        if (!supported.contains(p.extension(file.path).toLowerCase())) continue;
        if (_files.any((item) => item.path == file.path)) continue;
        _files.add(file);
      }
    });
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'tif', 'tiff'],
    );
    if (result == null) return;
    _addFiles(
      result.files
          .where((file) => file.path != null)
          .map((file) => XFile(file.path!)),
    );
  }

  Future<void> _scanDocuments() async {
    final output = await showDialog<ScannerOutput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ScannerDialog(service: _scannerService),
    );
    if (output == null || !mounted) return;
    _scannerTempDirectories.add(output.sessionDirectory);
    _addFiles(output.files.map((file) => XFile(file.path)));
    final currentTags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet();
    currentTags.addAll(output.metadataTags);
    _tagsController.text = currentTags.join(', ');
    setState(() {});
  }

  Future<void> _cleanupScannerFiles() async {
    final directories = List<Directory>.from(_scannerTempDirectories);
    _scannerTempDirectories.clear();
    for (final directory in directories) {
      await _scannerService.cleanup(directory);
    }
  }

  Future<void> _submit() async {
    if (_files.isEmpty) {
      _showInfo(context, 'Add at least one file.');
      return;
    }
    final student = _student;
    if (student == null) {
      _showInfo(context, 'Select a student.');
      return;
    }
    final documentType = _resolvedDocumentType;
    if (documentType.isEmpty) {
      _showInfo(context, 'Enter the document type name.');
      return;
    }
    setState(() => _saving = true);
    var uploaded = 0;
    var nextFile = 0;
    Future<void> uploadWorker() async {
      while (nextFile < _files.length) {
        final file = _files[nextFile++];
        final ok = await widget.onUpload(
          title: p.basename(file.path),
          student: student.fullName,
          sourceImagePath: file.path,
          mimeType: _mimeFromPath(file.path),
          studentNo: student.studentNo,
          course: student.course,
          schoolYear: _schoolYearForStudent(student),
          documentType: documentType,
          college: _college,
          tags: _tagsController.text,
          storagePath: _storagePathController.text,
        );
        if (ok) uploaded++;
      }
    }

    final workerCount = _files.length < 3 ? _files.length : 3;
    await Future.wait(List.generate(workerCount, (_) => uploadWorker()));
    if (!mounted) return;
    if (uploaded != _files.length) {
      setState(() => _saving = false);
      _showInfo(
        context,
        '$uploaded of ${_files.length} files uploaded. Temporary scanner files '
        'were retained so you can retry the failed items.',
      );
      return;
    }
    await _cleanupScannerFiles();
    if (!mounted) return;
    Navigator.of(context).pop(uploaded);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Upload documents',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _saving || _files.isEmpty
                        ? null
                        : () async {
                            setState(() => _files.clear());
                            await _cleanupScannerFiles();
                          },
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear selection'),
                  ),
                  IconButton(
                    tooltip: 'Close upload',
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(HugeIcons.strokeRoundedCancel01),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropTarget(
                onDragEntered: (_) => setState(() => _dragging = true),
                onDragExited: (_) => setState(() => _dragging = false),
                onDragDone: (detail) {
                  setState(() => _dragging = false);
                  _addFiles(detail.files);
                },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 116),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  decoration: BoxDecoration(
                    color: _dragging
                        ? _archiveAccent.withValues(alpha: 0.10)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          _dragging ? _archiveAccent : _RecordListTheme.border,
                      width: _dragging ? 1.5 : 1,
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final description = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            HugeIcons.strokeRoundedCloudUpload,
                            size: 38,
                          ),
                          const SizedBox(width: 14),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Drag and drop documents here, or choose files',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'PDF, JPG, PNG, or TIFF • single or multiple files',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                      final actions = Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _pickFiles,
                            icon: const Icon(Icons.folder_open_outlined),
                            label: const Text('Choose files'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _saving ? null : _scanDocuments,
                            icon: const Icon(Icons.document_scanner_outlined),
                            label: const Text('Scan document'),
                          ),
                        ],
                      );
                      if (constraints.maxWidth < 620) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            description,
                            const SizedBox(height: 14),
                            actions,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: description),
                          const SizedBox(width: 16),
                          actions,
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 340,
                    child: DropdownButtonFormField<String>(
                      initialValue: _studentName,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Student'),
                      items: widget.students
                          .map(
                            (student) => DropdownMenuItem(
                              value: student.fullName,
                              child: Text(
                                student.fullName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _studentName = value),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _documentType,
                      decoration:
                          const InputDecoration(labelText: 'Document type'),
                      items: _types
                          .map((type) =>
                              DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _documentType = value),
                    ),
                  ),
                  if (_documentType == 'Other')
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _customTypeController,
                        enabled: !_saving,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: 'Type name *',
                          hintText: 'e.g. Certificate of Enrollment',
                        ),
                      ),
                    ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _tagsController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Tags',
                        hintText: 'enrollment, scanned, 2026',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _storagePathController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Storage path',
                        hintText: 'Auto-generated route',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _DocumentUploadFileList(
                  files: _files,
                  onRemove: _saving
                      ? null
                      : (file) => setState(() => _files.remove(file)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                      '${_files.length} file${_files.length == 1 ? '' : 's'} ready'),
                  const Spacer(),
                  OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(HugeIcons.strokeRoundedUpload01),
                    label: const Text('Upload'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentUploadFileList extends StatelessWidget {
  const _DocumentUploadFileList({required this.files, required this.onRemove});

  final List<XFile> files;
  final ValueChanged<XFile>? onRemove;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const Center(child: Text('No files selected.'));
    }
    return ListView.separated(
      itemCount: files.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final file = files[index];
        return ListTile(
          dense: true,
          leading: Icon(_iconForMime(_mimeFromPath(file.path))),
          title: Text(p.basename(file.path), overflow: TextOverflow.ellipsis),
          subtitle: Text(file.path, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            tooltip: 'Remove file',
            onPressed: onRemove == null ? null : () => onRemove!(file),
            icon: const Icon(HugeIcons.strokeRoundedCancel01),
          ),
        );
      },
    );
  }
}

class _DocumentTableHeader extends StatelessWidget {
  const _DocumentTableHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: _RecordListTheme.textMuted,
      fontSize: 11,
      fontWeight: FontWeight.w700,
    );
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: _RecordListTheme.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: const [
          SizedBox(width: 30, child: Text('#', style: style)),
          Expanded(flex: 3, child: Text('Name', style: style)),
          Expanded(flex: 4, child: Text('Document name', style: style)),
          Expanded(flex: 2, child: Text('Type', style: style)),
          Expanded(flex: 2, child: Text('Tags', style: style)),
          Expanded(flex: 2, child: Text('Uploaded', style: style)),
          SizedBox(width: 48, child: Text('Actions', style: style)),
        ],
      ),
    );
  }
}

class _DocumentManagementRow extends StatelessWidget {
  const _DocumentManagementRow({
    required this.index,
    required this.selected,
    required this.document,
    required this.batch,
    required this.college,
    required this.program,
    required this.studentNo,
    required this.documentType,
    required this.onSelect,
    required this.onPreview,
    required this.onDownload,
    required this.onEdit,
    required this.onReplace,
    required this.onDelete,
  });

  final int index;
  final bool selected;
  final _DocRow document;
  final String batch;
  final String college;
  final String program;
  final String studentNo;
  final String documentType;
  final VoidCallback onSelect;
  final VoidCallback onPreview;
  final VoidCallback onDownload;
  final VoidCallback onEdit;
  final VoidCallback onReplace;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEFF6FF) : Colors.white,
      child: InkWell(
        onTap: () {
          onSelect();
          onPreview();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: _RecordListTheme.border),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  '$index',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _RecordListTheme.textPrimary,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: _DocumentStudentCell(
                  name: document.student,
                  studentNo: studentNo,
                ),
              ),
              Expanded(
                flex: 4,
                child: InkWell(
                  onTap: () {
                    onSelect();
                    onPreview();
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: _DocumentTitleCell(document: document),
                ),
              ),
              Expanded(
                flex: 2,
                child: _DocumentTypeBadge(label: documentType),
              ),
              Expanded(
                flex: 2,
                child: _DocumentTags(tags: document.tags),
              ),
              Expanded(
                flex: 2,
                child: Text(document.uploaded, style: _docMutedStyle),
              ),
              SizedBox(
                width: 48,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _DocumentMoreMenu(
                    onDownload: onDownload,
                    onEdit: onEdit,
                    onReplace: onReplace,
                    onDelete: onDelete,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentTitleCell extends StatelessWidget {
  const _DocumentTitleCell({required this.document});

  final _DocRow document;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(_iconForMime(document.type), color: _archiveAccent, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _documentDisplayName(document),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _RecordListTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocumentStudentCell extends StatelessWidget {
  const _DocumentStudentCell({required this.name, required this.studentNo});

  final String name;
  final String studentNo;

  @override
  Widget build(BuildContext context) {
    final displayName = _nameCase(name);
    final displayStudentNo = studentNo.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayName.isEmpty ? 'Unknown Student' : displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _RecordListTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (displayStudentNo.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            displayStudentNo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _docMutedStyle,
          ),
        ],
      ],
    );
  }
}

class _DocumentTypeBadge extends StatelessWidget {
  const _DocumentTypeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _archiveAccent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _archiveAccent,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DocumentTags extends StatelessWidget {
  const _DocumentTags({required this.tags});

  final String tags;

  @override
  Widget build(BuildContext context) {
    final values = tags
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .take(2)
        .toList();
    if (values.isEmpty) {
      return const Text('-', style: _docMutedStyle);
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final tag in values)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              tag,
              style: const TextStyle(
                color: Color(0xFF2563EB),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

enum _DocumentMenuAction { download, edit, replace, remove }

class _DocumentMoreMenu extends StatelessWidget {
  const _DocumentMoreMenu({
    required this.onDownload,
    required this.onEdit,
    required this.onReplace,
    required this.onDelete,
  });

  final VoidCallback onDownload;
  final VoidCallback onEdit;
  final VoidCallback onReplace;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_DocumentMenuAction>(
      tooltip: 'Document actions',
      onSelected: (value) {
        final action = switch (value) {
          _DocumentMenuAction.download => onDownload,
          _DocumentMenuAction.edit => onEdit,
          _DocumentMenuAction.replace => onReplace,
          _DocumentMenuAction.remove => onDelete,
        };
        if (action == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) => action());
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _DocumentMenuAction.download,
          child: Row(
            children: [
              Icon(HugeIcons.strokeRoundedDownload01, size: 19),
              SizedBox(width: 12),
              Text('Download'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: _DocumentMenuAction.edit,
          child: Row(
            children: [
              Icon(HugeIcons.strokeRoundedEdit02, size: 19),
              SizedBox(width: 12),
              Text('Edit details'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: _DocumentMenuAction.replace,
          child: Row(
            children: [
              Icon(HugeIcons.strokeRoundedFileUpload, size: 19),
              SizedBox(width: 12),
              Text('Replace file'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _DocumentMenuAction.remove,
          enabled: onDelete != null,
          child: const Row(
            children: [
              Icon(
                HugeIcons.strokeRoundedDelete02,
                color: Color(0xFFB91C1C),
                size: 19,
              ),
              SizedBox(width: 12),
              Text(
                'Remove',
                style: TextStyle(color: Color(0xFFB91C1C)),
              ),
            ],
          ),
        ),
      ],
      icon: const Icon(HugeIcons.strokeRoundedMoreVertical, size: 18),
      padding: EdgeInsets.zero,
    );
  }
}

class _DocumentSidePreview extends StatelessWidget {
  const _DocumentSidePreview({
    required this.documents,
    required this.selected,
    required this.batch,
    required this.college,
    required this.program,
    required this.studentNo,
    required this.documentType,
    required this.onSelected,
    required this.onPrevious,
    required this.onNext,
    required this.onDownload,
    required this.onEdit,
    required this.onOpenModal,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onToggleCollapsed,
  });

  final List<_DocRow> documents;
  final _DocRow selected;
  final String batch;
  final String college;
  final String program;
  final String studentNo;
  final String documentType;
  final ValueChanged<_DocRow> onSelected;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onDownload;
  final VoidCallback onEdit;
  final VoidCallback onOpenModal;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final current = documents.indexWhere((doc) => doc.id == selected.id);
    final safeIndex = current < 0 ? 0 : current;
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _RecordListTheme.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Document Preview',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _RecordListTheme.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${safeIndex + 1} of ${documents.length}',
                        style: _docMutedStyle,
                      ),
                      IconButton(
                        tooltip: 'Hide details',
                        onPressed: onToggleCollapsed,
                        icon: const Icon(HugeIcons.strokeRoundedViewOff),
                      ),
                      IconButton(
                        tooltip: 'Previous document',
                        onPressed: canGoPrevious ? onPrevious : null,
                        icon: const Icon(HugeIcons.strokeRoundedArrowLeft01),
                      ),
                      IconButton(
                        tooltip: 'Next document',
                        onPressed: canGoNext ? onNext : null,
                        icon: const Icon(HugeIcons.strokeRoundedArrowRight01),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  dense: true,
                  leading: Icon(
                    _iconForMime(selected.type),
                    color: _archiveAccent,
                    size: 34,
                  ),
                  title: Text(
                    selected.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '$documentType - ${selected.size}\nUploaded: ${selected.uploaded}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      TextButton(
                          onPressed: onOpenModal, child: const Text('Preview')),
                      TextButton(
                          onPressed: onEdit, child: const Text('Details')),
                      TextButton(onPressed: onEdit, child: const Text('Tags')),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Download',
                        onPressed: onDownload,
                        icon: const Icon(HugeIcons.strokeRoundedDownload01),
                      ),
                      IconButton(
                        tooltip: _isPdfDocument(selected)
                            ? 'Print PDF'
                            : 'Print image',
                        onPressed: () =>
                            _printDocument(context, document: selected),
                        icon: const Icon(HugeIcons.strokeRoundedPrinter),
                      ),
                      IconButton(
                        tooltip: 'Open preview',
                        onPressed: onOpenModal,
                        icon: const Icon(HugeIcons.strokeRoundedFullScreen),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ColoredBox(
                    color: const Color(0xFFF8FAFC),
                    child: _DocumentPreviewPane(document: selected),
                  ),
                ),
                if (documents.length > 1) ...[
                  const Divider(height: 1),
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      itemCount: documents.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final doc = documents[index];
                        final isSelected = doc.id == selected.id;
                        return InkWell(
                          onTap: () => onSelected(doc),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 130,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _archiveAccent.withValues(alpha: 0.10)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? _archiveAccent
                                    : _RecordListTheme.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(_iconForMime(doc.type), size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _documentDisplayName(doc),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _DocumentSideInfoCard(
          title: 'Storage Path',
          icon: HugeIcons.strokeRoundedPackage,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selected.storagePath.isEmpty
                      ? 'No path assigned'
                      : selected.storagePath,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              IconButton(
                tooltip: 'Edit path',
                onPressed: onEdit,
                icon: const Icon(HugeIcons.strokeRoundedEdit02, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocumentSideInfoCard extends StatelessWidget {
  const _DocumentSideInfoCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _RecordListTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _RecordListTheme.textMuted),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _RecordListTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _DocumentPreviewDialog extends StatefulWidget {
  const _DocumentPreviewDialog({
    required this.documents,
    required this.initialIndex,
    required this.batchForDocument,
    required this.collegeForDocument,
    required this.programForDocument,
    required this.studentNoForDocument,
    required this.documentTypeFor,
  });

  final List<_DocRow> documents;
  final int initialIndex;
  final String Function(_DocRow) batchForDocument;
  final String Function(_DocRow) collegeForDocument;
  final String Function(_DocRow) programForDocument;
  final String Function(_DocRow) studentNoForDocument;
  final String Function(_DocRow) documentTypeFor;

  @override
  State<_DocumentPreviewDialog> createState() => _DocumentPreviewDialogState();
}

class _DocumentPreviewDialogState extends State<_DocumentPreviewDialog> {
  late int _index = widget.initialIndex;
  double _width = 1100;
  double _height = 760;
  bool _printing = false;

  _DocRow get _doc => widget.documents[_index];

  void _go(int delta) {
    if (widget.documents.isEmpty) return;
    setState(() {
      final maxIndex = widget.documents.length - 1;
      _index = (_index + delta).clamp(0, maxIndex);
    });
  }

  Future<void> _printCurrent() async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      await _printDocument(context, document: _doc);
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.documents.isEmpty) {
      return const SizedBox.shrink();
    }

    final screen = MediaQuery.sizeOf(context);
    final maxWidth = math.max(320.0, screen.width - 36);
    final maxHeight = math.max(280.0, screen.height - 36);
    final minWidth = math.min(680.0, maxWidth);
    final minHeight = math.min(460.0, maxHeight);
    final width = _width.clamp(minWidth, maxWidth);
    final height = _height.clamp(minHeight, maxHeight);
    final showList = width >= 760;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(18),
      child: Material(
        color: Colors.white,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              Row(
                children: [
                  if (showList) ...[
                    SizedBox(
                      width: 280,
                      child: ListView.builder(
                        itemCount: widget.documents.length,
                        itemBuilder: (context, index) {
                          final doc = widget.documents[index];
                          return ListTile(
                            selected: index == _index,
                            leading: Icon(_iconForMime(doc.type)),
                            title: Text(
                              _documentDisplayName(doc),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(widget.documentTypeFor(doc)),
                            onTap: () => setState(() => _index = index),
                          );
                        },
                      ),
                    ),
                    const VerticalDivider(width: 1),
                  ],
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _documentDisplayName(_doc),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Previous document',
                                onPressed: _index == 0 ? null : () => _go(-1),
                                icon: const Icon(
                                    HugeIcons.strokeRoundedArrowLeft01),
                              ),
                              Text('${_index + 1}/${widget.documents.length}'),
                              IconButton(
                                tooltip: 'Next document',
                                onPressed: _index == widget.documents.length - 1
                                    ? null
                                    : () => _go(1),
                                icon: const Icon(
                                    HugeIcons.strokeRoundedArrowRight01),
                              ),
                              IconButton(
                                tooltip: _isPdfDocument(_doc)
                                    ? 'Print PDF'
                                    : 'Print image',
                                onPressed: _printing ? null : _printCurrent,
                                icon: _printing
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        HugeIcons.strokeRoundedPrinter,
                                      ),
                              ),
                              IconButton(
                                tooltip: 'Close preview',
                                onPressed: () => Navigator.of(context).pop(),
                                icon:
                                    const Icon(HugeIcons.strokeRoundedCancel01),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(child: _DocumentPreviewPane(document: _doc)),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) {
                    setState(() {
                      _width = (_width + details.delta.dx).clamp(
                        minWidth,
                        maxWidth,
                      );
                      _height = (_height + details.delta.dy).clamp(
                        minHeight,
                        maxHeight,
                      );
                    });
                  },
                  child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Icon(
                        HugeIcons.strokeRoundedDrag01,
                        size: 17,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned(
                right: 28,
                bottom: 8,
                child: IgnorePointer(
                  child: Text(
                    'Drag to resize',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentPreviewPane extends StatelessWidget {
  const _DocumentPreviewPane({required this.document});

  final _DocRow document;

  @override
  Widget build(BuildContext context) {
    final path = _localPreviewPath(document);
    final remoteUrl = document.remoteImageUrl.trim();
    final mime = document.type.toLowerCase();
    if (path.isNotEmpty && mime.startsWith('image/')) {
      return InteractiveViewer(
        child: Center(
          child: Image.file(
            File(path),
            key: ValueKey('${document.id}|$path'),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Text('Could not load local image.'),
          ),
        ),
      );
    }
    if (remoteUrl.isNotEmpty && _isImageDocument(document)) {
      return InteractiveViewer(
        child: Center(
          child: Image.network(
            remoteUrl,
            key: ValueKey('${document.id}|$remoteUrl'),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Text('Could not load image from server.'),
          ),
        ),
      );
    }
    if (path.isNotEmpty && _isPdfDocument(document)) {
      return PdfViewer.file(
        key: ValueKey('${document.id}|$path'),
        path,
        params: const PdfViewerParams(
          margin: 12,
          backgroundColor: Color(0xFFF8FAFC),
          errorBannerBuilder: _buildPdfErrorBanner,
        ),
      );
    }
    if (path.isNotEmpty && _isTextFile(path, mime)) {
      return FutureBuilder<String>(
        future: File(path).readAsString(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(snapshot.data!),
          );
        },
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconForMime(document.type), size: 70, color: _archiveAccent),
            const SizedBox(height: 14),
            Text(
              _previewMessage(document),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              path.isEmpty && remoteUrl.isEmpty
                  ? 'No preview file path is available.'
                  : (path.isNotEmpty ? path : remoteUrl),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _RecordListTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentMetadataDialog extends StatefulWidget {
  const _DocumentMetadataDialog({
    required this.document,
    required this.batch,
    required this.college,
    required this.program,
    required this.studentNo,
    required this.documentType,
    required this.onSave,
  });

  final _DocRow document;
  final String batch;
  final String college;
  final String program;
  final String studentNo;
  final String documentType;
  final Future<_DocRow?> Function({
    required _DocRow document,
    required String title,
    required String documentType,
    required String schoolYear,
    required String program,
    required String studentNo,
    required String storagePath,
    required String college,
    required String tags,
  }) onSave;

  @override
  State<_DocumentMetadataDialog> createState() =>
      _DocumentMetadataDialogState();
}

class _DocumentMetadataDialogState extends State<_DocumentMetadataDialog> {
  late final _title = TextEditingController(text: widget.document.title);
  late final _type = TextEditingController(text: widget.documentType);
  late final _batch = TextEditingController(text: widget.batch);
  late final _program = TextEditingController(text: widget.program);
  late final _studentNo = TextEditingController(text: widget.studentNo);
  late final _college = TextEditingController(text: widget.college);
  late final _path = TextEditingController(text: widget.document.storagePath);
  late final _tags = TextEditingController(text: widget.document.tags);
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _type.dispose();
    _batch.dispose();
    _program.dispose();
    _studentNo.dispose();
    _college.dispose();
    _path.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = await widget.onSave(
      document: widget.document,
      title: _title.text,
      documentType: _type.text,
      schoolYear: _batch.text,
      program: _program.text,
      studentNo: _studentNo.text,
      storagePath: _path.text,
      college: _college.text,
      tags: _tags.text,
    );
    if (!mounted) return;
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit document'),
      content: SizedBox(
        width: 560,
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metaField(_title, 'Filename/title', 548),
            _metaField(_type, 'Document type', 260),
            _metaField(_batch, 'Batch', 260),
            _metaField(_program, 'Program', 260),
            _metaField(_studentNo, 'Student no.', 260),
            _metaField(_college, 'College', 548),
            _metaField(_path, 'Storage path', 548),
            _metaField(_tags, 'Tags', 548),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _metaField(
      TextEditingController controller, String label, double width) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        enabled: !_saving,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _DocumentInfoWrap extends StatelessWidget {
  const _DocumentInfoWrap({
    required this.document,
    required this.batch,
    required this.college,
    required this.program,
    required this.studentNo,
    required this.documentType,
  });

  final _DocRow document;
  final String batch;
  final String college;
  final String program;
  final String studentNo;
  final String documentType;

  @override
  Widget build(BuildContext context) {
    final items = {
      'Size': document.size,
      'Type': documentType,
      'Uploaded': document.uploaded,
      'Uploader': document.uploader.isEmpty ? 'System' : document.uploader,
      'Student': document.student,
      'Student No.': studentNo,
      'Batch': batch,
      'College': college,
      'Program': program,
      'Tags': document.tags.isEmpty ? '-' : document.tags,
      'Path': document.storagePath.isEmpty ? '-' : document.storagePath,
    };
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final entry in items.entries)
          Chip(
            label: Text('${entry.key}: ${entry.value}'),
            backgroundColor: const Color(0xFFF8FAFC),
          ),
      ],
    );
  }
}

class _DocumentSegmentedButton extends StatelessWidget {
  const _DocumentSegmentedButton({
    required this.selected,
    required this.firstLabel,
    required this.secondLabel,
    required this.onChanged,
  });

  final bool selected;
  final String firstLabel;
  final String secondLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      segments: [
        ButtonSegment(value: true, label: Text(firstLabel)),
        ButtonSegment(value: false, label: Text(secondLabel)),
      ],
      selected: {selected},
      onSelectionChanged: (values) => onChanged(values.first),
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _DocumentEmptyState extends StatelessWidget {
  const _DocumentEmptyState({
    required this.hasFilters,
    required this.onClear,
    required this.onUpload,
  });

  final bool hasFilters;
  final VoidCallback onClear;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(HugeIcons.strokeRoundedFolder03, size: 46),
            const SizedBox(height: 12),
            Text(
              hasFilters ? 'No matching documents' : 'No documents yet',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Clear filters or search with another filename, tag, or metadata.'
                  : 'Upload files to start organizing the archive.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              children: [
                if (hasFilters)
                  OutlinedButton(
                    onPressed: onClear,
                    child: const Text('Clear filters'),
                  ),
                FilledButton.icon(
                  onPressed: onUpload,
                  icon: const Icon(HugeIcons.strokeRoundedUpload01),
                  label: const Text('Upload documents'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _mimeFromPath(String path) {
  final ext = p.extension(path).toLowerCase();
  return switch (ext) {
    '.png' => 'image/png',
    '.jpg' || '.jpeg' => 'image/jpeg',
    '.tif' || '.tiff' => 'image/tiff',
    '.gif' => 'image/gif',
    '.webp' => 'image/webp',
    '.pdf' => 'application/pdf',
    '.doc' => 'application/msword',
    '.docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    '.xls' => 'application/vnd.ms-excel',
    '.xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    '.ppt' => 'application/vnd.ms-powerpoint',
    '.pptx' =>
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    '.txt' => 'text/plain',
    '.csv' => 'text/csv',
    '.json' => 'application/json',
    '.mp4' => 'video/mp4',
    '.mov' => 'video/quicktime',
    '.mp3' => 'audio/mpeg',
    '.wav' => 'audio/wav',
    _ => 'application/octet-stream',
  };
}

IconData _iconForMime(String mime) {
  final value = mime.toLowerCase();
  if (value.startsWith('image/')) return HugeIcons.strokeRoundedImage01;
  if (value.startsWith('video/')) return HugeIcons.strokeRoundedFileVideo;
  if (value.startsWith('audio/')) return HugeIcons.strokeRoundedFileAudio;
  if (value.contains('pdf')) return HugeIcons.strokeRoundedPdf01;
  if (value.contains('word')) return HugeIcons.strokeRoundedFile02;
  if (value.contains('excel') || value.contains('spreadsheet')) {
    return HugeIcons.strokeRoundedTable;
  }
  if (value.contains('powerpoint') || value.contains('presentation')) {
    return HugeIcons.strokeRoundedPresentation01;
  }
  if (value.startsWith('text/') || value.contains('json')) {
    return HugeIcons.strokeRoundedText;
  }
  return HugeIcons.strokeRoundedFile01;
}

bool _isTextFile(String path, String mime) {
  final ext = p.extension(path).toLowerCase();
  return mime.startsWith('text/') ||
      mime.contains('json') ||
      const {'.txt', '.csv', '.json', '.xml', '.md', '.log'}.contains(ext);
}

String _previewMessage(_DocRow doc) {
  final mime = doc.type.toLowerCase();
  if (mime.contains('pdf')) return 'Local PDF file is not available';
  if (mime.contains('word')) return 'Word document preview placeholder';
  if (mime.contains('excel') || mime.contains('spreadsheet')) {
    return 'Spreadsheet preview placeholder';
  }
  if (mime.contains('powerpoint') || mime.contains('presentation')) {
    return 'Presentation preview placeholder';
  }
  if (mime.startsWith('video/')) return 'Video file preview placeholder';
  if (mime.startsWith('audio/')) return 'Audio file preview placeholder';
  return 'Preview is not available for this file type';
}
