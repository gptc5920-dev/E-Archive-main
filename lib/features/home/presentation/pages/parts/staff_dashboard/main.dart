part of '../../dashboard_shell_page.dart';

class _StaffDashboardPage extends StatelessWidget {
  const _StaffDashboardPage({
    required this.data,
    this.includeHeader = true,
  });

  final _DashboardBaseData data;
  final bool includeHeader;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final recentUploads = _Card(
          title: 'Recent Uploads',
          icon: HugeIcons.strokeRoundedTransactionHistory,
          child: SizedBox(
            height: data.recentDocs.isEmpty ? 70 : 300,
            child: _RecentUploadsTable(rows: data.recentDocs),
          ),
        );
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _DashboardStatTile(
                  title: 'Today Uploads',
                  value: data.recentUploadsCount.toString(),
                  icon: HugeIcons.strokeRoundedCloudUpload,
                  accent: const Color(0xFF0284C7),
                  hint: 'documents received',
                  onTap: data.onNavigate == null
                      ? null
                      : () => data.onNavigate!('documents'),
                ),
                _DashboardStatTile(
                  title: 'Students',
                  value: data.studentsCount.toString(),
                  icon: HugeIcons.strokeRoundedUserMultiple,
                  accent: const Color(0xFF1D4ED8),
                  hint: 'records available',
                  onTap: data.onNavigate == null
                      ? null
                      : () => data.onNavigate!('students'),
                ),
                _DashboardStatTile(
                  title: 'Documents',
                  value: data.documentsCount.toString(),
                  icon: HugeIcons.strokeRoundedFolder03,
                  accent: const Color(0xFF16A34A),
                  hint: 'total documents',
                  onTap: data.onNavigate == null
                      ? null
                      : () => data.onNavigate!('documents'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(child: recentUploads),
          ],
        );

        if (constraints.maxHeight < 520) {
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: SizedBox(height: 520, child: content),
          );
        }

        return SizedBox(
          height: constraints.maxHeight,
          child: content,
        );
      },
    );
  }
}
