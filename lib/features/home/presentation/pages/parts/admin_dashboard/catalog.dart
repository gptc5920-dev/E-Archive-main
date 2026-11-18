part of '../../dashboard_shell_page.dart';

class _AdminDashStatMetric {
  const _AdminDashStatMetric({
    required this.title,
    required this.icon,
    required this.accent,
    required this.navigationId,
    required this.valueOf,
    required this.hintOf,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final String navigationId;
  final String Function(_DashboardBaseData) valueOf;
  final String Function(_DashboardBaseData) hintOf;
}

List<_AdminDashStatMetric> _adminDashStatMetrics() => const [
      _AdminDashStatMetric(
        title: 'Students',
        icon: HugeIcons.strokeRoundedUserMultiple,
        accent: Color(0xFF2563EB),
        navigationId: 'students',
        valueOf: _studentsValue,
        hintOf: _studentsHint,
      ),
      _AdminDashStatMetric(
        title: 'Documents',
        icon: HugeIcons.strokeRoundedArchive,
        accent: Color(0xFF059669),
        navigationId: 'documents',
        valueOf: _documentsValue,
        hintOf: _documentsHint,
      ),
      _AdminDashStatMetric(
        title: 'Programs',
        icon: HugeIcons.strokeRoundedBookOpen01,
        accent: Color(0xFF0891B2),
        navigationId: 'courses',
        valueOf: _programsValue,
        hintOf: _programsHint,
      ),
      _AdminDashStatMetric(
        title: 'Colleges',
        icon: HugeIcons.strokeRoundedUniversity,
        accent: Color(0xFF7C3AED),
        navigationId: 'colleges',
        valueOf: _collegesValue,
        hintOf: _collegesHint,
      ),
    ];

String _studentsValue(_DashboardBaseData data) => '${data.studentsCount}';
String _studentsHint(_DashboardBaseData data) => data.studentsWithoutDocs > 0
    ? '${data.studentsWithoutDocs} without docs'
    : 'archived profiles';

String _documentsValue(_DashboardBaseData data) => '${data.documentsCount}';
String _documentsHint(_DashboardBaseData data) => 'stored in archive';

String _programsValue(_DashboardBaseData data) => '${data.coursesCount}';
String _programsHint(_DashboardBaseData data) => 'program offerings';

String _collegesValue(_DashboardBaseData data) => '${data.collegesCount}';
String _collegesHint(_DashboardBaseData data) => 'institutions';

class _AdminDashQuickAction {
  const _AdminDashQuickAction({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

const _adminDashQuickActions = [
  _AdminDashQuickAction(
    id: 'students',
    label: 'Students',
    icon: HugeIcons.strokeRoundedSchool,
  ),
  _AdminDashQuickAction(
    id: 'documents',
    label: 'Documents',
    icon: HugeIcons.strokeRoundedFolder01,
  ),
  _AdminDashQuickAction(
    id: 'backup_restore',
    label: 'Backup',
    icon: HugeIcons.strokeRoundedDatabaseExport,
  ),
  _AdminDashQuickAction(
    id: 'backup_restore',
    label: 'Restore',
    icon: HugeIcons.strokeRoundedDatabaseRestore,
  ),
  _AdminDashQuickAction(
    id: 'data_analytics',
    label: 'Analytics',
    icon: HugeIcons.strokeRoundedAnalytics01,
  ),
  _AdminDashQuickAction(
    id: 'disposable_records',
    label: 'Disposal',
    icon: HugeIcons.strokeRoundedPackage,
  ),
];

String _adminDashTopProgramLabel(_DashboardBaseData data) {
  final name = data.topProgramName;
  if (name == null || name.isEmpty) return 'No program data';
  return '$name (${data.topProgramCount})';
}
