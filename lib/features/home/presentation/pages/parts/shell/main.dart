part of '../../dashboard_shell_page.dart';

class DashboardShellPage extends StatefulWidget {
  const DashboardShellPage({
    super.key,
    required this.role,
    required this.loginUseCase,
    required this.accountName,
  });

  final UserRole role;
  final LoginUseCase loginUseCase;
  final String accountName;

  @override
  State<DashboardShellPage> createState() => _DashboardShellPageState();
}

class _DashboardShellPageState extends State<DashboardShellPage> {
  final _database = AppDatabase.instance;
  final _dashboardSearchController = TextEditingController();
  String _dashboardSearchQuery = '';
  bool _collapsed = false;
  String _selectedNavId = 'dashboard';
  final Set<String> _collapsedSections = {
    'Dashboard',
    'Student Records',
    'Settings',
    'Accounts',
    'System',
  };
  late final bool _isAdmin;
  // Use a white/light theme for all roles.
  bool get _isDarkAdmin => false;

  final List<_StudentRow> _students = [];
  bool _isLoadingStudents = true;
  String? _studentsLoadError;
  final List<_DocRow> _docs = [];
  bool _isLoadingDocs = true;
  String? _docsLoadError;
  bool _docsHasMore = false;
  int? _docsNextBeforeId;
  int _documentTotalCount = 0;
  int _archiveDocumentTotalCount = 0;
  int _studentsWithoutDocumentsTotal = 0;
  String _documentSearch = '';
  String _documentSchoolYear = '';
  String _documentCollege = '';
  String _documentProgram = '';
  String _documentType = '';
  final List<_DocRow> _deletedDocs = [];
  final List<_StudentRow> _deletedStudents = [];
  final List<_CollegeRow> _deletedColleges = [];
  bool _isLoadingDeletedDocs = false;
  String? _deletedDocsLoadError;
  String? _archivedStudentFilter;
  String? _documentsStudentFilter;
  final List<_CollegeRow> _colleges = [];
  bool _isLoadingColleges = true;
  String? _collegesLoadError;
  final List<_CourseRow> _courses = [];
  bool _isLoadingCourses = true;
  String? _coursesLoadError;
  int? _drillCollegeId;
  String? _drillCollegeName;
  int? _drillCourseId;
  String? _drillCourseName;
  String? _analyticsGraduatesYear;
  String? _analyticsGraduatesProgramName;
  String? _analyticsGraduatesProgramCode;
  int _dataAnalyticsSession = 0;
  Map<String, int> _studentCountByCourseName = {};
  Map<int, int> _courseCountByCollegeId = {};
  final List<_AuditRow> _audit = [];
  bool _isLoadingAudit = false;

  Timer? _dashboardSearchDebounce;
  _DashboardPrepared? _cachedDashboardPrepared;
  String? _dashboardPreparedKey;
  int _dashboardDataGeneration = 0;
  bool _dashboardShellDataReady = false;
  bool _dashboardPriorityReady = false;
  bool _dashboardSecondaryReady = false;
  bool _dashboardAnalyticsReady = false;
  String? _queuedNavId;
  bool _navUpdateScheduled = false;
  _AnalyticsData? _cachedDashboardAnalytics;
  _AnalyticsData? _cachedFullAnalytics;
  int _fullAnalyticsCacheGeneration = -1;
  bool _fullAnalyticsLoading = false;
  Widget? _backupRestorePage;
  Widget? _disposableRecordsPage;
  final Map<String, List<_AnalyticsGraduate>> _graduatesByYearCache = {};
  final Map<String, List<_CourseCount>> _courseCountsByYearCache = {};
  late final List<_SidebarNavSection> _navSections;

  static const _dashboardSchoolYearsLimit = 5;

