part of '../../dashboard_shell_page.dart';

enum _GraduateSort { nameAsc, studentNoAsc, programAsc }

class _YearGraduatesViewPage extends StatefulWidget {
  const _YearGraduatesViewPage({
    required this.year,
    required this.graduates,
    this.programName,
    this.programCode,
    this.onBack,
    this.onBreadcrumbTap,
  });

  final String year;
  final List<_AnalyticsGraduate> graduates;
  final String? programName;
  final String? programCode;
  final VoidCallback? onBack;
  final ValueChanged<int>? onBreadcrumbTap;

  @override
  State<_YearGraduatesViewPage> createState() => _YearGraduatesViewPageState();
}

class _YearGraduatesViewPageState extends State<_YearGraduatesViewPage> {
  static const _chartAccents = <Color>[
    Color(0xFF60A5FA),
    Color(0xFF4ADE80),
    Color(0xFFA78BFA),
    Color(0xFFFB923C),
    Color(0xFF22D3EE),
    Color(0xFFF472B6),
    Color(0xFF3B82F6),
  ];

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  _GraduateSort _sort = _GraduateSort.nameAsc;
  String? _programChipFilter;

  bool get _scopedToProgram =>
      (widget.programName?.trim().isNotEmpty ?? false) ||
      (widget.programCode?.trim().isNotEmpty ?? false);

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<String> get _programOptions {
    final labels = <String>{};
    for (final g in widget.graduates) {
      final label = g.programLabel.trim();
      if (label.isNotEmpty) labels.add(label);
    }
    final list = labels.toList()..sort();
    return list;
  }

  List<_AnalyticsGraduate> get _filtered {
    var list = widget.graduates;
    final chip = _programChipFilter;
    if (!_scopedToProgram && chip != null && chip.isNotEmpty) {
      list = list.where((g) => g.programLabel == chip).toList();
    }

    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (g) =>
                g.fullName.toLowerCase().contains(q) ||
                g.studentNo.toLowerCase().contains(q) ||
                g.course.toLowerCase().contains(q) ||
                g.programLabel.toLowerCase().contains(q) ||
                g.college.toLowerCase().contains(q) ||
                g.schoolYear.toLowerCase().contains(q),
          )
          .toList();
    }

    list = List<_AnalyticsGraduate>.from(list);
    switch (_sort) {
      case _GraduateSort.nameAsc:
        list.sort(
          (a, b) =>
              a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
        );
      case _GraduateSort.studentNoAsc:
        list.sort(
          (a, b) =>
              a.studentNo.toLowerCase().compareTo(b.studentNo.toLowerCase()),
        );
      case _GraduateSort.programAsc:
        list.sort((a, b) {
          final byProgram = a.programLabel
              .toLowerCase()
              .compareTo(b.programLabel.toLowerCase());
          if (byProgram != 0) return byProgram;
          return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
        });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final programOptions = _programOptions;

    final programTitle = widget.programName?.trim().isNotEmpty == true
        ? widget.programName!.trim()
        : widget.programCode?.trim();
    final breadcrumb = <String>[
      'Data Analytics',
      widget.year,
      if (programTitle != null && programTitle.isNotEmpty) programTitle,
      'Graduates',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RecordBreadcrumb(
          segments: breadcrumb,
          onBack: widget.onBack,
          onSegmentTap: widget.onBreadcrumbTap,
          backTooltip: _scopedToProgram
              ? 'Back to year overview'
              : 'Back to Data Analytics',
          maxSegmentWidth: 280,
        ),
        const SizedBox(height: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              programTitle != null && programTitle.isNotEmpty
                  ? programTitle
                  : 'Graduates · ${widget.year}',
              style: _AdminDashTheme.panelTitle(size: 22),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              programTitle != null && programTitle.isNotEmpty
                  ? '${widget.year} · ${widget.graduates.length} graduate${widget.graduates.length == 1 ? '' : 's'}'
                  : '${widget.graduates.length} graduate${widget.graduates.length == 1 ? '' : 's'} in ${widget.year}',
              style: _AdminDashTheme.label(size: 13).copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final stackTools = constraints.maxWidth < 640;
            final search = SizedBox(
              width: stackTools ? double.infinity : 360,
              child: _RecordSearchField(
                controller: _searchController,
                focusNode: _searchFocus,
                hintText: 'Search by name, student #, or program…',
                focusColor: const Color(0xFF4F46E5),
                onChanged: (value) => setState(() => _query = value),
              ),
            );
            final sortControl = _GraduateSortControl(
              value: _sort,
              onChanged: (value) => setState(() => _sort = value),
            );

            if (stackTools) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  search,
                  const SizedBox(height: 10),
                  sortControl,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: search),
                const SizedBox(width: 12),
                sortControl,
              ],
            );
          },
        ),
        if (!_scopedToProgram && programOptions.length > 1) ...[
          const SizedBox(height: 12),
          _GraduateProgramFilterBar(
            programs: programOptions,
            selected: _programChipFilter,
            accents: _chartAccents,
            onSelected: (value) => setState(() => _programChipFilter = value),
          ),
        ],
        if (widget.graduates.isNotEmpty) ...[
          const SizedBox(height: 12),
          _GraduateListSummary(
            showing: filtered.length,
            total: widget.graduates.length,
            hasSearch: _query.trim().isNotEmpty,
            hasProgramFilter: _programChipFilter != null,
          ),
        ],
        const SizedBox(height: 16),
        if (widget.graduates.isEmpty)
          const _AnalyticsEmptyState(
            message: 'No graduate records for this batch.',
          )
        else if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    HugeIcons.strokeRoundedSearchRemove,
                    size: 40,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No graduates match your filters.',
                    style: AppFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _YearGraduatesTable(
            graduates: filtered,
            accents: _chartAccents,
            query: _query.trim(),
          ),
      ],
    );
  }
}

