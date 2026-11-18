part of '../../dashboard_shell_page.dart';

enum _StudentListSortColumn { studentNo, name, program, batch }

class _StudentRecordsPage extends StatefulWidget {
  const _StudentRecordsPage({
    required this.rows,
    required this.documents,
    required this.courses,
    required this.colleges,
    this.programCodeForCourse,
    required this.onRegisterStudent,
    required this.onUpdateStudent,
    required this.onUploadDocument,
    required this.onUpdateDocument,
    required this.onDeleteDocument,
    required this.onViewStudentDocuments,
    required this.onViewAllDocuments,
    required this.onDeleteStudent,
    required this.canEdit,
    required this.isAdmin,
    this.drillCollegeName,
    this.drillCourseName,
    this.drillFromProgramsList = false,
    this.onDrillBack,
    this.drillDownView = false,
  });

  final List<_StudentRow> rows;
  final List<_DocRow> documents;
  final List<_CourseRow> courses;
  final List<_CollegeRow> colleges;
  final String? Function(String courseName)? programCodeForCourse;
  final Future<_StudentRow?> Function({
    required String studentNo,
    required String fullName,
    required String course,
    required int year,
    required String status,
    String? email,
    String schoolYear,
    String sex,
    String birthDate,
    String phoneNumber,
    String notes,
    String graduationDate,
    String lastEnrollmentDate,
  }) onRegisterStudent;
  final Future<_StudentRow?> Function({
    required _StudentRow student,
    required String studentNo,
    required String fullName,
    required String course,
    required int year,
    required String status,
    String? email,
    String schoolYear,
    String sex,
    String birthDate,
    String phoneNumber,
    String notes,
    String graduationDate,
    String lastEnrollmentDate,
  }) onUpdateStudent;
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
  final void Function(String student) onViewStudentDocuments;
  final VoidCallback onViewAllDocuments;
  final Future<String?> Function(_StudentRow student) onDeleteStudent;
  final bool canEdit;
  final bool isAdmin;
  final String? drillCollegeName;
  final String? drillCourseName;
  final bool drillFromProgramsList;
  final VoidCallback? onDrillBack;
  final bool drillDownView;

  @override
  State<_StudentRecordsPage> createState() => _StudentRecordsPageState();
}

class _StudentRecordsPageState extends State<_StudentRecordsPage> {
  static const _documentTypes = [
    'Form 137',
    'Other',
    'Transcript',
    'Birth certificate',
    'ID',
    'Medical record',
    'Clearance',
  ];

  bool _showForm = false;
  _StudentRow? _editingStudent;
  _StudentFormTab _formTab = _StudentFormTab.student;
  String? _filterDepartment;
  String? _filterProgram;
  String? _filterBatch;
  int? _selectedFormCollegeId;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  static const _studentsPageSize = 25;
  int _listPage = 0;
  _StudentListSortColumn _sortColumn = _StudentListSortColumn.studentNo;
  bool _sortAscending = true;

  String get _sortSelection {
    final column = switch (_sortColumn) {
      _StudentListSortColumn.studentNo => 'studentNo',
      _StudentListSortColumn.name => 'name',
      _StudentListSortColumn.program => 'program',
      _StudentListSortColumn.batch => 'batch',
    };
    return '$column:${_sortAscending ? 'asc' : 'desc'}';
  }

  @override
  void initState() {
    super.initState();
    _applyDrillFiltersFromWidget();
  }

  void _applyDrillFiltersFromWidget() {
    final program = widget.drillCourseName?.trim();
    if (program != null && program.isNotEmpty) {
      _filterProgram = program;
      _filterDepartment = _collegeNameForProgram(program) ??
          _databaseCollegeName(widget.drillCollegeName);
      return;
    }
    final dept = _databaseCollegeName(widget.drillCollegeName);
    if (dept != null) _filterDepartment = dept;
  }

  List<_CollegeRow> get _databaseColleges {
    return widget.colleges.where((college) => college.id != null).toList();
  }

  List<String> get _databaseDepartmentOptions {
    return _databaseColleges.map((college) => college.name).toList();
  }

  String? _databaseCollegeName(String? collegeName) {
    final target = collegeName?.trim().toLowerCase() ?? '';
    if (target.isEmpty) return null;
    for (final college in _databaseColleges) {
      if (college.name.trim().toLowerCase() == target) return college.name;
    }
    return null;
  }

  _CourseRow? _databaseCourse(String courseName) {
    final target = courseName.trim().toLowerCase();
    if (target.isEmpty) return null;
    for (final course in widget.courses) {
      if (course.name.trim().toLowerCase() == target) return course;
    }
    return null;
  }

  _CollegeRow? _collegeForProgram(String courseName) {
    final collegeId = _databaseCourse(courseName)?.collegeId;
    if (collegeId == null) return null;
    for (final college in _databaseColleges) {
      if (college.id == collegeId) return college;
    }
    return null;
  }

  String? _collegeNameForProgram(String courseName) {
    return _collegeForProgram(courseName)?.name;
  }

  List<String> _databaseProgramsForCollege(int? collegeId) {
    if (collegeId == null) return const [];
    final programs = widget.courses
        .where((course) => course.collegeId == collegeId)
        .map((course) => course.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    programs.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return programs;
  }

  int? _collegeIdForName(String? collegeName) {
    final resolved = _databaseCollegeName(collegeName);
    if (resolved == null) return null;
    for (final college in _databaseColleges) {
      if (college.name == resolved) return college.id;
    }
    return null;
  }

  int? _defaultFormCollegeId() {
    final drillCourse = widget.drillCourseName?.trim() ?? '';
    final fromCourse = _databaseCourse(drillCourse)?.collegeId;
    if (fromCourse != null) return fromCourse;
    final fromCollege = _collegeIdForName(widget.drillCollegeName);
    if (fromCollege != null) return fromCollege;
    for (final college in _databaseColleges) {
      if (_databaseProgramsForCollege(college.id).isNotEmpty) return college.id;
    }
    return _databaseColleges.isEmpty ? null : _databaseColleges.first.id;
  }

  final _studentNoController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _suffixController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _courseController = TextEditingController();
  final _schoolYearController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _enrolledAtController = TextEditingController();
  final _graduatedAtController = TextEditingController();

  DateTime? _birthDate;
  DateTime? _enrolledAt;
  DateTime? _graduatedAt;
  String _sex = '';
  bool _studentIdNotAvailable = false;
  final List<_StudentDocumentDraft> _documents = [];
  final ScannerService _studentScannerService = ScannerService();
  final List<Directory> _studentScannerTempDirectories = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _studentNoController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _suffixController.dispose();
    _birthDateController.dispose();
    _courseController.dispose();
    _schoolYearController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    _enrolledAtController.dispose();
    _graduatedAtController.dispose();
    for (final directory in _studentScannerTempDirectories) {
      _studentScannerService.cleanup(directory);
    }
    super.dispose();
  }

  bool get _hasActiveFilters {
    return _searchController.text.trim().isNotEmpty ||
        (_filterDepartment != null && _filterDepartment!.isNotEmpty) ||
        (_filterProgram != null && _filterProgram!.isNotEmpty) ||
        (_filterBatch != null && _filterBatch!.isNotEmpty);
  }

