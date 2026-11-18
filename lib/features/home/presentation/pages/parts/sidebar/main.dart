part of '../../dashboard_shell_page.dart';

class _DashboardSidebar extends StatefulWidget {
  const _DashboardSidebar({
    required this.isDarkAdmin,
    required this.collapsed,
    required this.role,
    required this.accountName,
    required this.sections,
    required this.collapsedSections,
    required this.selectedId,
    required this.onToggleCollapse,
    required this.onSectionToggle,
    required this.onLogout,
    required this.onItemSelected,
  });

  final bool isDarkAdmin;
  final bool collapsed;
  final UserRole role;
  final String accountName;
  final List<_SidebarNavSection> sections;
  final Set<String> collapsedSections;
  final String selectedId;
  final VoidCallback onToggleCollapse;
  final ValueChanged<String> onSectionToggle;
  final VoidCallback onLogout;
  final ValueChanged<String> onItemSelected;

  @override
  State<_DashboardSidebar> createState() => _DashboardSidebarState();
}

class _DashboardSidebarState extends State<_DashboardSidebar> {
  String? _hoverTarget;
  String? _queuedHoverTarget;
  bool _hoverUpdateScheduled = false;

  void _onHoverEnter(String target) {
    _setHoverTarget(target);
  }

  void _onHoverExit(String target) {
    if (_hoverTarget == target || _queuedHoverTarget == target) {
      _setHoverTarget(null);
    }
  }

  void _setHoverTarget(String? target) {
    _queuedHoverTarget = target;
    if (_hoverUpdateScheduled) return;
    _hoverUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hoverUpdateScheduled = false;
      if (!mounted) return;
      final next = _queuedHoverTarget;
      _queuedHoverTarget = null;
      if (_hoverTarget == next) return;
      setState(() => _hoverTarget = next);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _sidebarAnimDuration,
      curve: _sidebarAnimCurve,
      width: widget.collapsed ? _sidebarCollapsedWidth : _sidebarExpandedWidth,
      decoration: BoxDecoration(
        color: _sidebarBg,
        border: Border(
          right: BorderSide(color: _sidebarBorder),
        ),
      ),
      child: Column(
        children: [
          _SidebarHeader(
            collapsed: widget.collapsed,
            isDarkAdmin: widget.isDarkAdmin,
            onToggleCollapse: widget.onToggleCollapse,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 12),
              children: [
                for (var i = 0; i < widget.sections.length; i++) ...[
                  if (i > 0) const SizedBox(height: 4),
                  _SidebarSectionBlock(
                    section: widget.sections[i],
                    collapsed: widget.collapsed,
                    isDarkAdmin: widget.isDarkAdmin,
                    sectionCollapsed: widget.collapsedSections
                        .contains(widget.sections[i].title),
                    selectedId: widget.selectedId,
                    hoverTarget: _hoverTarget,
                    onHoverEnter: _onHoverEnter,
                    onHoverExit: _onHoverExit,
                    onSectionToggle: widget.onSectionToggle,
                    onItemSelected: widget.onItemSelected,
                  ),
                ],
              ],
            ),
          ),
          _SidebarFooter(
            collapsed: widget.collapsed,
            isDarkAdmin: widget.isDarkAdmin,
            role: widget.role,
            accountName: widget.accountName,
            onLogout: widget.onLogout,
          ),
        ],
      ),
    );
  }
}
