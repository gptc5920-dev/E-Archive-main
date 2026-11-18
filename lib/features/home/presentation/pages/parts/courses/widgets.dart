part of '../../dashboard_shell_page.dart';

class _CourseFormDialog extends StatefulWidget {
  const _CourseFormDialog({
    this.existing,
    required this.colleges,
    this.collegeName,
    this.initialCollegeId,
    required this.onAddCourse,
    required this.onUpdateCourse,
    this.onDeleteCourse,
  });

  final _CourseRow? existing;
  final List<_CollegeRow> colleges;
  final String? collegeName;
  final int? initialCollegeId;
  final Future<String?> Function({
    required String name,
    required int collegeId,
  }) onAddCourse;
  final Future<String?> Function({
    required _CourseRow course,
    required String name,
    required int collegeId,
  }) onUpdateCourse;
  final Future<String?> Function(_CourseRow course)? onDeleteCourse;

  @override
  State<_CourseFormDialog> createState() => _CourseFormDialogState();
}

class _CourseFormDialogState extends State<_CourseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _programNameController = TextEditingController();
  bool _saving = false;
  bool _closing = false;
  String? _apiError;
  int? _selectedCollegeId;

  bool get _isEdit => widget.existing != null;

  List<_CollegeRow> get _collegeOptions {
    return widget.colleges.where((college) => college.id != null).toList();
  }

  @override
  void initState() {
    super.initState();
    _programNameController.text = widget.existing?.name.trim() ?? '';
    final requestedCollegeId =
        widget.existing?.collegeId ?? widget.initialCollegeId;
    _selectedCollegeId =
        _collegeOptions.any((college) => college.id == requestedCollegeId)
            ? requestedCollegeId
            : (_collegeOptions.isEmpty ? null : _collegeOptions.first.id);
  }

  @override
  void dispose() {
    _programNameController.dispose();
    super.dispose();
  }

  void _close([String? result]) {
    if (_closing || !mounted) return;
    _closing = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      Navigator.of(context).pop(result);
    });
  }

  Future<void> _submit() async {
    if (_saving || _closing) return;
    setState(() => _apiError = null);
    if (!_formKey.currentState!.validate()) return;

    final name = _programNameController.text.trim();
    final collegeId = _selectedCollegeId;
    if (name.isEmpty || collegeId == null) return;

    setState(() => _saving = true);
    final error = _isEdit
        ? await widget.onUpdateCourse(
            course: widget.existing!,
            name: name,
            collegeId: collegeId,
          )
        : await widget.onAddCourse(name: name, collegeId: collegeId);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _saving = false;
        _apiError = error;
      });
      return;
    }

    _close(_isEdit ? 'updated' : 'added');
  }

  Future<void> _confirmDelete() async {
    final course = widget.existing;
    final onDelete = widget.onDeleteCourse;
    if (course == null || onDelete == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Remove program?'),
        content: Text(
          'Remove ${course.name}? This cannot be undone.',
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    final error = await onDelete(course);
    if (!mounted) return;

    if (error != null) {
      setState(() {
        _saving = false;
        _apiError = error;
      });
      return;
    }

    _close('deleted');
  }

  @override
  Widget build(BuildContext context) {
    final maxDialogHeight =
        math.max(320.0, MediaQuery.sizeOf(context).height - 48);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: maxDialogHeight),
        child: Material(
          color: Colors.white,
          elevation: 8,
          shadowColor: const Color(0x1A000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  border: Border(bottom: BorderSide(color: Color(0xFFBFDBFE))),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF93C5FD)),
                      ),
                      child: Icon(
                        _isEdit
                            ? HugeIcons.strokeRoundedEdit02
                            : HugeIcons.strokeRoundedAddCircle,
                        color: _courseBlue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEdit ? 'Edit program' : 'Add program',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF000000),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isEdit
                                ? 'Update the program and its college.'
                                : widget.collegeName != null
                                    ? 'Add a program for ${widget.collegeName}.'
                                    : 'Choose a college and enter the program name.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF000000),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _saving ? null : _close,
                      tooltip: 'Close',
                      icon: const Icon(HugeIcons.strokeRoundedCancel01,
                          color: Color(0xFF000000)),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: _selectedCollegeId,
                          isExpanded: true,
                          menuMaxHeight: _courseSelectorMenuMaxHeight,
                          borderRadius: BorderRadius.circular(8),
                          style: _courseFieldTextStyle,
                          dropdownColor: Colors.white,
                          decoration: _courseInputDecoration(
                            label: 'College *',
                            hint: _collegeOptions.isEmpty
                                ? 'No colleges available'
                                : 'Select a college',
                          ),
                          items: _collegeOptions
                              .map(
                                (college) => DropdownMenuItem<int>(
                                  value: college.id,
                                  child: Text(
                                    college.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: _courseFieldTextStyle,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _saving || _collegeOptions.isEmpty
                              ? null
                              : (value) =>
                                  setState(() => _selectedCollegeId = value),
                          validator: (value) {
                            if (value == null) {
                              return _collegeOptions.isEmpty
                                  ? 'Add a college before adding a program'
                                  : 'Select a college';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _programNameController,
                          enabled: !_saving,
                          style: _courseFieldTextStyle,
                          cursorColor: const Color(0xFF000000),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: _courseInputDecoration(
                            label: 'Program name *',
                            hint:
                                'e.g. Bachelor of Science in Computer Science',
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Enter a program name';
                            }
                            return null;
                          },
                        ),
                        if (_apiError != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Text(
                              _apiError!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFB91C1C),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB),
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  children: [
                    if (_isEdit && widget.onDeleteCourse != null)
                      TextButton(
                        onPressed: _saving ? null : _confirmDelete,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFB91C1C),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text(
                          'Remove',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (_isEdit && widget.onDeleteCourse != null)
                      const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _close,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF000000),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF000000),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _saving ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: _courseBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isEdit ? 'Save changes' : 'Add program',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