  List<String> get _filterProgramOptions {
    final collegeId = _collegeIdForName(_filterDepartment);
    final list = (collegeId == null
            ? widget.courses.map((course) => course.name.trim())
            : widget.courses
                .where((course) => course.collegeId == collegeId)
                .map((course) => course.name.trim()))
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<String> get _filterBatchOptions {
    final batches = widget.rows
        .map(_schoolYearForStudent)
        .where((batch) => batch.isNotEmpty)
        .toSet()
        .toList();
    batches.sort((a, b) => b.compareTo(a));
    return batches;
  }

  bool _studentMatchesDepartment(String course, String? department) {
    if (department == null || department.isEmpty) return true;
    return _collegeNameForProgram(course) == department;
  }

  bool _studentMatchesFilters(_StudentRow row) {
    final course = row.course.trim();
    if (_filterProgram != null &&
        _filterProgram!.isNotEmpty &&
        course != _filterProgram) {
      return false;
    }
    if (_filterDepartment != null &&
        _filterDepartment!.isNotEmpty &&
        !_studentMatchesDepartment(course, _filterDepartment)) {
      return false;
    }
    final batch = _schoolYearForStudent(row);
    if (_filterBatch != null &&
        _filterBatch!.isNotEmpty &&
        batch != _filterBatch) {
      return false;
    }
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return row.fullName.toLowerCase().contains(q) ||
        row.studentNo.toLowerCase().contains(q) ||
        (row.email ?? '').toLowerCase().contains(q);
  }

  List<_StudentRow> get _filtered {
    return widget.rows.where(_studentMatchesFilters).toList();
  }

  List<_StudentRow> get _filteredSorted {
    final list = List<_StudentRow>.from(_filtered);
    list.sort((a, b) {
      final cmp = switch (_sortColumn) {
        _StudentListSortColumn.studentNo =>
          _compareStudentNumbers(a.studentNo, b.studentNo),
        _StudentListSortColumn.name =>
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
        _StudentListSortColumn.program =>
          a.course.toLowerCase().compareTo(b.course.toLowerCase()),
        _StudentListSortColumn.batch =>
          _schoolYearForStudent(a).compareTo(_schoolYearForStudent(b)),
      };
      return _sortAscending ? cmp : -cmp;
    });
    return list;
  }

  int _totalListPages(int itemCount) {
    if (itemCount == 0) return 0;
    return (itemCount + _studentsPageSize - 1) ~/ _studentsPageSize;
  }

  int _safeListPage(int itemCount) {
    final pages = _totalListPages(itemCount);
    if (pages == 0) return 0;
    return _listPage.clamp(0, pages - 1);
  }

  List<_StudentRow> _pageSlice(List<_StudentRow> sorted, int page) {
    if (sorted.isEmpty) return const [];
    final start = page * _studentsPageSize;
    final end = math.min(start + _studentsPageSize, sorted.length);
    return sorted.sublist(start, end);
  }

  static int _compareStudentNumbers(String a, String b) {
    final na = a.trim().toUpperCase();
    final nb = b.trim().toUpperCase();
    final partsA = na.split('-');
    final partsB = nb.split('-');
    final maxLen = math.max(partsA.length, partsB.length);
    for (var i = 0; i < maxLen; i++) {
      final pa = i < partsA.length ? partsA[i] : '';
      final pb = i < partsB.length ? partsB[i] : '';
      final ia = int.tryParse(pa);
      final ib = int.tryParse(pb);
      final cmp =
          ia != null && ib != null ? ia.compareTo(ib) : pa.compareTo(pb);
      if (cmp != 0) return cmp;
    }
    return na.compareTo(nb);
  }

  void _onSortColumn(_StudentListSortColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
      _listPage = 0;
    });
  }

  void _onSortSelectionChanged(String? value) {
    if (value == null || value.isEmpty) return;
    final parts = value.split(':');
    if (parts.length != 2) return;
    setState(() {
      _sortColumn = switch (parts.first) {
        'name' => _StudentListSortColumn.name,
        'program' => _StudentListSortColumn.program,
        'batch' => _StudentListSortColumn.batch,
        _ => _StudentListSortColumn.studentNo,
      };
      _sortAscending = parts.last != 'desc';
      _listPage = 0;
    });
  }

  void _goToListPage(int page) {
    final pages = _totalListPages(_filteredSorted.length);
    if (page < 0 || page >= pages || page == _listPage) return;
    setState(() => _listPage = page);
  }

  void _resetListFilters() {
    setState(() {
      _searchController.clear();
      _listPage = 0;
      _filterBatch = null;
      if (widget.drillDownView) {
        _applyDrillFiltersFromWidget();
      } else {
        _filterDepartment = null;
        _filterProgram = null;
      }
    });
  }

  void _onDepartmentFilterChanged(String? department) {
    setState(() {
      _listPage = 0;
      _filterDepartment = department;
      if (_filterProgram != null &&
          !_filterProgramOptions.contains(_filterProgram)) {
        _filterProgram = null;
      }
    });
  }

  void _onProgramFilterChanged(String? program) {
    setState(() {
      _listPage = 0;
      _filterProgram = program;
      if (program != null && program.isNotEmpty) {
        _filterDepartment ??= _collegeNameForProgram(program);
      }
    });
  }

  void _onBatchFilterChanged(String? batch) {
    setState(() {
      _listPage = 0;
      _filterBatch = batch;
    });
  }

  List<_DocRow> _documentsForStudent(_StudentRow student) {
    final name = student.fullName.trim().toLowerCase();
    final studentNo = student.studentNo.trim().toLowerCase();
    if (name.isEmpty && studentNo.isEmpty) return const [];
    return widget.documents.where((document) {
      final documentName = document.student.trim().toLowerCase();
      final documentStudentNo = document.studentNo.trim().toLowerCase();
      return (studentNo.isNotEmpty && documentStudentNo == studentNo) ||
          (documentStudentNo.isEmpty &&
              name.isNotEmpty &&
              documentName == name);
    }).toList();
  }

  String _studentArchiveBaseName(_StudentRow student) {
    final programCode = StudentNumber.resolveProgramCode(
      programName: student.course,
      courseCode: widget.programCodeForCourse?.call(student.course),
    );
    return StudentExport.archiveBaseName(
      fullName: student.fullName,
      programCode: programCode,
      schoolYear: _schoolYearForStudent(student),
    );
  }

  Future<void> _downloadStudentPdfArchive(_StudentRow student) async {
    final pdfDocuments =
        _documentsForStudent(student).where(_isPdfDocument).toList();
    if (pdfDocuments.isEmpty) {
      _showInfo(context, 'This student does not have any PDF files to export.');
      return;
    }

    final archiveBaseName = _studentArchiveBaseName(student);
    final selectedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Download all student PDFs',
      fileName: '$archiveBaseName.zip',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (selectedPath == null || selectedPath.trim().isEmpty || !mounted) return;

    final archivePath = p.extension(selectedPath).toLowerCase() == '.zip'
        ? selectedPath
        : '$selectedPath.zip';
    final archiveFile = File(archivePath);
    final tempDirectory =
        await Directory.systemTemp.createTemp('e_archive_student_export_');
    final encoder = ZipFileEncoder();
    var encoderOpen = false;
    var included = 0;
    var unavailable = 0;

    try {
      await archiveFile.parent.create(recursive: true);
      encoder.create(archiveFile.path);
      encoderOpen = true;

      for (final document in pdfDocuments) {
        File? sourceFile;
        final localPath = document.localFilePath?.trim() ?? '';
        if (localPath.isNotEmpty) {
          final localFile = File(localPath);
          if (await localFile.exists()) sourceFile = localFile;
        }

        if (sourceFile == null && document.remoteImageUrl.trim().isNotEmpty) {
          try {
            final bytes = await _readDocumentBytes(
              localPath: '',
              remoteUrl: document.remoteImageUrl.trim(),
            );
            sourceFile = File(
              p.join(
                  tempDirectory.path, 'remote_${included + unavailable}.pdf'),
            );
            await sourceFile.writeAsBytes(bytes, flush: true);
          } catch (_) {
            unavailable += 1;
            continue;
          }
        }

        if (sourceFile == null) {
          unavailable += 1;
          continue;
        }

        final label = document.documentType.trim().isNotEmpty
            ? document.documentType
            : document.title;
        final entryName = StudentExport.pdfEntryName(
          label: label,
          index: included,
        );
        await encoder.addFile(sourceFile, entryName);
        included += 1;
      }

      await encoder.close();
      encoderOpen = false;

      if (included == 0) {
        if (await archiveFile.exists()) await archiveFile.delete();
        if (mounted) {
          _showInfo(
            context,
            'The PDF records were listed, but their files are not available.',
          );
        }
        return;
      }

      if (!mounted) return;
      final skippedMessage =
          unavailable == 0 ? '' : '\n$unavailable unavailable PDF(s) skipped.';
      _showInfo(
        context,
        'Downloaded $included PDF file(s) to:\n'
        '${archiveFile.path}$skippedMessage',
      );
    } catch (error) {
      if (encoderOpen) {
        try {
          await encoder.close();
        } catch (_) {}
      }
      try {
        if (await archiveFile.exists()) await archiveFile.delete();
      } catch (_) {}
      if (mounted) {
        _showInfo(context, 'Could not create the student PDF ZIP: $error');
      }
    } finally {
      try {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  int get _existingArchivedDocumentCount {
    final student = _editingStudent;
    if (student == null) return 0;
    return _documentsForStudent(student).length;
  }

  List<_DocRow> get _existingDocumentsForEditing {
    final student = _editingStudent;
    if (student == null) return const [];
    return _documentsForStudent(student);
  }

  Future<void> _confirmDeleteStudent(_StudentRow student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Move student to trash?'),
        content: Text(
          'Move ${student.fullName} (${student.studentNo}) to trash? '
          'Related documents must be moved or reassigned first.',
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
            child: const Text('Move to trash'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final error = await widget.onDeleteStudent(student);
    if (!mounted) return;

    if (error != null) {
      _showInfo(context, error);
      return;
    }

    _showInfo(context, 'Student moved to trash.');
  }

  void _showStudentDetail(_StudentRow student) {
    final docs = _documentsForStudent(student);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
            child: Theme(
              data: _studentDetailDialogTheme,
              child: Material(
                color: Colors.white,
                elevation: 8,
                shadowColor: const Color(0x1A000000),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                clipBehavior: Clip.antiAlias,
                child: _StudentDetailPanel(
                  student: student,
                  documents: docs,
                  onDownloadPdfs: () => _downloadStudentPdfArchive(student),
                  onEdit: widget.canEdit
                      ? () {
                          Navigator.of(dialogContext).pop();
                          _openEditForm(student);
                        }
                      : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openAddForm() {
    _editingStudent = null;
    _resetForm();
    setState(() => _showForm = true);
  }

  void _openEditForm(_StudentRow student) {
    _editingStudent = student;
    _resetForm();
    _loadStudentIntoForm(student);
    setState(() => _showForm = true);
  }

  void _backToList() {
    setState(() {
      _showForm = false;
      _editingStudent = null;
      _formTab = _StudentFormTab.student;
    });
  }

  void _refreshOpenStudentRecord({
    _StudentRow? student,
    required _StudentFormTab selectedTab,
  }) {
    setState(() {
      _showForm = true;
      if (student != null) _editingStudent = student;
      _formTab = selectedTab;
    });
  }

  void _resetForm() {
    unawaited(_cleanupStudentScannerFiles());
    _formTab = _StudentFormTab.student;
    _sex = '';
    _studentIdNotAvailable = false;
    _birthDate = null;
    _enrolledAt = null;
    _graduatedAt = null;
    _documents.clear();
    for (final c in [
      _studentNoController,
      _firstNameController,
      _middleNameController,
      _lastNameController,
      _suffixController,
      _birthDateController,
      _courseController,
      _emailController,
      _phoneController,
      _notesController,
      _enrolledAtController,
      _graduatedAtController,
    ]) {
      c.clear();
    }
    final drillCourse = widget.drillCourseName?.trim() ?? '';
    _selectedFormCollegeId = _defaultFormCollegeId();
    final selectable = _databaseProgramsForCollege(_selectedFormCollegeId);
    _courseController.text = drillCourse.isNotEmpty &&
            _databaseCourse(drillCourse)?.collegeId == _selectedFormCollegeId
        ? _databaseCourse(drillCourse)!.name
        : (selectable.isNotEmpty ? selectable.first : '');
    _schoolYearController.text = _defaultSchoolYear();
  }

  void _loadStudentIntoForm(_StudentRow student) {
    _studentIdNotAvailable = student.studentNo.trim().isEmpty ||
        StudentNumber.isNotAvailable(student.studentNo);
    _studentNoController.text =
        _studentIdNotAvailable ? StudentNumber.notAvailable : student.studentNo;
    _courseController.text = student.course;
    final course = _databaseCourse(student.course);
    _selectedFormCollegeId = course?.collegeId ?? _defaultFormCollegeId();
    if (course == null) {
      final programs = _databaseProgramsForCollege(_selectedFormCollegeId);
      _courseController.text = programs.isEmpty ? '' : programs.first;
    }
    _emailController.text = student.email ?? '';
    _phoneController.text = student.phoneNumber;
    _notesController.text = student.notes;
    _sex = student.sex.trim();
    _birthDateController.text = student.birthDate;
    _birthDate = _parseStudentDate(student.birthDate);
    _schoolYearController.text = _schoolYearForStudent(student);
    _enrolledAtController.text = student.lastEnrollmentDate;
    _graduatedAtController.text = student.graduationDate;
    _enrolledAt = _parseStudentDate(student.lastEnrollmentDate);
    _graduatedAt = _parseStudentDate(student.graduationDate);

    final parts = student.fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      _firstNameController.text = parts.first;
    } else if (parts.isNotEmpty) {
      _lastNameController.text = parts.last;
      _firstNameController.text = parts.first;
      if (parts.length > 2) {
        _middleNameController.text =
            parts.sublist(1, parts.length - 1).join(' ');
      }
    }
  }

  String _composedFullName() {
    final parts = <String>[
      _firstNameController.text.trim(),
      _middleNameController.text.trim(),
      _lastNameController.text.trim(),
    ].where((p) => p.isNotEmpty);
    final base = parts.join(' ');
    final suffix = _suffixController.text.trim();
    if (suffix.isEmpty) return base;
    return '$base $suffix'.trim();
  }

  String get _studentNoValue =>
      StudentNumber.storageValue(_studentNoController.text);

  void _setStudentIdNotAvailable(bool selected) {
    setState(() {
      _studentIdNotAvailable = selected;
      if (selected) {
        _studentNoController.text = StudentNumber.notAvailable;
      } else if (StudentNumber.isNotAvailable(_studentNoController.text)) {
        _studentNoController.clear();
      }
    });
  }

  String _formatStudentDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  DateTime? _parseStudentDate(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    try {
      final parsed = DateTime(y, m, d);
      if (parsed.year != y || parsed.month != m || parsed.day != d) {
        return null;
      }
      return parsed;
    } catch (_) {
      return null;
    }
  }

  String _normalizedStudentDate(TextEditingController controller) {
    final date = _parseStudentDate(controller.text);
    if (date == null) return '';
    return _formatStudentDate(date);
  }

  DateTime _dateWithinRange(
    DateTime value, {
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    final date = DateTime(value.year, value.month, value.day);
    final first = DateTime(firstDate.year, firstDate.month, firstDate.day);
    final last = DateTime(lastDate.year, lastDate.month, lastDate.day);
    if (date.isBefore(first)) return first;
    if (date.isAfter(last)) return last;
    return date;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(1950);
    final lastDate = now;
    final picked = await MinimalDatePicker.show(
      context: context,
      helpText: 'Birth date',
      initialDate: _dateWithinRange(
        _birthDate ??
            _parseStudentDate(_birthDateController.text) ??
            DateTime(now.year - 18),
        firstDate: firstDate,
        lastDate: lastDate,
      ),
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null) return;
    setState(() {
      _birthDate = picked;
      _birthDateController.text = _formatStudentDate(picked);
    });
  }

  Future<void> _pickEnrolledAt() async {
    final now = DateTime.now();
    final picked = await MinimalDatePicker.show(
      context: context,
      helpText: 'Enrollment date',
      initialDate:
          _enrolledAt ?? _parseStudentDate(_enrolledAtController.text) ?? now,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() {
      _enrolledAt = picked;
      _enrolledAtController.text = _formatStudentDate(picked);
    });
  }

  Future<void> _pickGraduatedAt() async {
    final now = DateTime.now();
    final enrolled =
        _enrolledAt ?? _parseStudentDate(_enrolledAtController.text);
    final picked = await MinimalDatePicker.show(
      context: context,
      helpText: 'Graduation date',
      initialDate: _graduatedAt ??
          _parseStudentDate(_graduatedAtController.text) ??
          enrolled ??
          now,
      firstDate: enrolled ?? DateTime(1950),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() {
      _graduatedAt = picked;
      _graduatedAtController.text = _formatStudentDate(picked);
    });
  }

  Future<void> _pickDocumentDate(int index) async {
    final draft = _documents[index];
    final now = DateTime.now();
    final picked = await MinimalDatePicker.show(
      context: context,
      helpText: 'Document date',
      initialDate: draft.receivedAt ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() => draft.receivedAt = picked);
  }

  void _addDocument() {
    setState(() {
      _documents.add(_StudentDocumentDraft(receivedAt: DateTime.now()));
    });
  }

  void _removeDocument(int index) {
    setState(() => _documents.removeAt(index));
  }

  Future<void> _pickDocumentFile(int index) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'png',
        'jpg',
        'jpeg',
        'gif',
        'webp',
      ],
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    final path = picked.path;
    if (path == null || path.isEmpty) return;

    setState(() {
      final draft = _documents[index];
      draft.filePath = path;
      draft.fileName = picked.name;
      if (draft.title.trim().isEmpty) {
        draft.title = p.basenameWithoutExtension(picked.name);
      }
    });
  }

  Future<void> _chooseDocumentFileSource(int index) async {
    final source = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Add document file'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop('file'),
            child: const ListTile(
              leading: Icon(HugeIcons.strokeRoundedFileUpload),
              title: Text('Choose file'),
              subtitle: Text('Select a document from this computer'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop('scan'),
            child: const ListTile(
              leading: Icon(Icons.document_scanner_outlined),
              title: Text('Scan document'),
              subtitle: Text('Scan using a connected USB scanner'),
            ),
          ),
        ],
      ),
    );
    if (!mounted || source == null) return;
    if (source == 'scan') {
      await _scanStudentDocuments(replaceIndex: index);
    } else {
      await _pickDocumentFile(index);
    }
  }

  Future<void> _pickDocumentFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'png',
        'jpg',
        'jpeg',
        'gif',
        'webp',
      ],
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      for (final picked in result.files) {
        final path = picked.path;
        if (path == null || path.isEmpty) continue;
        _documents.add(
          _StudentDocumentDraft(
            title: p.basenameWithoutExtension(picked.name),
            documentType: _documentTypes.first,
            receivedAt: DateTime.now(),
          )
            ..fileName = picked.name
            ..filePath = path,
        );
      }
    });
  }

  Future<void> _scanStudentDocuments({int? replaceIndex}) async {
    final selectedTab = _formTab;
    final output = await showDialog<ScannerOutput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ScannerDialog(
        service: _studentScannerService,
        combinedPdfOnly: true,
      ),
    );
    if (output == null || !mounted) return;

    final editingStudent = _editingStudent;
    final draft = replaceIndex != null &&
            replaceIndex >= 0 &&
            replaceIndex < _documents.length
        ? _documents[replaceIndex]
        : null;
    if (editingStudent != null) {
      final scannerTags = output.metadataTags.join(', ');
      final tags = <String>{
        ...?draft?.tags
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty),
        ...output.metadataTags,
      }.join(', ');
      var uploaded = 0;
      for (final file in output.files) {
        final fallbackTitle = p.basenameWithoutExtension(file.path);
        final ok = await widget.onUploadDocument(
          title: draft?.title.trim().isNotEmpty == true
              ? draft!.title.trim()
              : fallbackTitle,
          student: editingStudent.fullName,
          sourceImagePath: file.path,
          mimeType: _mimeTypeForPath(file.path),
          studentNo: _studentNoValue,
          course: _courseController.text.trim(),
          schoolYear: _schoolYearController.text.trim(),
          documentType:
              draft == null ? _documentTypes.first : _documentType(draft),
          isComplete: draft?.receivedAt != null,
          college: _collegeNameForProgram(_courseController.text.trim()) ?? '',
          studentCategory: 'Graduated',
          tags: tags.isEmpty ? scannerTags : tags,
          storagePath: '',
        );
        if (ok) uploaded++;
      }
      if (!mounted) return;
      if (uploaded == output.files.length) {
        await _studentScannerService.cleanup(output.sessionDirectory);
        if (!mounted) return;
        if (draft != null) _documents.remove(draft);
        _refreshOpenStudentRecord(selectedTab: selectedTab);
        await _showDocumentUploadSuccess(
          studentLabel: editingStudent.fullName,
          docsSaved: uploaded,
        );
        return;
      }
      _showInfo(
        context,
        'The scanned PDF could not be uploaded. It was kept in the form so '
        'you can retry with Save Student.',
      );
    }

    // A new student must be saved before a document can be associated with it.
    // Failed direct uploads are also staged here so the scan is not lost.
    _studentScannerTempDirectories.add(output.sessionDirectory);
    final scannerTags = output.metadataTags.join(', ');
    setState(() {
      var firstFile = 0;
      if (replaceIndex != null &&
          replaceIndex >= 0 &&
          replaceIndex < _documents.length &&
          output.files.isNotEmpty) {
        final file = output.files.first;
        final draft = _documents[replaceIndex];
        draft.fileName = p.basename(file.path);
        draft.filePath = file.path;
        draft.tags = scannerTags;
        if (draft.title.trim().isEmpty) {
          draft.title = p.basenameWithoutExtension(file.path);
        }
        firstFile = 1;
      }
      for (final file in output.files.skip(firstFile)) {
        if (_documents.any((draft) => draft.filePath == file.path)) continue;
        _documents.add(
          _StudentDocumentDraft(
            title: p.basenameWithoutExtension(file.path),
            documentType: _documentTypes.first,
            tags: scannerTags,
            receivedAt: DateTime.now(),
          )
            ..fileName = p.basename(file.path)
            ..filePath = file.path,
        );
      }
    });
  }

  Future<void> _cleanupStudentScannerFiles() async {
    final directories = List<Directory>.from(_studentScannerTempDirectories);
    _studentScannerTempDirectories.clear();
    for (final directory in directories) {
      await _studentScannerService.cleanup(directory);
    }
  }

  void _dropDocumentFiles(List<XFile> files) {
    setState(() {
      for (final file in files) {
        final path = file.path.trim();
        if (path.isEmpty) continue;
        _documents.add(
          _StudentDocumentDraft(
            title: p.basenameWithoutExtension(path),
            documentType: _documentTypes.first,
            receivedAt: DateTime.now(),
          )
            ..fileName = p.basename(path)
            ..filePath = path,
        );
      }
    });
  }

  void _previewExistingDocument(_DocRow document) {
    _showResizableDocumentViewer(context, document: document);
  }

  void _previewDraftDocument(_StudentDocumentDraft draft) {
    final path = draft.filePath?.trim() ?? '';
    if (path.isEmpty) {
      _showInfo(context, 'Choose a file before opening the viewer.');
      return;
    }

    final mimeType = _mimeTypeForPath(path);
    final title = draft.title.trim().isNotEmpty
        ? draft.title.trim()
        : p.basenameWithoutExtension(draft.fileName ?? p.basename(path));
    final document = _DocRow(
      title: title.isEmpty ? p.basename(path) : title,
      student: _composedFullName(),
      type: mimeType,
      size: '',
      uploaded:
          draft.receivedAt == null ? '' : _formatStudentDate(draft.receivedAt!),
      schoolYear: _schoolYearController.text.trim(),
      studentNo: _studentNoValue,
      program: _courseController.text.trim(),
      documentType: draft.documentType,
      tags: draft.tags,
      localFilePath: path,
      localImagePath: mimeType.startsWith('image/') ? path : null,
    );

    if (!_canPreviewDocument(document)) {
      _showInfo(context, 'Preview is not available for this document.');
      return;
    }
    _showResizableDocumentViewer(context, document: document);
  }

  Future<void> _downloadExistingDocument(_DocRow document) async {
    try {
      final sourcePath = document.localFilePath?.trim() ?? '';
      final localFile = sourcePath.isEmpty ? null : File(sourcePath);
      final hasLocalFile = localFile != null && await localFile.exists();
      final remoteUrl = document.remoteImageUrl.trim();
      if (!hasLocalFile && remoteUrl.isEmpty) {
        if (mounted) _showInfo(context, 'Document file is not available.');
        return;
      }

      var suggestedName = hasLocalFile ? p.basename(sourcePath) : '';
      if (suggestedName.isEmpty && remoteUrl.isNotEmpty) {
        suggestedName = p.basename(Uri.parse(remoteUrl).path);
      }
      if (suggestedName.isEmpty) suggestedName = document.title.trim();
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
      if (mounted) {
        _showInfo(context, 'Could not download document: $error');
      }
    }
  }

  Future<_DocRow?> _editExistingDocument(_DocRow document) async {
    final selectedTab = _formTab;
    final updated = await showDialog<_DocRow?>(
      context: context,
      builder: (context) => _StudentDocumentEditDialog(
        document: document,
        documentTypes: _documentTypes,
        onSave: ({
          required title,
          required documentType,
          required tags,
          required replacementFilePath,
        }) async {
          final replacementPath = replacementFilePath?.trim() ?? '';
          if (replacementPath.isNotEmpty) {
            final uploaded = await widget.onUploadDocument(
              title: title,
              student: document.student,
              sourceImagePath: replacementPath,
              mimeType: _mimeTypeForPath(replacementPath),
              studentNo: document.studentNo.trim().isEmpty
                  ? _studentNoValue
                  : document.studentNo,
              course: _courseController.text.trim(),
              schoolYear: document.schoolYear.trim().isEmpty
                  ? _schoolYearController.text.trim()
                  : document.schoolYear,
              documentType: documentType,
              college: document.college,
              tags: tags,
            );
            if (!uploaded) return null;

            final removedOriginal = await widget.onDeleteDocument(document);
            if (!removedOriginal) return null;
            return document;
          }

          return widget.onUpdateDocument(
            document: document,
            title: title,
            documentType: documentType,
            schoolYear: document.schoolYear,
            program: document.program,
            studentNo: document.studentNo,
            storagePath: document.storagePath,
            college: document.college,
            tags: tags,
          );
        },
      ),
    );
    if (!mounted || updated == null) return updated;
    _refreshOpenStudentRecord(selectedTab: selectedTab);
    await _showSaveConfirmation(
      title: 'Document updated',
      message: 'The document was updated successfully.',
    );
    return updated;
  }

  Future<bool> _deleteExistingDocument(_DocRow document) async {
    final selectedTab = _formTab;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Move document to Trash?'),
        content: Text(
          'Move ${_documentDisplayName(document)} to Trash? '
          'You can restore it later.',
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
    if (confirmed != true || !mounted) return false;

    final deleted = await widget.onDeleteDocument(document);
    if (!mounted) return deleted;
    if (deleted) {
      _refreshOpenStudentRecord(selectedTab: selectedTab);
      await _showSaveConfirmation(
        title: 'Document updated',
        message: 'The document was moved to Trash successfully.',
      );
    } else {
      setState(() {});
      _showInfo(context, 'Could not remove the document.');
    }
    return deleted;
  }

  String _mimeTypeForPath(String path) {
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  static String _defaultSchoolYear() {
    final y = DateTime.now().year;
    return '$y-${y + 1}';
  }

  /// Batches for the dropdown, newest first (e.g. 2025-2026).
  static List<String> _schoolYearOptions() {
    final current = DateTime.now().year;
    const yearsBack = 25;
    const yearsAhead = 5;
    final options = <String>[];
    for (var start = current + yearsAhead;
        start >= current - yearsBack;
        start--) {
      options.add('$start-${start + 1}');
    }
    return options;
  }

  String _documentTitle(_StudentDocumentDraft doc) {
    final title = doc.title.trim();
    if (title.isNotEmpty) return title;
    return doc.documentType;
  }

  String _documentType(_StudentDocumentDraft doc) {
    final type = doc.documentType.trim();
    if (doc.usesCustomDocumentType) return type;
    if (type.isNotEmpty) return type;
    return _documentTypes.isEmpty ? 'Other' : _documentTypes.first;
  }

  Future<void> _showSaveConfirmation({
    required String title,
    required String message,
    bool isWarning = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(
              isWarning ? Icons.warning_amber_rounded : Icons.check_circle,
              color:
                  isWarning ? const Color(0xFFD97706) : const Color(0xFF16A34A),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message, style: _studentFieldTextStyle),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDocumentUploadSuccess({
    required String studentLabel,
    required int docsSaved,
  }) {
    return _showSaveConfirmation(
      title: 'Saved successfully',
      message:
          '$docsSaved document${docsSaved == 1 ? '' : 's'} uploaded for $studentLabel.',
    );
  }

  Future<void> _saveStudent() async {
    final selectedTab = _formTab;
    final studentNo = _studentNoValue;
    final fullName = _composedFullName();
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) {
      _showInfo(context, 'First name and last name are required.');
      setState(() => _formTab = _StudentFormTab.student);
      return;
    }
    final course = _courseController.text.trim();
    if (course.isEmpty) {
      _showInfo(context, 'Please select a program on the Academic tab.');
      setState(() => _formTab = _StudentFormTab.academic);
      return;
    }

    final email = _emailController.text.trim();

    final docNumberOffset = _existingArchivedDocumentCount;
    for (var i = 0; i < _documents.length; i++) {
      final doc = _documents[i];
      final docNumber = docNumberOffset + i + 1;
      if (doc.usesCustomDocumentType && doc.documentType.trim().isEmpty) {
        _showInfo(
          context,
          'Enter the file type name for document #$docNumber.',
        );
        setState(() => _formTab = _StudentFormTab.documents);
        return;
      }
      final filePath = doc.filePath?.trim() ?? '';
      if (filePath.isEmpty) {
        _showInfo(
          context,
          'Choose a file for document #$docNumber before saving.',
        );
        setState(() => _formTab = _StudentFormTab.documents);
        return;
      }
    }

    setState(() => _isSaving = true);
    final editingStudent = _editingStudent;
    late final _StudentRow? saved;
    try {
      saved = editingStudent == null
          ? await widget.onRegisterStudent(
              studentNo: studentNo,
              fullName: fullName,
              course: course,
              year: 0,
              status: 'graduated',
              email: email.isEmpty ? null : email,
              schoolYear: _schoolYearController.text.trim(),
              sex: _sex,
              birthDate: _normalizedStudentDate(_birthDateController),
              phoneNumber: _phoneController.text.trim(),
              notes: _notesController.text.trim(),
              graduationDate: _normalizedStudentDate(_graduatedAtController),
              lastEnrollmentDate: _normalizedStudentDate(_enrolledAtController),
            )
          : await widget.onUpdateStudent(
              student: editingStudent,
              studentNo: studentNo,
              fullName: fullName,
              course: course,
              year: editingStudent.year,
              status: editingStudent.status.trim().isEmpty
                  ? 'graduated'
                  : editingStudent.status,
              email: email.isEmpty ? null : email,
              schoolYear: _schoolYearController.text.trim(),
              sex: _sex,
              birthDate: _normalizedStudentDate(_birthDateController),
              phoneNumber: _phoneController.text.trim(),
              notes: _notesController.text.trim(),
              graduationDate: _normalizedStudentDate(_graduatedAtController),
              lastEnrollmentDate: _normalizedStudentDate(_enrolledAtController),
            );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showInfo(
        context,
        'Could not update student record: '
        '${error.toString().replaceFirst('Bad state: ', '')}',
      );
      return;
    }
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (saved == null) {
      _showInfo(
        context,
        editingStudent == null
            ? 'Could not save student to the local database.'
            : 'Could not update student record.',
      );
      return;
    }

    final studentLabel = saved.fullName;
    final resolvedStudentNo = saved.studentNo;
    final schoolYear = _schoolYearController.text.trim();
    var docsSaved = 0;
    var docsFailed = 0;
    final uploadedDrafts = <_StudentDocumentDraft>{};
    for (final doc in _documents) {
      final path = doc.filePath?.trim() ?? '';
      if (path.isEmpty) continue;
      final documentType = _documentType(doc);
      final college = _collegeNameForProgram(course) ??
          _databaseCollegeName(widget.drillCollegeName) ??
          '';
      final ok = await widget.onUploadDocument(
        title: _documentTitle(doc),
        student: studentLabel,
        sourceImagePath: path,
        mimeType: _mimeTypeForPath(path),
        studentNo: resolvedStudentNo,
        course: course,
        schoolYear: schoolYear,
        documentType: documentType,
        isComplete: doc.receivedAt != null,
        college: college,
        studentCategory: 'Graduated',
        tags: doc.tags,
        storagePath: '',
      );
      if (ok) {
        docsSaved++;
        uploadedDrafts.add(doc);
      } else {
        docsFailed++;
      }
    }

    if (!mounted) return;

    if (docsFailed > 0) {
      setState(() {
        _documents.removeWhere(uploadedDrafts.contains);
        _editingStudent = saved;
        _showForm = true;
        _formTab = selectedTab;
      });
      await _showSaveConfirmation(
        title: 'Student saved with upload issues',
        message:
            'The student record was saved. $docsSaved document(s) uploaded, '
            'but $docsFailed failed. The failed documents remain in the form '
            'so you can try again.',
        isWarning: true,
      );
      return;
    } else if (docsSaved > 0) {
      await _cleanupStudentScannerFiles();
      if (!mounted) return;
      setState(() {
        _documents.clear();
        _editingStudent = saved;
        _showForm = true;
        _formTab = selectedTab;
      });
      await _showSaveConfirmation(
        title:
            editingStudent == null ? 'Student saved' : 'Student record updated',
        message: editingStudent == null
            ? 'Student $studentLabel was saved and $docsSaved '
                'document${docsSaved == 1 ? '' : 's'} uploaded successfully.'
            : 'The student record was updated and $docsSaved '
                'document${docsSaved == 1 ? '' : 's'} uploaded successfully.',
      );
      return;
    } else {
      _refreshOpenStudentRecord(
        student: saved,
        selectedTab: selectedTab,
      );
      await _showSaveConfirmation(
        title:
            editingStudent == null ? 'Student saved' : 'Student record updated',
        message: editingStudent == null
            ? 'Student $studentLabel was saved successfully.'
            : 'The student record was updated successfully.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showForm) {
      return _buildFormView();
    }
    return _buildListView();
  }

  Widget _buildListView() {
    final filtered = _filteredSorted;
    final listPage = _safeListPage(filtered.length);
    final pageRows = _pageSlice(filtered, listPage);
    final showEmpty = filtered.isEmpty;
    final total = widget.rows.length;

    return Theme(
      data: _studentDetailDialogTheme,
      child: CallbackShortcuts(
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
              //   breadcrumbs: breadcrumbs,
              //   onBack: inDrill ? widget.onDrillBack : null,
              //   backTooltip: inDrill ? 'Back to programs' : null,
              //   title: 'Students',
              //   subtitle: inDrill
              //       ? 'Graduated students in ${widget.drillCourseName}.'
              //       : 'Search and manage graduated student records.',
              // ),
              Expanded(
                child: _RecordListCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RecordListToolbar(
                        search: _RecordSearchField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          onChanged: (_) => setState(() => _listPage = 0),
                          hintText: 'Search by name, ID, or email…',
                          focusColor: const Color(0xFF2563EB),
                        ),
                        trailing: [
                          // if (!showEmpty)
                          //   _RecordCountBadge(
                          //     icon: HugeIcons.strokeRoundedUserMultiple,
                          //     label: countLabel,
                          //     accentColor: const Color(0xFF2563EB),
                          //   ),
                          const SizedBox(width: 8),
                          if (widget.canEdit && !widget.drillDownView)
                            _RecordPrimaryButton(
                              label: 'Add student',
                              onPressed: _openAddForm,
                              color: const Color(0xFF2563EB),
                            ),
                        ],
                      ),
                      const Divider(height: 1, color: _RecordListTheme.border),
                      if (!widget.drillDownView) ...[
                        const Divider(
                            height: 1, color: _RecordListTheme.border),
                        _StudentDepartmentProgramFilterBar(
                          department: _filterDepartment,
                          program: _filterProgram,
                          status: _filterBatch,
                          departments: _databaseDepartmentOptions,
                          programs: _filterProgramOptions,
                          statuses: _filterBatchOptions,
                          sortSelection: _sortSelection,
                          onDepartmentChanged: _onDepartmentFilterChanged,
                          onProgramChanged: _onProgramFilterChanged,
                          onStatusChanged: _onBatchFilterChanged,
                          onSortChanged: _onSortSelectionChanged,
                          onClear: _hasActiveFilters ? _resetListFilters : null,
                        ),
                        if (_hasActiveFilters)
                          _StudentActiveFilterSummary(
                            department: _filterDepartment,
                            program: _filterProgram,
                            status: _filterBatch,
                            searchQuery: _searchController.text.trim(),
                            resultCount: filtered.length,
                            totalCount: total,
                          ),
                      ],
                      const Divider(height: 1, color: _RecordListTheme.border),
                      if (showEmpty)
                        _CollegesEmptyState(
                          canEdit: widget.canEdit,
                          hasSearchFilter: _hasActiveFilters,
                          onAdd: _openAddForm,
                          addButtonLabel: 'Add student',
                          addButtonColor: const Color(0xFF2563EB),
                          addButtonForegroundColor: Colors.white,
                          onResetFilters: _resetListFilters,
                        )
                      else
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: DataTable2(
                                  columnSpacing: 12,
                                  horizontalMargin: 16,
                                  headingRowHeight: 38,
                                  dataRowHeight: 46,
                                  fixedTopRows: 1,
                                  minWidth: 760,
                                  dividerThickness: 1,
                                  headingRowColor: WidgetStateProperty.all(
                                    const Color(0xFFF8FAFC),
                                  ),
                                  dataRowColor:
                                      WidgetStateProperty.resolveWith<Color?>(
                                    (states) {
                                      if (states
                                          .contains(WidgetState.hovered)) {
                                        return const Color(0xFFF1F5F9);
                                      }
                                      return null;
                                    },
                                  ),
                                  border: const TableBorder(
                                    horizontalInside: BorderSide(
                                      color: Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  columns: [
                                    DataColumn2(
                                      label: _StudentTableSortLabel(
                                        label: 'Student ID',
                                        column:
                                            _StudentListSortColumn.studentNo,
                                        activeColumn: _sortColumn,
                                        ascending: _sortAscending,
                                        onSort: _onSortColumn,
                                      ),
                                      fixedWidth: 150,
                                    ),
                                    DataColumn2(
                                      label: _StudentTableSortLabel(
                                        label: 'Name',
                                        column: _StudentListSortColumn.name,
                                        activeColumn: _sortColumn,
                                        ascending: _sortAscending,
                                        onSort: _onSortColumn,
                                      ),
                                      size: ColumnSize.L,
                                    ),
                                    DataColumn2(
                                      label: _StudentTableSortLabel(
                                        label: 'Program',
                                        column: _StudentListSortColumn.program,
                                        activeColumn: _sortColumn,
                                        ascending: _sortAscending,
                                        onSort: _onSortColumn,
                                      ),
                                      size: ColumnSize.L,
                                    ),
                                    DataColumn2(
                                      label: Text(
                                        'Batch',
                                        style: _studentTableHeaderTextStyle,
                                      ),
                                      fixedWidth: 116,
                                    ),
                                    DataColumn2(
                                      label: Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          'Actions',
                                          style: _studentTableHeaderTextStyle,
                                        ),
                                      ),
                                      fixedWidth: 136,
                                    ),
                                  ],
                                  rows: List<DataRow>.generate(
                                    pageRows.length,
                                    (index) {
                                      final s = pageRows[index];
                                      final batch = _schoolYearForStudent(s);
                                      return DataRow2(
                                        onTap: () => _showStudentDetail(s),
                                        color: WidgetStateProperty.all(
                                          index.isOdd
                                              ? const Color(0xFFFAFBFC)
                                              : Colors.transparent,
                                        ),
                                        cells: [
                                          DataCell(
                                            Text(
                                              StudentNumber.displayValue(
                                                s.studentNo,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF111827),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              _nameCase(s.fullName),
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF111827),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              _sentenceCase(s.course),
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF111827),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              batch.isEmpty
                                                  ? 'Unassigned'
                                                  : batch,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF111827),
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
                                                  _RecordDownloadAction(
                                                    onPressed: () =>
                                                        _downloadStudentPdfArchive(
                                                      s,
                                                    ),
                                                    tooltip:
                                                        'Download all PDFs',
                                                  ),
                                                  _RecordEditAction(
                                                    onPressed: widget.canEdit
                                                        ? () => _openEditForm(s)
                                                        : null,
                                                  ),
                                                  if (widget.isAdmin) ...[
                                                    const SizedBox(width: 2),
                                                    _RecordDeleteAction(
                                                      onPressed: () =>
                                                          _confirmDeleteStudent(
                                                        s,
                                                      ),
                                                      tooltip: 'Move to trash',
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                              _StudentListPaginationBar(
                                currentPage: listPage,
                                totalPages: _totalListPages(filtered.length),
                                totalItems: filtered.length,
                                pageSize: _studentsPageSize,
                                onPageChanged: _goToListPage,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Theme(
      data: _studentDetailDialogTheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StudentsFormTopBar(
            onBack: _backToList,
            canEdit: widget.canEdit,
            onAdd: widget.canEdit ? _openAddForm : null,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StudentFormTabBar(
                    tab: _formTab,
                    onChanged: (t) => setState(() => _formTab = t),
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _buildActiveFormTab(),
                            ),
                          ),
                          if (_formTab == _StudentFormTab.documents) ...[
                            const Divider(
                              height: 1,
                              color: Color(0xFFE5E7EB),
                            ),
                            _StudentDocumentsSection(
                              documents: _documents,
                              existingDocuments: _existingDocumentsForEditing,
                              existingDocumentCount:
                                  _existingArchivedDocumentCount,
                              onAdd: _addDocument,
                              onRemove: _removeDocument,
                              onPickDate: _pickDocumentDate,
                              onPickFile: _chooseDocumentFileSource,
                              onPickFiles: _pickDocumentFiles,
                              onScanDocuments: _scanStudentDocuments,
                              onDropFiles: _dropDocumentFiles,
                              documentTypes: _documentTypes,
                              onDocumentChanged: () => setState(() {}),
                              onPreviewExisting: _previewExistingDocument,
                              onPreviewDraft: _previewDraftDocument,
                              onDownloadExisting: _downloadExistingDocument,
                              onEditExisting: _editExistingDocument,
                              onDeleteExisting: _deleteExistingDocument,
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                            child: Row(
                              children: [
                                FilledButton(
                                  onPressed: _isSaving ? null : _saveStudent,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _collegeTealDark,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(_editingStudent == null
                                          ? 'Save student'
                                          : 'Update student'),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton(
                                  onPressed: _isSaving ? null : _backToList,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _studentTextBlack,
                                    side: const BorderSide(
                                      color: Color(0xFFE5E7EB),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Student List'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFormTab() {
    switch (_formTab) {
      case _StudentFormTab.student:
        return _buildStudentTab(key: const ValueKey('student'));
      case _StudentFormTab.academic:
        return _buildAcademicTab(key: const ValueKey('academic'));
      case _StudentFormTab.contact:
        return _buildContactTab(key: const ValueKey('contact'));
      case _StudentFormTab.notes:
        return _buildNotesTab(key: const ValueKey('notes'));
      case _StudentFormTab.dates:
        return _buildDatesTab(key: const ValueKey('dates'));
      case _StudentFormTab.documents:
        return const SizedBox(key: ValueKey('documents'));
    }
  }

  Widget _buildStudentTab({required Key key}) {
    return Column(
      key: key,
      children: [
        _StudentLabeledField(
          label: 'Student ID',
          child: Row(
            children: [
              Expanded(
                child: _StudentTextField(
                  controller: _studentNoController,
                  hint: 'Optional (e.g. ${StudentNumber.example})',
                  inputFormatters: [_StudentNumberInputFormatter()],
                  readOnly: _studentIdNotAvailable,
                ),
              ),
              const SizedBox(width: 10),
              FilterChip(
                label: const Text(StudentNumber.notAvailable),
                selected: _studentIdNotAvailable,
                tooltip: 'Student ID is not available',
                onSelected: _setStudentIdNotAvailable,
              ),
            ],
          ),
        ),
        _StudentLabeledField(
          label: 'First name',
          required: true,
          child: _StudentTextField(controller: _firstNameController),
        ),
        _StudentLabeledField(
          label: 'Middle name',
          child: _StudentTextField(controller: _middleNameController),
        ),
        _StudentLabeledField(
          label: 'Last name',
          required: true,
          child: _StudentTextField(controller: _lastNameController),
        ),
        _StudentLabeledField(
          label: 'Suffix',
          child: _StudentTextField(controller: _suffixController),
        ),
        _StudentLabeledField(
          label: 'Birth date',
          child: _StudentDateField(
            controller: _birthDateController,
            showWarning: _birthDate == null,
            onPick: _pickBirthDate,
          ),
        ),
        _StudentLabeledField(
          label: 'Sex',
          child: DropdownButtonFormField<String>(
            initialValue: _sex.isEmpty ? null : _sex,
            style: _studentInputTextStyle,
            dropdownColor: Colors.white,
            isExpanded: true,
            decoration: _studentInputDecoration(hint: 'Select sex'),
            items: const [
              DropdownMenuItem(value: 'Female', child: Text('Female')),
              DropdownMenuItem(value: 'Male', child: Text('Male')),
            ],
            onChanged: (value) => setState(() => _sex = value ?? ''),
          ),
        ),
      ],
    );
  }

  Widget _buildAcademicTab({required Key key}) {
    final collegeIds = _databaseColleges.map((college) => college.id).toSet();
    final collegeValue = collegeIds.contains(_selectedFormCollegeId)
        ? _selectedFormCollegeId
        : null;
    final selectable = _databaseProgramsForCollege(collegeValue);
    final programValue = _resolvedProgramDropdownValue(
      _courseController.text,
      selectable,
    );
    return Column(
      key: key,
      children: [
        _StudentLabeledField(
          label: 'College',
          required: true,
          child: DropdownButtonFormField<int>(
            initialValue: collegeValue,
            menuMaxHeight: _studentSelectorMenuMaxHeight,
            borderRadius: BorderRadius.circular(8),
            style: _studentInputTextStyle,
            dropdownColor: Colors.white,
            isExpanded: true,
            decoration: _studentInputDecoration(
              hint: _databaseColleges.isEmpty
                  ? 'No colleges available'
                  : 'Select college',
            ),
            items: _databaseColleges
                .map(
                  (college) => DropdownMenuItem<int>(
                    value: college.id,
                    child: Text(
                      college.name,
                      overflow: TextOverflow.ellipsis,
                      style: _studentInputTextStyle,
                    ),
                  ),
                )
                .toList(),
            onChanged: _databaseColleges.isEmpty
                ? null
                : (value) {
                    final programs = _databaseProgramsForCollege(value);
                    setState(() {
                      _selectedFormCollegeId = value;
                      _courseController.text =
                          programs.isEmpty ? '' : programs.first;
                    });
                  },
          ),
        ),
        _StudentLabeledField(
          label: 'Program',
          required: true,
          child: DropdownButtonFormField<String>(
            key: ValueKey<String>(
              'program:${collegeValue ?? 'none'}:${programValue ?? 'none'}',
            ),
            initialValue: programValue,
            menuMaxHeight: _studentSelectorMenuMaxHeight,
            borderRadius: BorderRadius.circular(8),
            style: _studentInputTextStyle,
            dropdownColor: Colors.white,
            isExpanded: true,
            decoration: _studentInputDecoration(
              hint: collegeValue == null
                  ? 'Select a college first'
                  : selectable.isEmpty
                      ? 'No programs available'
                      : 'Select program',
            ),
            items: _flatProgramDropdownItems(selectable),
            onChanged: selectable.isEmpty
                ? null
                : (v) {
                    if (v == null || v.startsWith('\u0000header:')) return;
                    setState(() => _courseController.text = v);
                  },
          ),
        ),
        _StudentLabeledField(
          label: 'Batch',
          required: true,
          child: DropdownButtonFormField<String>(
            key: ValueKey('school-year:${_schoolYearController.text}'),
            initialValue:
                _schoolYearOptions().contains(_schoolYearController.text)
                    ? _schoolYearController.text
                    : _defaultSchoolYear(),
            style: _studentInputTextStyle,
            dropdownColor: Colors.white,
            isExpanded: true,
            decoration: _studentInputDecoration(),
            items: _schoolYearOptions()
                .map(
                  (y) => DropdownMenuItem(
                    value: y,
                    child: Text(y, style: _studentInputTextStyle),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _schoolYearController.text = v);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContactTab({required Key key}) {
    return Column(
      key: key,
      children: [
        _StudentLabeledField(
          label: 'Email',
          child: _StudentTextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
          ),
        ),
        _StudentLabeledField(
          label: 'Phone',
          child: _StudentTextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesTab({required Key key}) {
    return Column(
      key: key,
      children: [
        _StudentLabeledField(
          label: 'Notes',
          child: TextField(
            controller: _notesController,
            maxLines: 6,
            inputFormatters: [LengthLimitingTextInputFormatter(4000)],
            style: _studentInputTextStyle,
            decoration: _studentInputDecoration().copyWith(counterText: ''),
          ),
        ),
      ],
    );
  }

  Widget _buildDatesTab({required Key key}) {
    return Column(
      key: key,
      children: [
        _StudentLabeledField(
          label: 'Enrolled at',
          child: _StudentDateField(
            controller: _enrolledAtController,
            showWarning: false,
            onPick: _pickEnrolledAt,
          ),
        ),
        _StudentLabeledField(
          label: 'Graduated at',
          child: _StudentDateField(
            controller: _graduatedAtController,
            showWarning: false,
            onPick: _pickGraduatedAt,
          ),
        ),
      ],
    );
  }
}