class _GraduateSortControl extends StatelessWidget {
  const _GraduateSortControl({
    required this.value,
    required this.onChanged,
  });

  final _GraduateSort value;
  final ValueChanged<_GraduateSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _AdminDashTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AdminDashTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_GraduateSort>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(8),
          icon: const Icon(HugeIcons.strokeRoundedSorting01,
              size: 18, color: Color(0xFF64748B)),
          style: AppFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
          items: const [
            DropdownMenuItem(
              value: _GraduateSort.nameAsc,
              child: Text('Name A–Z'),
            ),
            DropdownMenuItem(
              value: _GraduateSort.studentNoAsc,
              child: Text('Student #'),
            ),
            DropdownMenuItem(
              value: _GraduateSort.programAsc,
              child: Text('Program'),
            ),
          ],
          onChanged: (picked) {
            if (picked != null) onChanged(picked);
          },
        ),
      ),
    );
  }
}

class _GraduateProgramFilterBar extends StatelessWidget {
  const _GraduateProgramFilterBar({
    required this.programs,
    required this.selected,
    required this.accents,
    required this.onSelected,
  });

  final List<String> programs;
  final String? selected;
  final List<Color> accents;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _GraduateFilterChip(
            label: 'All programs',
            selected: selected == null,
            accent: const Color(0xFF64748B),
            onTap: () => onSelected(null),
          ),
          for (final program in programs) ...[
            const SizedBox(width: 8),
            _GraduateFilterChip(
              label: program,
              selected: selected == program,
              accent: _accentForProgram(program, accents),
              onTap: () => onSelected(program),
            ),
          ],
        ],
      ),
    );
  }
}

class _GraduateFilterChip extends StatelessWidget {
  const _GraduateFilterChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.14) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? accent : const Color(0xFFE2E8F0),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: AppFonts.poppins(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? accent : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }
}