  @override
  void dispose() {
    _dashboardSearchDebounce?.cancel();
    _dashboardSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _isAdmin = widget.role == UserRole.admin;
    _database.userRole = _isAdmin ? 'admin' : 'staff';
    _database.userName = widget.accountName;
    _navSections = _createNavSections();
    _expandSectionForNavId(_selectedNavId);
    _loadDashboardPriorityData();
    _loadSecondaryShellData();
    _loadAuditLogs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maximizeDashboardWindow();
    });
  }

  Future<void> _maximizeDashboardWindow() async {
    try {
      await windowManager.show();
      await windowManager.restore();
      await windowManager.focus();
      await windowManager.maximize();
    } catch (_) {
      // Some test and headless environments do not expose a desktop display.
    }
  }

  void _syncDashboardShellReady() {
    final ready = _dashboardPriorityReady && _dashboardSecondaryReady;
    if (_dashboardShellDataReady == ready &&
        (!ready || !_isAdmin || _dashboardAnalyticsReady)) {
      return;
    }
    _dashboardShellDataReady = ready;
    if (ready && _isAdmin && !_dashboardAnalyticsReady) {
      _dashboardAnalyticsReady = true;
      _refreshDashboardPrepared(withAnalytics: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkAdmin ? _adminBg : const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Row(
          children: [
            _DashboardSidebar(
              isDarkAdmin: _isDarkAdmin,
              collapsed: _collapsed,
              role: widget.role,
              accountName: widget.accountName,
              sections: _navSections,
              collapsedSections: _collapsedSections,
              selectedId: _selectedNavId,
              onToggleCollapse: _toggleSidebar,
              onSectionToggle: _toggleSectionCollapsed,
              onLogout: _logout,
              onItemSelected: _selectNavItem,
            ),
            Expanded(
              child: _selectedNavId == 'dashboard'
                  ? SizedBox.expand(
                      key: const ValueKey<String>('dashboard'),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                        child: _buildContent(includeHeader: false),
                      ),
                    )
                  : _analyticsGraduatesYear != null
                      ? SizedBox.expand(
                          key: const ValueKey<String>(
                            'data_analytics_graduates',
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: _buildContent(),
                            ),
                          ),
                        )
                      : _selectedNavId == 'data_analytics' &&
                              _analyticsGraduatesYear == null
                          ? Padding(
                              key: const ValueKey<String>('data_analytics'),
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                              child: _buildDataAnalyticsViewport(),
                            )
                          : _contentFillsViewport(_selectedNavId)
                              ? Padding(
                                  key: ValueKey<String>(_selectedNavId),
                                  padding:
                                      const EdgeInsets.fromLTRB(24, 20, 24, 24),
                                  child: _buildContent(),
                                )
                              : SingleChildScrollView(
                                  key: ValueKey<String>(_selectedNavId),
                                  padding:
                                      const EdgeInsets.fromLTRB(24, 20, 24, 24),
                                  child: _buildContent(),
                                ),
            ),
          ],
        ),
      ),
    );
  }

  void _logout() {
    _database.userRole = '';
    _database.userName = 'system';
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginPage(loginUseCase: widget.loginUseCase),
      ),
      (_) => false,
    );
  }

  List<_SidebarNavSection> _createNavSections() {
    final dashboardItems = <_SidebarNavItem>[
      _SidebarNavItem(
        id: 'dashboard',
        title: _isAdmin ? 'Dashboard' : 'Dashboard',
        icon: HugeIcons.strokeRoundedDashboardSquare01,
      ),
      if (_isAdmin) ...[
        _SidebarNavItem(
          id: 'data_analytics',
          title: 'Analytics',
          icon: HugeIcons.strokeRoundedChartLineData01,
        ),
      ],
    ];
    final sections = <_SidebarNavSection>[
      _SidebarNavSection(
        title: 'Dashboard',
        items: dashboardItems,
      ),
      _SidebarNavSection(
        title: 'Student Records',
        items: [
          _SidebarNavItem(
            id: 'colleges',
            title: 'Colleges',
            icon: HugeIcons.strokeRoundedUniversity,
          ),
          _SidebarNavItem(
            id: 'courses',
            title: 'Programs',
            icon: HugeIcons.strokeRoundedBookOpen01,
          ),
          _SidebarNavItem(
            id: 'students',
            title: 'Students',
            icon: HugeIcons.strokeRoundedUserMultiple,
          ),
          _SidebarNavItem(
            id: 'documents',
            title: 'Documents',
            icon: HugeIcons.strokeRoundedFolder03,
          ),
        ],
      ),
      _SidebarNavSection(
        title: 'System',
        items: [
          _SidebarNavItem(
            id: 'archived_documents',
            title: 'Trash',
            icon: HugeIcons.strokeRoundedDelete02,
          ),
        ],
      ),
    ];
    if (_isAdmin) {
      sections.addAll([
        _SidebarNavSection(
          title: 'Settings',
          items: [
            _SidebarNavItem(
              id: 'settings',
              title: 'Settings',
              icon: HugeIcons.strokeRoundedSettings02,
            ),
          ],
        ),
        _SidebarNavSection(
          title: 'Accounts',
          items: [
            _SidebarNavItem(
              id: 'users',
              title: 'Users',
              icon: HugeIcons.strokeRoundedUserSettings01,
            ),
          ],
        ),
        _SidebarNavSection(
          title: 'Administration',
          items: [
            _SidebarNavItem(
              id: 'settings_colleges',
              title: 'Manage Colleges',
              icon: HugeIcons.strokeRoundedBuilding03,
            ),
          ],
        ),
      ]);
      final systemSection = sections.firstWhere(
        (section) => section.title == 'System',
      );
      systemSection.items.addAll([
        _SidebarNavItem(
          id: 'activity_log',
          title: 'Activity Log',
          icon: HugeIcons.strokeRoundedTransactionHistory,
        ),
        _SidebarNavItem(
          id: 'disposable_records',
          title: 'Disposable Records',
          icon: HugeIcons.strokeRoundedPackage,
        ),
        _SidebarNavItem(
          id: 'backup_restore',
          title: 'Backup & Restore',
          icon: HugeIcons.strokeRoundedDatabaseRestore,
        ),
      ]);
    }
    return sections;
  }

  String get _selectedNavTitle {
    for (final section in _navSections) {
      for (final item in section.items) {
        if (item.id == _selectedNavId) return item.title;
      }
    }
    return 'Overall Dashboard';
  }

  Widget _buildDataAnalyticsMainPage() {
    if (_cachedFullAnalytics == null) {
      _ensureFullAnalytics();
      return const _AnalyticsLoadingSkeleton(
        pinnedHeader: true,
      );
    }
    return _DataAnalyticsPage(
      key: ValueKey<int>(_dataAnalyticsSession),
      data: _cachedFullAnalytics!,
      courseCountsForYear: _courseCountsForYear,
      onViewYearGraduates: _viewAnalyticsGraduates,
      allGraduates: _allAnalyticsGraduates,
      onSelectGraduate: _openAnalyticsGraduate,
      pinnedHeader: true,
    );
  }

  Widget _buildDataAnalyticsViewport() {
    return SizedBox.expand(child: _buildDataAnalyticsMainPage());
  }

  Widget _buildContent({bool includeHeader = true}) {
    if (_selectedNavId == 'dashboard') {
      if (!_dashboardShellDataReady) {
        return const _DashboardLoadingSkeleton();
      }

      if (_cachedDashboardPrepared == null) {
        _refreshDashboardPrepared();
      }
      final prepared = _cachedDashboardPrepared;
      if (prepared == null) {
        return const _DashboardLoadingSkeleton();
      }

      final segments = prepared.segments;
      final base = _DashboardBaseData(
        accountName: widget.accountName,
        studentsCount: prepared.studentsCount,
        documentsCount: prepared.documentsCount,
        coursesCount: _courses.length,
        collegesCount: _colleges.length,
        recentUploadsCount: prepared.documentsCount,
        studentsWithoutDocs: prepared.studentsWithoutDocs,
        topProgramName: segments.isEmpty ? null : segments.first.label,
        topProgramCount: segments.isEmpty ? 0 : segments.first.count,
        courseSegments: segments,
        recentDocs: prepared.filteredRecentDocs,
        recentAudit: _audit.take(3).toList(),
        searchController: _dashboardSearchController,
        onSearchChanged: _onDashboardSearchChanged,
        onNavigate: _selectNavItem,
        onViewStudentDocuments:
            widget.role == UserRole.admin ? _openDocumentsForStudent : null,
        analytics: prepared.analytics,
        showAnalyticsCharts: _dashboardAnalyticsReady,
      );

      if (_studentsLoadError != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Text(
                _studentsLoadError!,
                style: const TextStyle(color: Color(0xFF9A3412), fontSize: 12),
              ),
            ),
            Expanded(
              child: widget.role == UserRole.admin
                  ? _AdminDashboardPage(
                      data: base, includeHeader: includeHeader)
                  : _StaffDashboardPage(
                      data: base, includeHeader: includeHeader),
            ),
          ],
        );
      }

      return widget.role == UserRole.admin
          ? _AdminDashboardPage(data: base, includeHeader: includeHeader)
          : _StaffDashboardPage(data: base, includeHeader: includeHeader);
    }
    if (_selectedNavId == 'colleges') {
      if (_drillCourseId != null && _drillCourseName != null) {
        final courseStudents =
            _students.where((s) => s.course == _drillCourseName).toList();
        return _StudentRecordsPage(
          rows: courseStudents,
          documents: _docs,
          courses: _courses,
          colleges: _colleges,
          programCodeForCourse: _programCodeForCourse,
          onRegisterStudent: _registerStudent,
          onUpdateStudent: _updateStudent,
          onUploadDocument: _uploadStudentDocument,
          onUpdateDocument: _updateDocumentMetadata,
          onDeleteDocument: _deleteDocument,
          onViewStudentDocuments: _openDocumentsForStudent,
          onViewAllDocuments: _openDocuments,
          onDeleteStudent: _deleteStudent,
          canEdit: true,
          isAdmin: _isAdmin,
          drillCollegeName: _drillCollegeName,
          drillCourseName: _drillCourseName,
          onDrillBack: _backToCollegeCourses,
          drillDownView: true,
        );
      }
      if (_drillCollegeId != null) {
        final collegeCourses =
            _courses.where((c) => c.collegeId == _drillCollegeId).toList();
        return _CoursesPage(
          rows: collegeCourses,
          colleges: _colleges,
          canEdit: true,
          canAdd: true,
          isLoading: _isLoadingCourses,
          loadError: _coursesLoadError,
          onRefresh: () => _loadCourses(),
          onAddCourse: _addCourse,
          onUpdateCourse: _updateCourse,
          onDeleteCourse: _deleteCourse,
          collegeName: _drillCollegeName,
          initialCollegeId: _drillCollegeId,
          onBack: _backToColleges,
          onCourseSelected: _openCourseStudents,
          studentCountByName: _studentCountByCourseName,
        );
      }
      return _CollegesPage(
        rows: _colleges,
        canEdit: false,
        isLoading: _isLoadingColleges,
        loadError: _collegesLoadError,
        onRefresh: () => _loadColleges(),
        onAddCollege: _addCollege,
        onUpdateCollege: _updateCollege,
        onDeleteCollege: _deleteCollege,
        onCollegeSelected: _openCollegeCourses,
        courseCountByCollegeId: _courseCountByCollegeId,
      );
    }
    if (_selectedNavId == 'students') {
      return _StudentRecordsPage(
        rows: _students,
        documents: _docs,
        courses: _courses,
        colleges: _colleges,
        programCodeForCourse: _programCodeForCourse,
        onRegisterStudent: _registerStudent,
        onUpdateStudent: _updateStudent,
        onUploadDocument: _uploadStudentDocument,
        onUpdateDocument: _updateDocumentMetadata,
        onDeleteDocument: _deleteDocument,
        onViewStudentDocuments: _openDocumentsForStudent,
        onViewAllDocuments: _openDocuments,
        onDeleteStudent: _deleteStudent,
        canEdit: true,
        isAdmin: _isAdmin,
      );
    }
    if (_selectedNavId == 'courses') {
      if (_drillCourseId != null && _drillCourseName != null) {
        final courseStudents =
            _students.where((s) => s.course == _drillCourseName).toList();
        return _StudentRecordsPage(
          rows: courseStudents,
          documents: _docs,
          courses: _courses,
          colleges: _colleges,
          programCodeForCourse: _programCodeForCourse,
          onRegisterStudent: _registerStudent,
          onUpdateStudent: _updateStudent,
          onUploadDocument: _uploadStudentDocument,
          onUpdateDocument: _updateDocumentMetadata,
          onDeleteDocument: _deleteDocument,
          onViewStudentDocuments: _openDocumentsForStudent,
          onViewAllDocuments: _openDocuments,
          onDeleteStudent: _deleteStudent,
          canEdit: true,
          isAdmin: _isAdmin,
          drillCourseName: _drillCourseName,
          drillFromProgramsList: true,
          onDrillBack: _backToPrograms,
          drillDownView: true,
        );
      }
      return _CoursesPage(
        rows: _courses,
        colleges: _colleges,
        canEdit: true,
        canAdd: true,
        isLoading: _isLoadingCourses,
        loadError: _coursesLoadError,
        onRefresh: () => _loadCourses(),
        onAddCourse: _addCourse,
        onUpdateCourse: _updateCourse,
        onDeleteCourse: _deleteCourse,
        onCourseSelected: _openCourseStudents,
        studentCountByName: _studentCountByCourseName,
      );
    }
    if (_selectedNavId == 'archived_documents') {
      return _DocumentArchivePage(
        rows: _deletedDocs,
        students: _deletedStudents,
        colleges: _deletedColleges,
        isAdmin: _isAdmin,
        isLoading: _isLoadingDeletedDocs,
        loadError: _deletedDocsLoadError,
        studentFilter: _archivedStudentFilter,
        onStudentFilterChanged: (student) {
          setState(() => _archivedStudentFilter = student);
        },
        onRefreshRequested: () => _loadDeletedDocuments(),
        onRestoreDoc: _restoreTrashDocument,
        onDeleteDoc: _purgeDeletedDocument,
        onDeleteDocs: _purgeDeletedDocuments,
        onRestoreStudent: _restoreTrashStudent,
        onDeleteStudent: _purgeTrashStudent,
        onRestoreCollege: _restoreTrashCollege,
        onDeleteCollege: _purgeTrashCollege,
      );
    }
    if (_selectedNavId == 'documents') {
      return _DocumentModulePage(
        rows: _docs,
        students: _students,
        courses: _courses,
        colleges: _colleges,
        isLoading: _isLoadingDocs,
        loadError: _docsLoadError,
        studentFilter: _documentsStudentFilter,
        onStudentFilterChanged: (student) {
          setState(() => _documentsStudentFilter = student);
        },
        onRefreshRequested: () => _loadDocuments(),
        onQueryChanged: _queryDocuments,
        onLoadMore: _loadMoreDocuments,
        hasMore: _docsHasMore,
        totalCount: _documentTotalCount,
        onUploadDocument: _uploadStudentDocument,
        onUpdateDocument: _updateDocumentMetadata,
        onDeleteDocument: _deleteDocument,
        canDelete: _isAdmin,
      );
    }
    if (_selectedNavId == 'users') {
      return _UserManagementPage(isAdmin: _isAdmin);
    }
    if (_selectedNavId == 'activity_log') {
      return _AuditLogPage(rows: _audit);
    }
    if (_selectedNavId == 'disposable_records') {
      _disposableRecordsPage ??= _DisposableRecordsPage(isAdmin: _isAdmin);
      return _disposableRecordsPage!;
    }
    if (_selectedNavId == 'backup_restore') {
      _backupRestorePage ??= _BackupRestorePage(isAdmin: _isAdmin);
      return _backupRestorePage!;
    }
    if (_selectedNavId == 'settings') {
      return _SystemSettingsPage(
        accountName: widget.accountName,
        role: widget.role,
        auditRows: _audit,
        isLoadingAudit: _isLoadingAudit,
        onRefreshLogs: _loadAuditLogs,
      );
    }
    if (_selectedNavId == 'data_analytics') {
      if (_analyticsGraduatesYear != null) {
        final year = _analyticsGraduatesYear!;
        return _YearGraduatesViewPage(
          year: year,
          graduates: _graduatesForYear(
            year,
            programName: _analyticsGraduatesProgramName,
            programCode: _analyticsGraduatesProgramCode,
          ),
          programName: _analyticsGraduatesProgramName,
          programCode: _analyticsGraduatesProgramCode,
          onBack: _backFromAnalyticsGraduates,
          onBreadcrumbTap: _onAnalyticsBreadcrumbTap,
        );
      }
      return _buildDataAnalyticsMainPage();
    }
    if (_selectedNavId == 'settings_colleges') {
      return _SettingsCollegesPage(
        rows: _colleges,
        isLoading: _isLoadingColleges,
        loadError: _collegesLoadError,
        onRefresh: () => _loadColleges(),
        onAddCollege: _addCollege,
        onUpdateCollege: _updateCollege,
        onDeleteCollege: _deleteCollege,
        courseCountByCollegeId: _courseCountByCollegeId,
      );
    }
    return _TemplatePagePlaceholder(
      title: _selectedNavTitle,
      subtitle: 'This page is ready for feature details.',
    );
  }

  void _toggleSidebar() {
    setState(() {
      _collapsed = !_collapsed;
    });
  }

  void _toggleSectionCollapsed(String title) {
    setState(() {
      if (_collapsedSections.contains(title)) {
        _collapsedSections.remove(title);
      } else {
        _collapsedSections.add(title);
      }
    });
  }

  void _expandSectionForNavId(String id) {
    for (final section in _navSections) {
      if (section.items.any((item) => item.id == id)) {
        _collapsedSections.remove(section.title);
        return;
      }
    }
  }

  void _selectNavItem(String id) {
    _queuedNavId = id;
    if (_navUpdateScheduled) return;
    _navUpdateScheduled = true;
    Future<void>.delayed(Duration.zero, () {
      _navUpdateScheduled = false;
      if (!mounted) return;
      final nextId = _queuedNavId;
      _queuedNavId = null;
      if (nextId == null) return;
      _applyNavSelection(nextId);
    });
  }

  void _applyNavSelection(String id) {
    if (id == _selectedNavId &&
        id != 'data_analytics' &&
        _analyticsGraduatesYear == null) {
      return;
    }

    final fromNavId = _selectedNavId;
    setState(() {
      _selectedNavId = id;
      _expandSectionForNavId(id);
      if (id != 'data_analytics') {
        _analyticsGraduatesYear = null;
        _analyticsGraduatesProgramName = null;
        _analyticsGraduatesProgramCode = null;
      }
      if (id == 'documents') {
        _documentsStudentFilter = null;
      }
      if (id == 'archived_documents') {
        _archivedStudentFilter = null;
      }
      if (id != 'colleges' && id != 'courses') {
        _resetRecordsDrill();
      } else if (id == 'colleges') {
        // Always return to the colleges list (sidebar re-click included).
        _resetRecordsDrill();
      } else if (id == 'courses') {
        if (fromNavId != 'courses') {
          _resetRecordsDrill();
        } else {
          // Re-select Programs: leave student drill, keep top-level list.
          _drillCourseId = null;
          _drillCourseName = null;
        }
      }
    });

    if (id == 'dashboard') {
      _scheduleDashboardAnalyticsReveal();
    }
    if (id == 'documents') {
      _loadDocuments(showLoading: _docs.isEmpty);
    }
    if (id == 'archived_documents') {
      _loadDeletedDocuments(showLoading: _deletedDocs.isEmpty);
    }
    if (id == 'colleges' || id == 'settings_colleges') {
      _loadColleges(showLoading: _colleges.isEmpty);
    }
    if (id == 'courses') {
      _loadCourses(showLoading: _courses.isEmpty);
    }
    if (id == 'activity_log') {
      _loadAuditLogs();
    }
    if (id == 'data_analytics') {
      _openDataAnalytics();
    }
  }

  void _resetRecordsDrill() {
    _drillCollegeId = null;
    _drillCollegeName = null;
    _drillCourseId = null;
    _drillCourseName = null;
  }

  void _openCollegeCourses(_CollegeRow college) {
    if (college.id == null) return;
    setState(() {
      _drillCollegeId = college.id;
      _drillCollegeName = college.name;
      _drillCourseId = null;
      _drillCourseName = null;
    });
    _loadCourses(showLoading: _courses.isEmpty);
  }

  void _openCourseStudents(_CourseRow course) {
    setState(() {
      _drillCourseId = course.id;
      _drillCourseName = course.name;
    });
  }

  void _backToColleges() {
    setState(_resetRecordsDrill);
  }

  void _backToCollegeCourses() {
    setState(() {
      _drillCourseId = null;
      _drillCourseName = null;
    });
  }

  void _backToPrograms() {
    setState(() {
      _drillCourseId = null;
      _drillCourseName = null;
    });
  }

  void _openDataAnalytics() {
    setState(() {
      _analyticsGraduatesYear = null;
      _analyticsGraduatesProgramName = null;
      _analyticsGraduatesProgramCode = null;
      _dataAnalyticsSession++;
    });
    _ensureFullAnalytics();
  }

  void _viewAnalyticsGraduates(
    String year, {
    String? programName,
    String? programCode,
  }) {
    setState(() {
      _analyticsGraduatesYear = year;
      _analyticsGraduatesProgramName =
          programName?.trim().isEmpty == true ? null : programName?.trim();
      _analyticsGraduatesProgramCode =
          programCode?.trim().isEmpty == true ? null : programCode?.trim();
    });
  }

  void _backFromAnalyticsGraduates() {
    setState(() {
      final hasProgramScope =
          (_analyticsGraduatesProgramName?.trim().isNotEmpty ?? false) ||
              (_analyticsGraduatesProgramCode?.trim().isNotEmpty ?? false);
      if (hasProgramScope) {
        _analyticsGraduatesProgramName = null;
        _analyticsGraduatesProgramCode = null;
        return;
      }
      _analyticsGraduatesYear = null;
    });
  }

  void _onAnalyticsBreadcrumbTap(int index) {
    if (index == 0) {
      _openDataAnalytics();
      return;
    }
    if (index == 1) {
      setState(() {
        _analyticsGraduatesProgramName = null;
        _analyticsGraduatesProgramCode = null;
      });
    }
  }

  List<_AnalyticsGraduate> _allAnalyticsGraduates() {
    final list = _students
        .map(
          (student) => _AnalyticsGraduate(
            studentNo: student.studentNo,
            fullName: student.fullName,
            course: student.course,
            programLabel: _programChartLabel(student.course),
            schoolYear: _schoolYearForStudent(student),
            college: _collegeNameForCourse(student.course) ?? '',
          ),
        )
        .toList()
      ..sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );
    return list;
  }

  void _openAnalyticsGraduate(_AnalyticsGraduate graduate) {
    final year = graduate.schoolYear.trim().isNotEmpty
        ? graduate.schoolYear
        : _schoolYearFromStudentNo(graduate.studentNo);
    if (year.isEmpty) {
      _viewAnalyticsGraduates(
        _currentSchoolYear(),
        programName: graduate.course,
        programCode: graduate.programLabel,
      );
      return;
    }
    _viewAnalyticsGraduates(
      year,
      programName: graduate.course,
      programCode: graduate.programLabel,
    );
  }

  void _goToDashboard() {
    setState(() {
      _selectedNavId = 'dashboard';
      _expandSectionForNavId('dashboard');
    });
    _scheduleDashboardAnalyticsReveal();
  }

  bool _contentFillsViewport(String navId) {
    switch (navId) {
      case 'colleges':
      case 'courses':
      case 'students':
      case 'documents':
      case 'archived_documents':
      case 'settings':
      case 'settings_colleges':
      case 'users':
      case 'activity_log':
      case 'disposable_records':
      case 'backup_restore':
        return true;
      default:
        return false;
    }
  }

  void _rebuildAggregateCounts() {
    final studentCounts = <String, int>{};
    for (final student in _students) {
      final course = student.course.trim();
      if (course.isEmpty) continue;
      studentCounts[course] = (studentCounts[course] ?? 0) + 1;
    }
    final courseCounts = <int, int>{};
    for (final course in _courses) {
      final collegeId = course.collegeId;
      if (collegeId == null) continue;
      courseCounts[collegeId] = (courseCounts[collegeId] ?? 0) + 1;
    }
    _studentCountByCourseName = studentCounts;
    _courseCountByCollegeId = courseCounts;
  }

  void _openDocuments({String? studentFilter}) {
    setState(() {
      _documentsStudentFilter = studentFilter;
      _selectedNavId = 'documents';
    });
    _expandSectionForNavId('documents');
    _loadDocuments(showLoading: _docs.isEmpty);
  }

  void _openDocumentsForStudent(String student) {
    final name = student.trim();
    if (name.isEmpty) return;
    _openDocuments(studentFilter: name);
  }

  Future<void> _loadAuditLogs() async {
    if (mounted) {
      setState(() => _isLoadingAudit = true);
    }
    try {
      final results = await _database.fetchAuditLogs(limit: 100);
      final rows = results.map((row) {
        final created = (row['created_at'] ?? '').toString();
        final datePart = created.contains('T')
            ? created.split('T').first
            : created.split(' ').first;
        return _AuditRow(
          actor: row['actor'],
          action: row['action'],
          resourceType: row['resource_type'],
          resourceId: row['resource_id'],
          details: row['details'],
          date: datePart,
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _audit
          ..clear()
          ..addAll(rows);
        _isLoadingAudit = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingAudit = false);
    }
  }

  Future<void> _loadDocuments({bool showLoading = true}) async {
    return _queryDocuments(showLoading: showLoading);
  }

  Future<void> _queryDocuments({
    String search = '',
    String schoolYear = '',
    String college = '',
    String program = '',
    String documentType = '',
    bool showLoading = true,
  }) async {
    if (mounted && showLoading) {
      setState(() {
        _isLoadingDocs = true;
        _docsLoadError = null;
      });
    }
    try {
      _documentSearch = search;
      _documentSchoolYear = schoolYear;
      _documentCollege = college;
      _documentProgram = program;
      _documentType = documentType;
      final hasFilters = search.trim().isNotEmpty ||
          schoolYear.trim().isNotEmpty ||
          college.trim().isNotEmpty ||
          program.trim().isNotEmpty ||
          documentType.trim().isNotEmpty;
      final responses = await Future.wait([
        _database.fetchDocumentPage(
          limit: 100,
          includeTotal: hasFilters,
          search: search,
          schoolYear: schoolYear,
          college: college,
          program: program,
          documentType: documentType,
        ),
        _database.fetchDocumentSummary(),
      ]);
      final page = responses[0];
      final results = (page['items'] as List).cast<Map<String, Object?>>();
      final rows = results.map(_docRowFromMap).toList();

      if (!mounted) return;
      _docs
        ..clear()
        ..addAll(rows);
      _isLoadingDocs = false;
      _docsHasMore = page['has_more'] == true;
      _docsNextBeforeId = page['next_before_id'] as int?;
      final missingCount = responses[1]['students_without_documents'];
      final archiveCount = responses[1]['document_count'];
      _archiveDocumentTotalCount =
          archiveCount is num ? archiveCount.toInt() : rows.length;
      _studentsWithoutDocumentsTotal =
          missingCount is num ? missingCount.toInt() : 0;
      final pageTotal = page['total'];
      _documentTotalCount = pageTotal is num
          ? pageTotal.toInt()
          : (_archiveDocumentTotalCount > 0
              ? _archiveDocumentTotalCount
              : rows.length);
      _docsLoadError = null;
      _markDashboardDataDirty();
      _refreshDashboardPrepared();
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingDocs = false;
        _docsLoadError = 'Could not load documents from the local database.';
      });
    }
  }

  Future<void> _loadMoreDocuments() async {
    if (_isLoadingDocs || !_docsHasMore || _docsNextBeforeId == null) return;
    setState(() => _isLoadingDocs = true);
    try {
      final page = await _database.fetchDocumentPage(
        limit: 100,
        beforeId: _docsNextBeforeId,
        includeTotal: false,
        search: _documentSearch,
        schoolYear: _documentSchoolYear,
        college: _documentCollege,
        program: _documentProgram,
        documentType: _documentType,
      );
      final items = (page['items'] as List).cast<Map<String, Object?>>();
      if (!mounted) return;
      _docs.addAll(items.map(_docRowFromMap));
      _docsHasMore = page['has_more'] == true;
      _docsNextBeforeId = page['next_before_id'] as int?;
      final pageTotal = page['total'];
      if (pageTotal is num) _documentTotalCount = pageTotal.toInt();
      _isLoadingDocs = false;
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingDocs = false;
        _docsLoadError = 'Could not load more documents.';
      });
    }
  }

  Future<void> _loadDeletedDocuments({bool showLoading = true}) async {
    if (mounted && showLoading) {
      setState(() {
        _isLoadingDeletedDocs = true;
        _deletedDocsLoadError = null;
      });
    }
    try {
      final results = await Future.wait([
        _database.fetchDeletedDocuments(),
        _database.fetchDeletedStudents(),
        _database.fetchDeletedColleges(),
      ]);
      final rows = results[0].map(_docRowFromMap).toList();
      final students = results[1].map(_studentRowFromMap).toList();
      final colleges = results[2].map(_collegeRowFromMap).toList();

      if (!mounted) return;
      _deletedDocs
        ..clear()
        ..addAll(rows);
      _deletedStudents
        ..clear()
        ..addAll(students);
      _deletedColleges
        ..clear()
        ..addAll(colleges);
      _isLoadingDeletedDocs = false;
      _deletedDocsLoadError = null;
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingDeletedDocs = false;
        _deletedDocsLoadError = 'Could not load items in Trash.';
      });
    }
  }

  Future<void> _loadColleges({bool showLoading = true}) async {
    if (mounted && showLoading) {
      setState(() {
        _isLoadingColleges = true;
        _collegesLoadError = null;
      });
    }
    try {
      final results = await _database.fetchColleges();
      final rows = results.map(_collegeRowFromMap).toList();

      if (!mounted) return;
      setState(() {
        _colleges
          ..clear()
          ..addAll(rows);
        _isLoadingColleges = false;
        _collegesLoadError = null;
        _rebuildAggregateCounts();
        _markDashboardDataDirty();
        _refreshDashboardPrepared();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingColleges = false;
        _collegesLoadError = 'Could not load colleges from the local database.';
      });
    }
  }

  Future<String?> _addCollege({required String name}) async {
    try {
      final row = await _database.insertCollege(name: name);
      final created = _collegeRowFromMap(row);
      if (mounted) {
        setState(() {
          _colleges.add(created);
          _colleges.sort((a, b) => a.name.compareTo(b.name));
        });
      }
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Bad state: ', '');
    }
  }

  Future<String?> _updateCollege({
    required _CollegeRow college,
    required String name,
  }) async {
    if (college.id == null) return 'College id is missing.';
    try {
      final row = await _database.updateCollege(
        id: college.id!,
        name: name,
      );
      final updated = _collegeRowFromMap(row);
      if (mounted) {
        setState(() {
          final index = _colleges.indexWhere((c) => c.id == college.id);
          if (index >= 0) {
            _colleges[index] = updated;
            _colleges.sort((a, b) => a.name.compareTo(b.name));
          }
          _rebuildAggregateCounts();
          _markDashboardDataDirty();
          _refreshDashboardPrepared();
        });
        await _loadDocuments(showLoading: false);
      }
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Bad state: ', '');
    }
  }

  Future<String?> _deleteCollege(_CollegeRow college) async {
    if (college.id == null) return 'College id is missing.';
    try {
      final ok = await _database.deleteCollege(college.id!);
      if (!ok) {
        await _loadColleges();
        return 'College not found.';
      }
      if (mounted) {
        setState(() {
          _colleges.removeWhere((c) => c.id == college.id);
          _courses.removeWhere((c) => c.collegeId == college.id);
        });
        await _loadDeletedDocuments(showLoading: false);
      }
      return null;
    } catch (e) {
      await _loadColleges();
      await _loadCourses(showLoading: false);
      return e.toString().replaceFirst('Bad state: ', '');
    }
  }

  _CollegeRow _collegeRowFromMap(Map<String, Object?> item) {
    return _CollegeRow(
      id: int.tryParse('${item['id'] ?? ''}'),
      name: (item['name'] ?? '').toString(),
    );
  }

  Future<void> _loadCourses({bool showLoading = true}) async {
    if (mounted && showLoading) {
      setState(() {
        _isLoadingCourses = true;
        _coursesLoadError = null;
      });
    }
    try {
      final results = await _database.fetchCourses();
      final rows = results.map(_courseRowFromMap).toList();

      if (!mounted) return;
      setState(() {
        _courses
          ..clear()
          ..addAll(rows);
        _isLoadingCourses = false;
        _coursesLoadError = null;
        _rebuildAggregateCounts();
        _markDashboardDataDirty();
        _refreshDashboardPrepared();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingCourses = false;
        _coursesLoadError = 'Could not load programs from the local database.';
      });
    }
  }

  Future<String?> _addCourse({
    required String name,
    required int collegeId,
  }) async {
    try {
      final row = await _database.insertCourse(
        name: name,
        collegeId: collegeId,
      );
      final created = _courseRowFromMap(row);
      if (mounted) {
        setState(() {
          _courses.add(created);
          _courses.sort((a, b) => a.name.compareTo(b.name));
          _rebuildAggregateCounts();
        });
      }
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Bad state: ', '');
    }
  }

  Future<String?> _updateCourse({
    required _CourseRow course,
    required String name,
    required int collegeId,
  }) async {
    if (course.id == null) return 'Program id is missing.';
    try {
      final row = await _database.updateCourse(
        id: course.id!,
        name: name,
        collegeId: collegeId,
      );
      final updated = _courseRowFromMap(row);
      if (mounted) {
        setState(() {
          final index = _courses.indexWhere((c) => c.id == course.id);
          if (index >= 0) {
            _courses[index] = updated;
            _courses.sort((a, b) => a.name.compareTo(b.name));
          }
          _rebuildAggregateCounts();
        });
      }
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Bad state: ', '');
    }
  }

  Future<String?> _deleteCourse(_CourseRow course) async {
    if (course.id == null) return 'Program id is missing.';
    try {
      final ok = await _database.deleteCourse(course.id!);
      if (!ok) {
        await _loadCourses();
        return 'Program not found.';
      }
      if (mounted) {
        setState(() {
          _courses.removeWhere((c) => c.id == course.id);
          _rebuildAggregateCounts();
        });
      }
      return null;
    } catch (e) {
      await _loadCourses();
      return e.toString().replaceFirst('Bad state: ', '');
    }
  }

  _CourseRow _courseRowFromMap(Map<String, Object?> item) {
    final code = (item['code'] ?? '').toString().trim();
    return _CourseRow(
      id: int.tryParse('${item['id'] ?? ''}'),
      name: (item['name'] ?? '').toString(),
      collegeId: int.tryParse('${item['college_id'] ?? ''}'),
      code: code.isEmpty ? null : code,
    );
  }

  Future<void> _loadStudents({bool showLoading = true}) async {
    if (mounted && showLoading) {
      setState(() {
        _isLoadingStudents = true;
        _studentsLoadError = null;
      });
    }
    try {
      final results = await _database.fetchStudents();
      final rows = results.map(_studentRowFromMap).toList();

      if (!mounted) return;
      _students
        ..clear()
        ..addAll(rows);
      _isLoadingStudents = false;
      _studentsLoadError = null;
      _rebuildAggregateCounts();
      _markDashboardDataDirty();
      _refreshDashboardPrepared();
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingStudents = false;
        _studentsLoadError = 'Could not load students from the local database.';
      });
    }
  }

  Future<void> _loadDashboardPriorityData() async {
    if (mounted) {
      setState(() {
        _isLoadingStudents = true;
        _isLoadingDocs = true;
        _isLoadingCourses = true;
        _studentsLoadError = null;
        _docsLoadError = null;
        _coursesLoadError = null;
      });
    }

    List<_StudentRow>? students;
    List<_DocRow>? docs;
    List<_CourseRow>? courses;
    String? studentsLoadError;
    String? docsLoadError;
    String? coursesLoadError;

    await Future.wait<void>([
      _database.fetchStudents().then((results) {
        students = results.map(_studentRowFromMap).toList();
      }).catchError((_) {
        studentsLoadError = 'Could not load students from the local database.';
      }),
      _database.fetchDocumentPage(limit: 100, includeTotal: false).then((page) {
        final results = (page['items'] as List).cast<Map<String, Object?>>();
        docs = results.map(_docRowFromMap).toList();
        _docsHasMore = page['has_more'] == true;
        _docsNextBeforeId = page['next_before_id'] as int?;
        final total = page['total'];
        if (total is num) _documentTotalCount = total.toInt();
      }).catchError((_) {
        docsLoadError = 'Could not load documents from the local database.';
      }),
      _database.fetchDocumentSummary().then((summary) {
        final count = summary['document_count'];
        _documentTotalCount = count is num ? count.toInt() : 0;
        _archiveDocumentTotalCount = _documentTotalCount;
        final missing = summary['students_without_documents'];
        _studentsWithoutDocumentsTotal = missing is num ? missing.toInt() : 0;
      }).catchError((_) {}),
      _database.fetchCourses().then((results) {
        courses = results.map(_courseRowFromMap).toList();
      }).catchError((_) {
        coursesLoadError = 'Could not load programs from the local database.';
      }),
    ]);

    if (!mounted) return;

    if (students != null) {
      _students
        ..clear()
        ..addAll(students!);
    }
    if (docs != null) {
      _docs
        ..clear()
        ..addAll(docs!);
    }
    if (courses != null) {
      _courses
        ..clear()
        ..addAll(courses!);
    }
    _studentsLoadError = studentsLoadError;
    _docsLoadError = docsLoadError;
    _coursesLoadError = coursesLoadError;
    _isLoadingStudents = false;
    _isLoadingDocs = false;
    _isLoadingCourses = false;
    _rebuildAggregateCounts();
    _markDashboardDataDirty(resetAnalytics: true);
    _refreshDashboardPrepared();
    _dashboardPriorityReady = true;
    _syncDashboardShellReady();

    setState(() {});
    _scheduleDashboardAnalyticsReveal();
    Future.microtask(_ensureFullAnalytics);
  }

  Future<void> _loadSecondaryShellData() async {
    List<_CollegeRow>? colleges;
    String? collegesLoadError;

    await _database.fetchColleges().then((results) {
      colleges = results.map(_collegeRowFromMap).toList();
    }).catchError((_) {
      collegesLoadError = 'Could not load colleges from the local database.';
    });

    if (!mounted) return;

    if (colleges != null) {
      _colleges
        ..clear()
        ..addAll(colleges!);
    }
    _collegesLoadError = collegesLoadError;
    _isLoadingColleges = false;
    _markDashboardDataDirty();
    _refreshDashboardPrepared();
    _dashboardSecondaryReady = true;
    _syncDashboardShellReady();

    setState(() {});
  }

  void _scheduleDashboardAnalyticsReveal() {
    if (!_isAdmin || _dashboardAnalyticsReady) return;
    if (!_dashboardShellDataReady) return;
    setState(() {
      _dashboardAnalyticsReady = true;
      _refreshDashboardPrepared(withAnalytics: true);
    });
  }

  Future<bool> _deleteDocument(_DocRow doc) async {
    if (doc.id.trim().isEmpty) {
      return true;
    }

    final docId = int.tryParse(doc.id.trim());
    if (docId == null) {
      return false;
    }

    if (mounted) {
      setState(() {
        _docs.removeWhere((d) => _isSameDocument(d, doc));
        _markDashboardDataDirty();
        _refreshDashboardPrepared();
      });
    }

    try {
      final ok = await _database.deleteDocument(docId);
      if (!ok) {
        await _loadDocuments();
      } else {
        _archiveDocumentTotalCount =
            (_archiveDocumentTotalCount - 1).clamp(0, 1 << 31);
        _documentTotalCount = (_documentTotalCount - 1).clamp(0, 1 << 31);
        await _loadDeletedDocuments(showLoading: false);
      }
      return ok;
    } catch (_) {
      await _loadDocuments();
      return false;
    }
  }

  Future<int> _deleteDocuments(List<_DocRow> docs) async {
    var deletedCount = 0;
    for (final doc in docs) {
      final ok = await _deleteDocument(doc);
      if (ok) deletedCount++;
    }
    return deletedCount;
  }

  Future<bool> _purgeDeletedDocument(_DocRow doc) async {
    if (doc.id.trim().isEmpty) {
      return false;
    }

    final docId = int.tryParse(doc.id.trim());
    if (docId == null) {
      return false;
    }

    if (mounted) {
      setState(() {
        _deletedDocs.removeWhere((d) => _isSameDocument(d, doc));
      });
    }

    try {
      final ok = await _database.purgeDocument(docId);
      if (!ok) {
        await _loadDeletedDocuments();
      }
      return ok;
    } catch (_) {
      await _loadDeletedDocuments();
      return false;
    }
  }

  Future<bool> _restoreTrashDocument(_DocRow doc) async {
    final docId = int.tryParse(doc.id.trim());
    if (docId == null) return false;

    try {
      final ok = await _database.restoreDocument(docId);
      if (!ok) return false;
      if (mounted) {
        setState(() {
          _deletedDocs.removeWhere((d) => _isSameDocument(d, doc));
          _markDashboardDataDirty();
          _refreshDashboardPrepared();
        });
      }
      await _loadDocuments(showLoading: false);
      return true;
    } catch (_) {
      await _loadDeletedDocuments(showLoading: false);
      return false;
    }
  }

  Future<int> _purgeDeletedDocuments(List<_DocRow> docs) async {
    var deletedCount = 0;
    for (final doc in docs) {
      final ok = await _purgeDeletedDocument(doc);
      if (ok) deletedCount++;
    }
    return deletedCount;
  }

  Future<bool> _restoreTrashStudent(_StudentRow student) async {
    if (student.id == null) return false;
    try {
      final ok = await _database.restoreStudent(student.id!);
      if (!ok) return false;
      await Future.wait([
        _loadStudents(showLoading: false),
        _loadDocuments(showLoading: false),
        _loadDeletedDocuments(showLoading: false),
      ]);
      return true;
    } catch (_) {
      await _loadDeletedDocuments(showLoading: false);
      return false;
    }
  }

  Future<String?> _purgeTrashStudent(_StudentRow student) async {
    if (student.id == null) return 'Student id is missing.';
    try {
      final ok = await _database.purgeStudent(student.id!);
      await _loadDeletedDocuments(showLoading: false);
      return ok ? null : 'Student was not found in Trash.';
    } catch (e) {
      await _loadDeletedDocuments(showLoading: false);
      return e.toString().replaceFirst('Bad state: ', '');
    }
  }

  Future<bool> _restoreTrashCollege(_CollegeRow college) async {
    if (college.id == null) return false;
    try {
      final ok = await _database.restoreCollege(college.id!);
      if (!ok) return false;
      await Future.wait([
        _loadColleges(showLoading: false),
        _loadCourses(showLoading: false),
        _loadDeletedDocuments(showLoading: false),
      ]);
      return true;
    } catch (_) {
      await _loadDeletedDocuments(showLoading: false);
      return false;
    }
  }

  Future<String?> _purgeTrashCollege(_CollegeRow college) async {
    if (college.id == null) return 'College id is missing.';
    try {
      final ok = await _database.purgeCollege(college.id!);
      await _loadDeletedDocuments(showLoading: false);
      return ok ? null : 'College was not found in Trash.';
    } catch (e) {
      await _loadDeletedDocuments(showLoading: false);
      return e.toString().replaceFirst('Bad state: ', '');
    }
  }

  String? _programCodeForCourse(String courseName) {
    final name = courseName.trim();
    if (name.isEmpty) return null;
    for (final course in _courses) {
      if (course.name == name) {
        final code = course.code?.trim() ?? '';
        return code.isEmpty ? null : code;
      }
    }
    return null;
  }

  String _programChartLabel(String courseName) {
    final name = courseName.trim();
    if (name.isEmpty) return 'N/A';
    return StudentNumber.resolveProgramCode(
      programName: name,
      courseCode: _programCodeForCourse(name),
    );
  }

  String? _collegeNameForCourse(String courseName) {
    final name = courseName.trim();
    if (name.isEmpty) return null;
    for (final course in _courses) {
      if (course.name != name) continue;
      final collegeId = course.collegeId;
      if (collegeId == null) return null;
      for (final college in _colleges) {
        if (college.id == collegeId) return college.name;
      }
      return null;
    }
    return null;
  }

  Future<bool> _uploadStudentDocument({
    required String title,
    required String student,
    required String sourceImagePath,
    required String mimeType,
    String studentNo = '',
    String course = '',
    String schoolYear = '',
    String documentType = '',
    bool isComplete = true,
    String college = '',
    String studentCategory = 'Graduated',
    String tags = '',
    String storagePath = '',
  }) async {
    try {
      final program = _programCodeForCourse(course) ?? course;
      final resolvedCollege = college.trim().isNotEmpty
          ? college.trim()
          : (_collegeNameForCourse(course) ?? '');
      final row = await _database.insertDocument(
        title: title,
        student: student,
        sourceImagePath: sourceImagePath,
        mimeType: mimeType,
        studentNo: studentNo,
        course: course,
        program: program,
        schoolYear: schoolYear,
        documentType: documentType,
        isComplete: isComplete,
        college: resolvedCollege,
        studentCategory: studentCategory,
        tags: tags,
        storagePath: storagePath,
      );
      final doc = _docRowFromMap(row);
      if (mounted) {
        setState(() {
          _docs.insert(0, doc);
          _archiveDocumentTotalCount++;
          _documentTotalCount++;
          _documentsStudentFilter = null;
          _markDashboardDataDirty();
        });
      }
      return true;
    } catch (error, stackTrace) {
      debugPrint('Document upload failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<_DocRow?> _updateDocumentMetadata({
    required _DocRow document,
    required String title,
    required String documentType,
    required String schoolYear,
    required String program,
    required String studentNo,
    required String storagePath,
    required String college,
    required String tags,
  }) async {
    final id = int.tryParse(document.id.trim());
    if (id == null) return null;
    try {
      final row = await _database.updateDocumentMetadata(
        id: id,
        title: title,
        documentType: documentType,
        schoolYear: schoolYear,
        program: program,
        studentNo: studentNo,
        storagePath: storagePath,
        college: college,
        tags: tags,
      );
      final updated = _docRowFromMap(row);
      if (mounted) {
        setState(() {
          final index =
              _docs.indexWhere((doc) => _isSameDocument(doc, document));
          if (index == -1) {
            _docs.insert(0, updated);
          } else {
            _docs[index] = updated;
          }
          _markDashboardDataDirty();
          _refreshDashboardPrepared();
        });
      }
      return updated;
    } catch (_) {
      await _loadDocuments(showLoading: false);
      return null;
    }
  }

  Future<_StudentRow?> _registerStudent({
    required String studentNo,
    required String fullName,
    required String course,
    required int year,
    required String status,
    String? email,
    String sex = '',
    String birthDate = '',
    String phoneNumber = '',
    String notes = '',
    String schoolYear = '',
    String graduationDate = '',
    String lastEnrollmentDate = '',
  }) async {
    try {
      final row = await _database.insertStudent(
        studentNo: studentNo.trim(),
        fullName: fullName,
        course: course,
        year: year,
        status: 'graduated',
        schoolYear: schoolYear,
        email: email ?? '',
        sex: sex,
        birthDate: birthDate,
        phoneNumber: phoneNumber,
        notes: notes,
        graduationDate: graduationDate,
        lastEnrollmentDate: lastEnrollmentDate,
        retentionBasis: graduationDate.trim().isNotEmpty
            ? 'graduation_date'
            : 'last_enrollment_date',
      );
      final created = _studentRowFromMap(row);
      if (mounted) {
        setState(() {
          _students.add(created);
          _rebuildAggregateCounts();
        });
      }
      return created;
    } catch (_) {
      return null;
    }
  }

  Future<_StudentRow?> _updateStudent({
    required _StudentRow student,
    required String studentNo,
    required String fullName,
    required String course,
    required int year,
    required String status,
    String? email,
    String sex = '',
    String birthDate = '',
    String phoneNumber = '',
    String notes = '',
    String schoolYear = '',
    String graduationDate = '',
    String lastEnrollmentDate = '',
  }) async {
    final id = student.id;
    if (id == null) return null;

    try {
      final row = await _database.updateStudent(
        id: id,
        studentNo: studentNo.trim(),
        fullName: fullName,
        course: course,
        year: year,
        status: status.trim().isEmpty ? 'graduated' : status,
        schoolYear: schoolYear,
        email: email ?? '',
        sex: sex,
        birthDate: birthDate,
        phoneNumber: phoneNumber,
        notes: notes,
        graduationDate: graduationDate,
        lastEnrollmentDate: lastEnrollmentDate,
        retentionBasis: graduationDate.trim().isNotEmpty
            ? 'graduation_date'
            : 'last_enrollment_date',
      );
      if (row == null) return null;
      final updated = _studentRowFromMap(row);
      if (mounted) {
        setState(() {
          final index = _students.indexWhere((s) => s.id == id);
          if (index == -1) {
            _students.add(updated);
          } else {
            _students[index] = updated;
          }

          final oldName = student.fullName.trim().toLowerCase();
          final oldNo = student.studentNo.trim().toLowerCase();
          for (var i = 0; i < _docs.length; i++) {
            final doc = _docs[i];
            final docStudent = doc.student.trim().toLowerCase();
            final docNo = doc.studentNo.trim().toLowerCase();
            final matchesById = oldNo.isNotEmpty && docNo == oldNo;
            final matchesUnassignedByName =
                docNo.isEmpty && oldName.isNotEmpty && docStudent == oldName;
            if (matchesById || matchesUnassignedByName) {
              _docs[i] = _DocRow(
                id: doc.id,
                title: doc.title,
                student: updated.fullName,
                type: doc.type,
                size: doc.size,
                uploaded: doc.uploaded,
                schoolYear: updated.schoolYear,
                studentNo: updated.studentNo,
                program: doc.program,
                college: doc.college,
                documentType: doc.documentType,
                storagePath: doc.storagePath,
                tags: doc.tags,
                uploader: doc.uploader,
                localFilePath: doc.localFilePath,
                localImagePath: doc.localImagePath,
                remoteImageUrl: doc.remoteImageUrl,
              );
            }
          }

          _rebuildAggregateCounts();
          _markDashboardDataDirty(resetAnalytics: true);
          _refreshDashboardPrepared();
        });
      }
      return updated;
    } catch (error) {
      await _loadStudents();
      await _loadDocuments(showLoading: false);
      throw StateError(
        error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  _StudentRow _studentRowFromMap(Map<String, Object?> item) {
    final email = _cleanTextValue(item['email']);
    return _StudentRow(
      id: int.tryParse('${item['id'] ?? ''}'),
      studentNo: _cleanTextValue(item['student_no']),
      fullName: _cleanTextValue(item['full_name']),
      course: _cleanTextValue(item['course']),
      year: int.tryParse('${item['year'] ?? 0}') ?? 0,
      status: _cleanTextValue(item['status']).isEmpty
          ? 'graduated'
          : _cleanTextValue(item['status']),
      email: email.isEmpty ? null : email,
      schoolYear: _cleanTextValue(item['school_year']),
      sex: _cleanTextValue(item['sex']),
      birthDate: _cleanTextValue(item['birth_date']),
      phoneNumber: _cleanTextValue(item['phone_number']),
      notes: _cleanTextValue(item['notes']),
      graduationDate: _cleanTextValue(item['graduation_date']),
      lastEnrollmentDate: _cleanTextValue(item['last_enrollment_date']),
    );
  }

  Future<String?> _deleteStudent(_StudentRow student) async {
    if (student.id == null) return 'Student id is missing.';
    try {
      final ok = await _database.deleteStudent(student.id!);
      if (!ok) {
        await _loadStudents();
        return 'Student not found.';
      }
      if (mounted) {
        final name = student.fullName.trim().toLowerCase();
        setState(() {
          _students.removeWhere((s) => s.id == student.id);
          if (name.isNotEmpty) {
            _docs.removeWhere(
              (doc) => doc.student.trim().toLowerCase() == name,
            );
          }
          _rebuildAggregateCounts();
        });
        await _loadDeletedDocuments(showLoading: false);
      }
      return null;
    } catch (e) {
      await _loadStudents();
      await _loadDocuments(showLoading: false);
      return e.toString().replaceFirst('Bad state: ', '');
    }
  }

  _DocRow _docRowFromMap(Map<String, Object?> item) {
    final imagePath = (item['image_path'] ?? '').toString().trim();
    final remoteUrl = _documentImageUrl(imagePath);
    final localPath =
        remoteUrl.isEmpty && imagePath.isNotEmpty ? imagePath : null;
    return _DocRow(
      id: (item['id'] ?? '').toString(),
      title: (item['title'] ?? 'Untitled Document').toString(),
      student: (item['student'] ?? '').toString(),
      type: (item['mime_type'] ?? 'image').toString(),
      size: _formatBytesFromApi(item['size_bytes']),
      uploaded: _formatDateFromIso((item['created_at'] ?? '').toString()),
      schoolYear: (item['school_year'] ?? '').toString().trim(),
      studentNo: (item['student_no'] ?? '').toString().trim(),
      program: (item['program'] ?? '').toString().trim(),
      college: (item['college'] ?? '').toString().trim(),
      documentType: (item['document_type'] ?? '').toString().trim(),
      storagePath: (item['storage_path'] ?? '').toString().trim(),
      tags: (item['tags'] ?? '').toString().trim(),
      uploader: (item['uploader'] ?? '').toString().trim(),
      deletedAt: _formatDateFromIso((item['deleted_at'] ?? '').toString()),
      deletedBy: (item['deleted_by'] ?? '').toString().trim(),
      localFilePath: localPath,
      localImagePath: localPath,
      remoteImageUrl: remoteUrl,
    );
  }

  /// Resolves remote image paths. Standalone documents use local file paths.
  String _documentImageUrl(String imagePath) {
    if (imagePath.isEmpty) return '';
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    return '';
  }

  bool _isSameDocument(_DocRow a, _DocRow b) {
    final aId = a.id.trim();
    final bId = b.id.trim();
    if (aId.isNotEmpty && bId.isNotEmpty) {
      return aId == bId;
    }
    return a.title == b.title &&
        a.student == b.student &&
        a.uploaded == b.uploaded &&
        a.type == b.type &&
        a.size == b.size;
  }

  String _formatDateFromIso(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value;
    }
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    final year = parsed.year.toString();
    return '$month/$day/$year';
  }

  String _formatBytesFromApi(dynamic value) {
    final bytes = int.tryParse('${value ?? 0}') ?? 0;
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _invalidateFullAnalytics() {
    _cachedFullAnalytics = null;
    _fullAnalyticsCacheGeneration = -1;
    _fullAnalyticsLoading = false;
    _graduatesByYearCache.clear();
    _courseCountsByYearCache.clear();
  }

  void _ensureFullAnalytics() {
    if (_cachedFullAnalytics != null &&
        _fullAnalyticsCacheGeneration == _dashboardDataGeneration) {
      return;
    }
    if (_fullAnalyticsLoading) return;
    _fullAnalyticsLoading = true;

    Future<void>.microtask(() {
      final data = _buildAnalyticsDataFast();
      if (!mounted) return;
      _cachedFullAnalytics = data;
      _fullAnalyticsCacheGeneration = _dashboardDataGeneration;
      _fullAnalyticsLoading = false;
      if (_selectedNavId == 'data_analytics') {
        setState(() {});
      }
    });
  }

  _AnalyticsData _buildAnalyticsDataFast() {
    final byCourse = <String, int>{};
    final studentsByYear = <String, int>{};
    final docsPerYear = <String, int>{};
    final years = <String>{};

    for (final student in _students) {
      final course =
          student.course.trim().isEmpty ? 'N/A' : student.course.trim();
      byCourse.update(course, (count) => count + 1, ifAbsent: () => 1);

      final year = _schoolYearForStudent(student);
      if (year.isEmpty) continue;
      years.add(year);
      studentsByYear.update(year, (count) => count + 1, ifAbsent: () => 1);
    }
    for (final doc in _docs) {
      final year = _schoolYearForDocument(doc, students: _students);
      if (year.isEmpty) continue;
      years.add(year);
      docsPerYear.update(year, (count) => count + 1, ifAbsent: () => 1);
    }
    years.add(_currentSchoolYear());

    final byCourseEntries = byCourse.entries
        .map(
          (entry) => _CourseCount(
            name: entry.key,
            code: _programChartLabel(entry.key),
            count: entry.value,
          ),
        )
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final availableYears = years.toList()
      ..sort((a, b) {
        final aStart = int.tryParse(a.split('-').first) ?? 0;
        final bStart = int.tryParse(b.split('-').first) ?? 0;
        return bStart.compareTo(aStart);
      });

    final bySchoolYear = availableYears
        .map(
          (year) => _YearCount(
            year: year,
            students: studentsByYear[year] ?? 0,
            documents: docsPerYear[year] ?? 0,
          ),
        )
        .toList();

    final byCourseByYear = <String, List<_CourseCount>>{
      for (final year in availableYears) year: _courseCountsInSchoolYear(year),
    };

    return _AnalyticsData(
      students: _students.length,
      courses: _courses.length,
      documents: _docs.length,
      byCourse: byCourseEntries,
      bySchoolYear: bySchoolYear,
      availableYears: availableYears,
      byCourseByYear: byCourseByYear,
      graduatesByYear: const {},
    );
  }

  List<_CourseCount> _courseCountsInSchoolYear(String year) {
    final counts = <String, int>{};
    final names = <String, String>{};

    for (final student in _students) {
      if (_schoolYearForStudent(student) != year) continue;
      final courseName =
          student.course.trim().isEmpty ? 'N/A' : student.course.trim();
      final code = _programCodeFromStudentNo(student.studentNo);
      final key = code.isNotEmpty ? code : _programChartLabel(courseName);
      counts.update(key, (count) => count + 1, ifAbsent: () => 1);
      final existing = names[key];
      if (existing == null || courseName.length > existing.length) {
        names[key] = courseName;
      }
    }

    return counts.entries
        .map(
          (entry) => _CourseCount(
            name: names[entry.key] ?? entry.key,
            code: entry.key,
            count: entry.value,
          ),
        )
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
  }

  List<_AnalyticsGraduate> _graduatesForYear(
    String year, {
    String? programName,
    String? programCode,
  }) {
    final all = _graduatesByYearCache.putIfAbsent(year, () {
      final rows =
          _students.where((s) => _schoolYearForStudent(s) == year).toList()
            ..sort(
              (a, b) =>
                  a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
            );
      return rows
          .map(
            (student) => _AnalyticsGraduate(
              studentNo: student.studentNo,
              fullName: student.fullName,
              course: student.course,
              programLabel: _programChartLabel(student.course),
              schoolYear: _schoolYearForStudent(student),
              college: _collegeNameForCourse(student.course) ?? '',
            ),
          )
          .toList();
    });

    final nameFilter = programName?.trim();
    final codeFilter = programCode?.trim();
    if ((nameFilter == null || nameFilter.isEmpty) &&
        (codeFilter == null || codeFilter.isEmpty)) {
      return all;
    }

    return all.where((graduate) {
      final course = graduate.course.trim();
      final label = graduate.programLabel.trim();
      if (nameFilter != null &&
          nameFilter.isNotEmpty &&
          course.toLowerCase() == nameFilter.toLowerCase()) {
        return true;
      }
      if (codeFilter != null &&
          codeFilter.isNotEmpty &&
          label.toLowerCase() == codeFilter.toLowerCase()) {
        return true;
      }
      return false;
    }).toList();
  }

  List<_CourseCount> _courseCountsForYear(String year) {
    final cached = _cachedFullAnalytics?.byCourseByYear[year];
    if (cached != null) return cached;
    return _courseCountsByYearCache.putIfAbsent(
      year,
      () => _courseCountsInSchoolYear(year),
    );
  }

  List<_DocRow> _filterDocsForDashboardSearch(List<_DocRow> docs) {
    final q = _dashboardSearchQuery.trim().toLowerCase();
    if (q.isEmpty) return docs;
    return docs
        .where(
          (doc) =>
              doc.title.toLowerCase().contains(q) ||
              doc.student.toLowerCase().contains(q) ||
              doc.type.toLowerCase().contains(q) ||
              doc.uploaded.toLowerCase().contains(q) ||
              doc.schoolYear.toLowerCase().contains(q) ||
              doc.studentNo.toLowerCase().contains(q) ||
              doc.program.toLowerCase().contains(q) ||
              doc.college.toLowerCase().contains(q) ||
              doc.documentType.toLowerCase().contains(q) ||
              doc.tags.toLowerCase().contains(q),
        )
        .toList();
  }

  List<_StudentRow> _filterStudentsForDashboardSearch(
    List<_StudentRow> students,
  ) {
    final q = _dashboardSearchQuery.trim().toLowerCase();
    if (q.isEmpty) return students;
    return students
        .where(
          (student) =>
              student.fullName.toLowerCase().contains(q) ||
              student.studentNo.toLowerCase().contains(q) ||
              student.course.toLowerCase().contains(q) ||
              student.status.toLowerCase().contains(q) ||
              (student.email ?? '').toLowerCase().contains(q) ||
              _schoolYearForStudent(student).toLowerCase().contains(q) ||
              (_collegeNameForCourse(student.course) ?? '')
                  .toLowerCase()
                  .contains(q),
        )
        .toList();
  }

  void _markDashboardDataDirty({bool resetAnalytics = false}) {
    _dashboardDataGeneration++;
    _cachedDashboardAnalytics = null;
    if (resetAnalytics) {
      _dashboardAnalyticsReady = false;
    }
    _cachedDashboardPrepared = null;
    _dashboardPreparedKey = null;
    _invalidateFullAnalytics();
  }

  void _onDashboardSearchChanged(String query) {
    _dashboardSearchDebounce?.cancel();
    _dashboardSearchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final next = query.trim();
      if (_dashboardSearchQuery == next) return;
      setState(() {
        _dashboardSearchQuery = next;
        _markDashboardDataDirty();
        _refreshDashboardPrepared();
      });
    });
  }

  void _refreshDashboardPrepared({bool withAnalytics = false}) {
    final cacheKey =
        '$_dashboardDataGeneration|${_dashboardSearchQuery.trim().toLowerCase()}|${withAnalytics || _dashboardAnalyticsReady}';
    if (_cachedDashboardPrepared != null && _dashboardPreparedKey == cacheKey) {
      return;
    }

    final filteredStudents = _filterStudentsForDashboardSearch(_students);
    final filteredDocs = _filterDocsForDashboardSearch(_docs);
    final includeAnalytics =
        withAnalytics || (_dashboardAnalyticsReady && _isAdmin);
    if (includeAnalytics && _cachedDashboardAnalytics == null) {
      _cachedDashboardAnalytics = _buildDashboardAnalyticsPreview(
        students: filteredStudents,
        docs: filteredDocs,
      );
    }

    _cachedDashboardPrepared = _DashboardPrepared(
      studentsCount: filteredStudents.length,
      documentsCount: _dashboardSearchQuery.trim().isEmpty
          ? _archiveDocumentTotalCount
          : filteredDocs.length,
      segments: _buildCoursePercentSegments(filteredStudents),
      studentsWithoutDocs: _dashboardSearchQuery.trim().isEmpty
          ? _studentsWithoutDocumentsTotal
          : _countStudentsWithoutDocs(students: filteredStudents, docs: _docs),
      filteredRecentDocs: _recentDocsForDashboard(filteredDocs),
      analytics: includeAnalytics ? _cachedDashboardAnalytics : null,
    );
    _dashboardPreparedKey = cacheKey;
  }

  List<_DocRow> _recentDocsForDashboard(List<_DocRow> docs) {
    if (docs.isEmpty) return const [];
    final copy = List<_DocRow>.from(docs);
    copy.sort((a, b) {
      final aDate = _parseUploadedDate(a.uploaded);
      final bDate = _parseUploadedDate(b.uploaded);
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return copy;
  }

  DateTime? _parseUploadedDate(String uploaded) {
    final iso = DateTime.tryParse(uploaded);
    if (iso != null) return iso;
    final parts = uploaded.split('/');
    if (parts.length == 3) {
      final month = int.tryParse(parts[0]);
      final day = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (month != null && day != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  int _countStudentsWithoutDocs({
    required List<_StudentRow> students,
    required List<_DocRow> docs,
  }) {
    if (students.isEmpty) return 0;
    final documentStudentNumbers = <String>{};
    final documentStudentNames = <String>{};
    for (final doc in docs) {
      final studentNo = doc.studentNo.trim().toLowerCase();
      final studentName = doc.student.trim().toLowerCase();
      if (studentNo.isNotEmpty) documentStudentNumbers.add(studentNo);
      if (studentName.isNotEmpty) documentStudentNames.add(studentName);
    }
    if (documentStudentNumbers.isEmpty && documentStudentNames.isEmpty) {
      return students.length;
    }

    var missing = 0;
    for (final student in students) {
      final name = student.fullName.trim().toLowerCase();
      final no = student.studentNo.trim().toLowerCase();
      final hasDoc = (no.isNotEmpty && documentStudentNumbers.contains(no)) ||
          (name.isNotEmpty && documentStudentNames.contains(name));
      if (!hasDoc) missing++;
    }
    return missing;
  }

  _AnalyticsData _buildDashboardAnalyticsPreview({
    required List<_StudentRow> students,
    required List<_DocRow> docs,
  }) {
    final byCourse = <String, int>{};
    final studentsByYear = <String, int>{};
    for (final student in students) {
      final course =
          student.course.trim().isEmpty ? 'N/A' : student.course.trim();
      byCourse.update(course, (count) => count + 1, ifAbsent: () => 1);
      final year = _schoolYearForStudent(student);
      if (year.isNotEmpty) {
        studentsByYear.update(year, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    final byCourseEntries = byCourse.entries
        .map(
          (entry) => _CourseCount(
            name: entry.key,
            code: _programChartLabel(entry.key),
            count: entry.value,
          ),
        )
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    if (byCourseEntries.length > 8) {
      byCourseEntries.removeRange(8, byCourseEntries.length);
    }

    final docsPerYear = <String, int>{};
    for (final doc in docs) {
      final year = _schoolYearForDocument(doc, students: students);
      if (year.isEmpty) continue;
      docsPerYear.update(year, (count) => count + 1, ifAbsent: () => 1);
    }

    final allYears = _collectSchoolYears(
      students: students,
      docs: docs,
    );
    final displayYears = allYears.length <= _dashboardSchoolYearsLimit
        ? allYears
        : allYears.sublist(0, _dashboardSchoolYearsLimit);
    // Oldest → newest for time-series charts (collector returns newest first).
    final chartYears = displayYears.reversed.toList();

    final bySchoolYear = chartYears
        .map(
          (year) => _YearCount(
            year: year,
            students: studentsByYear[year] ?? 0,
            documents: docsPerYear[year] ?? 0,
          ),
        )
        .toList();

    return _AnalyticsData(
      students: students.length,
      courses: _courses.length,
      documents: docs.length,
      byCourse: byCourseEntries,
      bySchoolYear: bySchoolYear,
      availableYears: allYears,
      byCourseByYear: const {},
      graduatesByYear: const {},
    );
  }

  List<_PieSeg> _buildCoursePercentSegments(List<_StudentRow> students) {
    if (students.isEmpty) return const [];
    final counts = <String, int>{};
    for (final student in students) {
      final course = student.course.trim().isEmpty ? 'N/A' : student.course;
      counts.update(course, (value) => value + 1, ifAbsent: () => 1);
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = students.length;
    final percents = _distributePercentages(
      sorted.map((e) => e.value).toList(),
      total,
    );
    const colors = _programChartColors;
    return List<_PieSeg>.generate(sorted.length, (index) {
      final item = sorted[index];
      return _PieSeg(
        _programChartLabel(item.key),
        percents[index],
        colors[index % colors.length],
        count: item.value,
      );
    });
  }
}

class _DashboardPrepared {
  const _DashboardPrepared({
    required this.studentsCount,
    required this.documentsCount,
    required this.segments,
    required this.studentsWithoutDocs,
    required this.filteredRecentDocs,
    required this.analytics,
  });

  final int studentsCount;
  final int documentsCount;
  final List<_PieSeg> segments;
  final int studentsWithoutDocs;
  final List<_DocRow> filteredRecentDocs;
  final _AnalyticsData? analytics;
}