class _GraduateListSummary extends StatelessWidget {
  const _GraduateListSummary({
    required this.showing,
    required this.total,
    required this.hasSearch,
    required this.hasProgramFilter,
  });

  final int showing;
  final int total;
  final bool hasSearch;
  final bool hasProgramFilter;

  @override
  Widget build(BuildContext context) {
    final filtered = hasSearch || hasProgramFilter || showing != total;
    return Row(
      children: [
        Icon(
          HugeIcons.strokeRoundedUserMultiple,
          size: 16,
          color: filtered ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 6),
        Text(
          filtered
              ? 'Showing $showing of $total graduates'
              : '$total graduate${total == 1 ? '' : 's'}',
          style: AppFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: filtered ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class _YearGraduatesTable extends StatelessWidget {
  const _YearGraduatesTable({
    required this.graduates,
    required this.accents,
    required this.query,
  });

  final List<_AnalyticsGraduate> graduates;
  final List<Color> accents;
  final String query;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth =
            constraints.maxWidth < 940 ? 940.0 : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x080F172A),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _YearGraduatesTableHeader(),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: graduates.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    itemBuilder: (context, index) {
                      final graduate = graduates[index];
                      final accent =
                          _accentForProgram(graduate.programLabel, accents);
                      return _YearGraduateRow(
                        graduate: graduate,
                        accent: accent,
                        query: query,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _YearGraduatesTableHeader extends StatelessWidget {
  const _YearGraduatesTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = AppFonts.poppins(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.7,
      color: const Color(0xFF64748B),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 52),
          Expanded(child: Text('GRADUATE', style: style)),
          SizedBox(width: 180, child: Text('STUDENT NO.', style: style)),
          SizedBox(width: 112, child: Text('PROGRAM', style: style)),
          SizedBox(width: 210, child: Text('COLLEGE', style: style)),
          SizedBox(width: 120, child: Text('BATCH', style: style)),
        ],
      ),
    );
  }
}

class _YearGraduateRow extends StatelessWidget {
  const _YearGraduateRow({
    required this.graduate,
    required this.accent,
    required this.query,
  });

  final _AnalyticsGraduate graduate;
  final Color accent;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _GraduateAvatar(
            initials: _graduateInitials(graduate.fullName),
            accent: accent,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HighlightedText(
                  text: graduate.fullName,
                  query: query,
                  style: AppFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                  highlightStyle: AppFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ).copyWith(
                    backgroundColor: accent.withValues(alpha: 0.15),
                  ),
                ),
                if (graduate.course.trim().isNotEmpty &&
                    graduate.course.trim().toLowerCase() !=
                        graduate.programLabel.trim().toLowerCase()) ...[
                  const SizedBox(height: 2),
                  Text(
                    graduate.course,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 180,
            child: _HighlightedText(
              text: graduate.studentNo,
              query: query,
              style: AppFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
                letterSpacing: 0.2,
              ),
              highlightStyle: AppFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: accent,
              ).copyWith(
                backgroundColor: accent.withValues(alpha: 0.12),
              ),
            ),
          ),
          SizedBox(
            width: 112,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _GraduateProgramChip(
                  label: graduate.programLabel, accent: accent),
            ),
          ),
          SizedBox(
            width: 210,
            child: Text(
              graduate.college.trim().isEmpty ? '-' : graduate.college,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              graduate.schoolYear.trim().isEmpty ? '-' : graduate.schoolYear,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    required this.highlightStyle,
  });

  final String text;
  final String query;
  final TextStyle style;
  final TextStyle highlightStyle;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return Text(text,
          style: style, maxLines: 2, overflow: TextOverflow.ellipsis);
    }

    final lower = text.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final index = lower.indexOf(q, start);
      if (index < 0) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start), style: style));
        }
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: style));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + q.length),
          style: highlightStyle,
        ),
      );
      start = index + q.length;
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans),
    );
  }
}
