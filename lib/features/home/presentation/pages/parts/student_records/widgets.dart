part of '../../dashboard_shell_page.dart';

class _StudentsListTopBar extends StatelessWidget {
  const _StudentsListTopBar({
    required this.canEdit,
    this.onAdd,
    this.drillCollegeName,
    this.drillCourseName,
    this.onDrillBack,
  });

  final bool canEdit;
  final VoidCallback? onAdd;
  final String? drillCollegeName;
  final String? drillCourseName;
  final VoidCallback? onDrillBack;

  @override
  Widget build(BuildContext context) {
    final inDrill = drillCourseName != null && drillCourseName!.isNotEmpty;
    return Row(
      children: [
        if (inDrill)
          _StudentsDrillBreadcrumb(
            collegeName: drillCollegeName ?? '',
            courseName: drillCourseName!,
            onBack: onDrillBack,
          )
        else
          const _StudentsBreadcrumb(),
        const Spacer(),
        if (canEdit && onAdd != null) ...[
          const SizedBox(width: 10),
          _RecordsAddButton(onPressed: onAdd!),
        ],
      ],
    );
  }
}

class _StudentsDrillBreadcrumb extends StatelessWidget {
  const _StudentsDrillBreadcrumb({
    required this.collegeName,
    required this.courseName,
    this.onBack,
  });

  final String collegeName;
  final String courseName;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final segments = <String>[
      'Records',
      if (collegeName.isNotEmpty) collegeName,
      courseName,
      'Students',
    ];
    return _RecordBreadcrumb(
      segments: segments,
      onBack: onBack,
      backTooltip: 'Back to programs',
    );
  }
}

class _StudentsFormTopBar extends StatelessWidget {
  const _StudentsFormTopBar({
    required this.onBack,
    required this.canEdit,
    this.onAdd,
  });

  final VoidCallback onBack;
  final bool canEdit;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RecordBreadcrumb(
            segments: const ['Records', 'Students'],
            onBack: onBack,
            backTooltip: 'Back to list',
          ),
        ),
        if (canEdit && onAdd != null) ...[
          const SizedBox(width: 10),
          _RecordsAddButton(onPressed: onAdd!),
        ],
      ],
    );
  }
}

class _StudentsBreadcrumb extends StatelessWidget {
  const _StudentsBreadcrumb();

  @override
  Widget build(BuildContext context) {
    return const _RecordBreadcrumb(segments: ['Records', 'Students']);
  }
}

class _RecordsAddButton extends StatelessWidget {
  const _RecordsAddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _collegeTeal,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 36,
          height: 36,
          child:
              Icon(HugeIcons.strokeRoundedAdd01, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _StudentFormTabBar extends StatelessWidget {
  const _StudentFormTabBar({required this.tab, required this.onChanged});

  final _StudentFormTab tab;
  final ValueChanged<_StudentFormTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          _StudentFormTabChip(
            label: 'Student',
            selected: tab == _StudentFormTab.student,
            onTap: () => onChanged(_StudentFormTab.student),
          ),
          _StudentFormTabChip(
            label: 'Academic',
            selected: tab == _StudentFormTab.academic,
            onTap: () => onChanged(_StudentFormTab.academic),
          ),
          _StudentFormTabChip(
            label: 'Contact',
            selected: tab == _StudentFormTab.contact,
            onTap: () => onChanged(_StudentFormTab.contact),
          ),
          _StudentFormTabChip(
            label: 'Notes',
            selected: tab == _StudentFormTab.notes,
            onTap: () => onChanged(_StudentFormTab.notes),
          ),
          _StudentFormTabChip(
            label: 'Dates',
            selected: tab == _StudentFormTab.dates,
            onTap: () => onChanged(_StudentFormTab.dates),
          ),
          _StudentFormTabChip(
            label: 'Documents',
            selected: tab == _StudentFormTab.documents,
            onTap: () => onChanged(_StudentFormTab.documents),
          ),
        ],
      ),
    );
  }
}

class _StudentFormTabChip extends StatelessWidget {
  const _StudentFormTabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? _collegeTeal : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: _studentLabelTextStyle.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _StudentLabeledField extends StatelessWidget {
  const _StudentLabeledField({
    required this.label,
    required this.child,
    this.required = false,
  });

  final String label;
  final Widget child;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 168,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Text(label, style: _studentLabelTextStyle),
                  if (required) Text('*', style: _studentRequiredMarkTextStyle),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _StudentTextField extends StatelessWidget {
  const _StudentTextField({
    required this.controller,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      readOnly: readOnly,
      style: _studentInputTextStyle,
      decoration: _studentInputDecoration(hint: hint),
    );
  }
}

class _StudentDateField extends StatelessWidget {
  const _StudentDateField({
    required this.controller,
    required this.showWarning,
    required this.onPick,
  });

  final TextEditingController controller;
  final bool showWarning;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onPick,
      style: _studentInputTextStyle,
      decoration: _studentInputDecoration().copyWith(
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showWarning)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(
                  HugeIcons.strokeRoundedAlert01,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
              ),
            IconButton(
              tooltip: 'Pick date',
              onPressed: onPick,
              icon: const Icon(
                HugeIcons.strokeRoundedCalendar01,
                size: 18,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentDocumentsSection extends StatelessWidget {
  const _StudentDocumentsSection({
    required this.documents,
    required this.existingDocuments,
    this.existingDocumentCount = 0,
    required this.onAdd,
    required this.onRemove,
    required this.onPickDate,
    required this.onPickFile,
    required this.onPickFiles,
    required this.onScanDocuments,
    required this.onDropFiles,
    required this.documentTypes,
    required this.onDocumentChanged,
    required this.onPreviewExisting,
    required this.onPreviewDraft,
    required this.onDownloadExisting,
    required this.onEditExisting,
    required this.onDeleteExisting,
  });

  final List<_StudentDocumentDraft> documents;
  final List<_DocRow> existingDocuments;
  final int existingDocumentCount;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onPickDate;
  final ValueChanged<int> onPickFile;
  final VoidCallback onPickFiles;
  final VoidCallback onScanDocuments;
  final ValueChanged<List<XFile>> onDropFiles;
  final List<String> documentTypes;
  final VoidCallback onDocumentChanged;
  final ValueChanged<_DocRow> onPreviewExisting;
  final ValueChanged<_StudentDocumentDraft> onPreviewDraft;
  final Future<void> Function(_DocRow document) onDownloadExisting;
  final Future<_DocRow?> Function(_DocRow document) onEditExisting;
  final Future<bool> Function(_DocRow document) onDeleteExisting;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: const Color(0xFFF9FAFB),
          child: Text(
            'Files and documents ${existingDocumentCount + documents.length}',
            style: _studentSectionTitleTextStyle,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StudentDocumentDropZone(
                onPickFiles: onPickFiles,
                onScanDocuments: onScanDocuments,
                onDropFiles: onDropFiles,
              ),
              const SizedBox(height: 12),
              _StudentDocumentDraftTable(
                documents: documents,
                existingDocuments: existingDocuments,
                existingDocumentCount: existingDocumentCount,
                documentTypes: documentTypes,
                onRemove: onRemove,
                onPickDate: onPickDate,
                onPickFile: onPickFile,
                onChanged: onDocumentChanged,
                onPreviewExisting: onPreviewExisting,
                onPreviewDraft: onPreviewDraft,
                onDownloadExisting: onDownloadExisting,
                onEditExisting: onEditExisting,
                onDeleteExisting: onDeleteExisting,
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(HugeIcons.strokeRoundedAdd01,
                          size: 18, color: _collegeTeal),
                      const SizedBox(width: 8),
                      Text(
                        'Add another Student document',
                        style: _studentLinkTextStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StudentDocumentEditDialog extends StatefulWidget {
  const _StudentDocumentEditDialog({
    required this.document,
    required this.documentTypes,
    required this.onSave,
  });

  final _DocRow document;
  final List<String> documentTypes;
  final Future<_DocRow?> Function({
    required String title,
    required String documentType,
    required String tags,
    required String? replacementFilePath,
  }) onSave;

  @override
  State<_StudentDocumentEditDialog> createState() =>
      _StudentDocumentEditDialogState();
}

class _StudentDocumentEditDialogState
    extends State<_StudentDocumentEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _customTypeController;
  late final TextEditingController _tagsController;
  late String _selectedType;
  String? _replacementFilePath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.document.title);
    _tagsController = TextEditingController(text: widget.document.tags);

    final currentType = _studentDocumentTypeLabel(widget.document);
    final standardTypes = widget.documentTypes.where((type) => type != 'Other');
    _selectedType = standardTypes.contains(currentType)
        ? currentType
        : widget.documentTypes.contains('Other')
            ? 'Other'
            : currentType;
    _customTypeController = TextEditingController(
      text: _selectedType == 'Other' ? currentType : '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _customTypeController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  String get _resolvedType => _selectedType == 'Other'
      ? _customTypeController.text.trim()
      : _selectedType.trim();

  Future<void> _pickReplacementFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
      withData: false,
    );
    final path = result?.files.single.path?.trim() ?? '';
    if (path.isEmpty || !mounted) return;
    setState(() => _replacementFilePath = path);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showInfo(context, 'Enter the document name.');
      return;
    }
    final documentType = _resolvedType;
    if (documentType.isEmpty) {
      _showInfo(context, 'Enter the file type name.');
      return;
    }

    setState(() => _saving = true);
    final updated = await widget.onSave(
      title: title,
      documentType: documentType,
      tags: _tagsController.text.trim(),
      replacementFilePath: _replacementFilePath,
    );
    if (!mounted) return;
    if (updated == null) {
      setState(() => _saving = false);
      _showInfo(context, 'Could not update the document.');
      return;
    }
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final localPath = widget.document.localFilePath?.trim() ?? '';
    final remotePath = widget.document.remoteImageUrl.trim();
    final fileName = localPath.isNotEmpty
        ? p.basename(localPath)
        : remotePath.isNotEmpty
            ? p.basename(Uri.tryParse(remotePath)?.path ?? '')
            : _documentDisplayName(widget.document);
    final replacementPath = _replacementFilePath?.trim() ?? '';
    final replacementName =
        replacementPath.isEmpty ? '' : p.basename(replacementPath);

    return AlertDialog(
      title: const Text('Edit document'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Document name *',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Document type *',
                ),
                items: widget.documentTypes
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _selectedType = value);
                      },
              ),
              if (_selectedType == 'Other') ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _customTypeController,
                  enabled: !_saving,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'File type name *',
                    hintText: 'e.g. Certificate of Enrollment',
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _tagsController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  hintText: 'Separate tags with commas',
                ),
              ),
              const SizedBox(height: 14),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: replacementName.isEmpty
                      ? 'Current file'
                      : 'Replacement file',
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        replacementName.isEmpty
                            ? (fileName.isEmpty ? 'File unavailable' : fileName)
                            : replacementName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: replacementName.isEmpty
                            ? _studentMutedTextStyle
                            : _studentInputTextStyle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                      ),
                    ),
                    if (replacementName.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear replacement',
                        onPressed: _saving
                            ? null
                            : () => setState(
                                  () => _replacementFilePath = null,
                                ),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          HugeIcons.strokeRoundedCancel01,
                          size: 18,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickReplacementFile,
                icon: const Icon(HugeIcons.strokeRoundedFileUpload, size: 18),
                label: Text(
                  replacementName.isEmpty
                      ? 'Choose replacement file'
                      : 'Choose a different file',
                ),
              ),
              if (replacementName.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'The replacement will be uploaded when you save. The '
                  'current file will then be moved to Trash.',
                  style: _studentMutedTextStyle,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save document'),
        ),
      ],
    );
  }
}

class _StudentDocumentDraftTable extends StatelessWidget {
  const _StudentDocumentDraftTable({
    required this.documents,
    required this.existingDocuments,
    required this.existingDocumentCount,
    required this.documentTypes,
    required this.onRemove,
    required this.onPickDate,
    required this.onPickFile,
    required this.onChanged,
    required this.onPreviewExisting,
    required this.onPreviewDraft,
    required this.onDownloadExisting,
    required this.onEditExisting,
    required this.onDeleteExisting,
  });

  final List<_StudentDocumentDraft> documents;
  final List<_DocRow> existingDocuments;
  final int existingDocumentCount;
  final List<String> documentTypes;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onPickDate;
  final ValueChanged<int> onPickFile;
  final VoidCallback onChanged;
  final ValueChanged<_DocRow> onPreviewExisting;
  final ValueChanged<_StudentDocumentDraft> onPreviewDraft;
  final Future<void> Function(_DocRow document) onDownloadExisting;
  final Future<_DocRow?> Function(_DocRow document) onEditExisting;
  final Future<bool> Function(_DocRow document) onDeleteExisting;

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final totalRows = existingDocuments.length + documents.length;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const minimumTableWidth = 1124.0;
          final availableWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : minimumTableWidth;
          final tableWidth = availableWidth < minimumTableWidth
              ? minimumTableWidth
              : availableWidth;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  const _StudentDocumentDraftTableHeader(),
                  if (totalRows == 0)
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        'No student documents added yet.',
                        style: _studentMutedTextStyle,
                      ),
                    )
                  else ...[
                    for (var i = 0; i < existingDocuments.length; i++)
                      _StudentExistingDocumentTableRow(
                        index: i + 1,
                        doc: existingDocuments[i],
                        showDivider: i < totalRows - 1,
                        onPreview: () =>
                            onPreviewExisting(existingDocuments[i]),
                        onDownload: () =>
                            onDownloadExisting(existingDocuments[i]),
                        onEdit: () => onEditExisting(existingDocuments[i]),
                        onDelete: () => onDeleteExisting(existingDocuments[i]),
                      ),
                    for (var i = 0; i < documents.length; i++)
                      _StudentDocumentDraftTableRow(
                        index: existingDocuments.length + i + 1,
                        draft: documents[i],
                        documentTypes: documentTypes,
                        showDivider:
                            existingDocuments.length + i < totalRows - 1,
                        onRemove: () => onRemove(i),
                        onPickDate: () => onPickDate(i),
                        onPickFile: () => onPickFile(i),
                        onPreview: () => onPreviewDraft(documents[i]),
                        onChanged: onChanged,
                        formatDate: _formatDate,
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StudentExistingDocumentTableRow extends StatelessWidget {
  const _StudentExistingDocumentTableRow({
    required this.index,
    required this.doc,
    required this.showDivider,
    required this.onPreview,
    required this.onDownload,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final _DocRow doc;
  final bool showDivider;
  final VoidCallback onPreview;
  final Future<void> Function() onDownload;
  final Future<_DocRow?> Function() onEdit;
  final Future<bool> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFD),
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text('$index', style: _studentFieldTextStyle),
          ),
          Expanded(
            flex: 19,
            child: InkWell(
              onTap: onPreview,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  _documentDisplayName(doc),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _studentInputTextStyle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 16,
            child: _StudentDocPill(text: _studentDocumentTypeLabel(doc)),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 22,
            child: Text(
              _documentDisplayName(doc),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _studentMutedTextStyle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 12,
            child: Text(doc.uploaded, style: _studentMutedTextStyle),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 14,
            child: Text(
              doc.tags.trim().isEmpty ? '-' : doc.tags,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _studentMutedTextStyle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 11,
            child: Text('Saved', style: _studentMutedTextStyle),
          ),
          SizedBox(
            width: 48,
            child: PopupMenuButton<String>(
              tooltip: 'Document actions',
              icon: const Icon(HugeIcons.strokeRoundedMoreVertical),
              onSelected: (value) async {
                if (value == 'edit') {
                  await onEdit();
                } else if (value == 'download') {
                  await onDownload();
                } else if (value == 'remove') {
                  await onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'download',
                  child: ListTile(
                    dense: true,
                    leading: Icon(HugeIcons.strokeRoundedDownload01),
                    title: Text('Download'),
                  ),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    dense: true,
                    leading: Icon(HugeIcons.strokeRoundedEdit02),
                    title: Text('Edit'),
                  ),
                ),
                PopupMenuItem(
                  value: 'remove',
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      HugeIcons.strokeRoundedDelete02,
                      color: Color(0xFFB91C1C),
                    ),
                    title: Text(
                      'Remove',
                      style: TextStyle(color: Color(0xFFB91C1C)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentDocumentDraftTableHeader extends StatelessWidget {
  const _StudentDocumentDraftTableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Color(0xFF475569),
      fontSize: 12,
      fontWeight: FontWeight.w800,
    );
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: const Row(
        children: [
          SizedBox(width: 38, child: Text('#', style: style)),
          Expanded(flex: 19, child: Text('Document', style: style)),
          SizedBox(width: 10),
          Expanded(flex: 16, child: Text('Type', style: style)),
          SizedBox(width: 10),
          Expanded(flex: 22, child: Text('File', style: style)),
          SizedBox(width: 10),
          Expanded(flex: 12, child: Text('Received', style: style)),
          SizedBox(width: 10),
          Expanded(flex: 14, child: Text('Tags', style: style)),
          SizedBox(width: 10),
          Expanded(flex: 11, child: Text('Remarks', style: style)),
          SizedBox(width: 48, child: Text('Actions', style: style)),
        ],
      ),
    );
  }
}

class _StudentDocumentDraftTableRow extends StatelessWidget {
  const _StudentDocumentDraftTableRow({
    required this.index,
    required this.draft,
    required this.documentTypes,
    required this.showDivider,
    required this.onRemove,
    required this.onPickDate,
    required this.onPickFile,
    required this.onPreview,
    required this.onChanged,
    required this.formatDate,
  });

  final int index;
  final _StudentDocumentDraft draft;
  final List<String> documentTypes;
  final bool showDivider;
  final VoidCallback onRemove;
  final VoidCallback onPickDate;
  final VoidCallback onPickFile;
  final VoidCallback onPreview;
  final VoidCallback onChanged;
  final String Function(DateTime? date) formatDate;

  @override
  Widget build(BuildContext context) {
    final fileName = draft.fileName?.trim() ?? '';
    final filePath = draft.filePath?.trim() ?? '';
    final hasFile = fileName.isNotEmpty || filePath.isNotEmpty;
    final fileLabel = fileName.isNotEmpty ? fileName : p.basename(filePath);
    final selectedType = draft.usesCustomDocumentType
        ? 'Other'
        : documentTypes.contains(draft.documentType)
            ? draft.documentType
            : (documentTypes.isEmpty
                ? draft.documentType
                : documentTypes.first);

    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text('$index', style: _studentFieldTextStyle),
          ),
          Expanded(
            flex: 19,
            child: TextFormField(
              initialValue: draft.title,
              style: _studentInputTextStyle,
              decoration: _studentInputDecoration(hint: 'Document name'),
              onChanged: (value) {
                draft.title = value;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  isExpanded: true,
                  style: _studentInputTextStyle,
                  decoration: _studentInputDecoration(),
                  dropdownColor: Colors.white,
                  items: documentTypes
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(
                            type,
                            overflow: TextOverflow.ellipsis,
                            style: _studentInputTextStyle,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    draft.usesCustomDocumentType = value == 'Other';
                    draft.documentType = value == 'Other' ? '' : value;
                    onChanged();
                  },
                ),
                if (draft.usesCustomDocumentType) ...[
                  const SizedBox(height: 6),
                  TextFormField(
                    key: ValueKey('custom-type-${identityHashCode(draft)}'),
                    initialValue: draft.documentType,
                    style: _studentInputTextStyle,
                    textCapitalization: TextCapitalization.words,
                    decoration: _studentInputDecoration(
                      hint: 'File type name *',
                    ),
                    onChanged: (value) {
                      draft.documentType = value;
                      onChanged();
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 22,
            child: InkWell(
              onTap: hasFile ? onPreview : onPickFile,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: _studentInputDecoration(
                  hint: 'Choose file',
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasFile ? fileLabel : 'Choose file',
                        overflow: TextOverflow.ellipsis,
                        style: hasFile
                            ? _studentInputTextStyle
                            : _studentHintTextStyle,
                      ),
                    ),
                    Icon(
                      HugeIcons.strokeRoundedFileUpload,
                      size: 18,
                      color: hasFile ? _collegeTeal : _studentTextMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 12,
            child: OutlinedButton.icon(
              onPressed: onPickDate,
              icon: Icon(
                draft.receivedAt == null
                    ? HugeIcons.strokeRoundedAlert01
                    : HugeIcons.strokeRoundedCalendar01,
                size: 16,
                color:
                    draft.receivedAt == null ? const Color(0xFFDC2626) : null,
              ),
              label: Text(
                formatDate(draft.receivedAt),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 14,
            child: TextFormField(
              initialValue: draft.tags,
              style: _studentInputTextStyle,
              decoration: _studentInputDecoration(hint: 'Tags'),
              onChanged: (value) {
                draft.tags = value;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 11,
            child: TextFormField(
              initialValue: draft.remarks,
              style: _studentInputTextStyle,
              decoration: _studentInputDecoration(hint: 'Remarks'),
              onChanged: (value) {
                draft.remarks = value;
                onChanged();
              },
            ),
          ),
          SizedBox(
            width: 48,
            child: PopupMenuButton<String>(
              tooltip: 'File actions',
              icon: const Icon(HugeIcons.strokeRoundedMoreVertical),
              onSelected: (value) {
                if (value == 'replace') {
                  onPickFile();
                } else if (value == 'remove') {
                  onRemove();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'replace',
                  child: ListTile(
                    dense: true,
                    leading: const Icon(HugeIcons.strokeRoundedFileUpload),
                    title: Text(hasFile ? 'Replace file' : 'Choose file'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      HugeIcons.strokeRoundedDelete02,
                      color: Color(0xFFDC2626),
                    ),
                    title: Text(
                      'Remove',
                      style: TextStyle(color: Color(0xFFDC2626)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentDocumentDropZone extends StatefulWidget {
  const _StudentDocumentDropZone({
    required this.onPickFiles,
    required this.onScanDocuments,
    required this.onDropFiles,
  });

  final VoidCallback onPickFiles;
  final VoidCallback onScanDocuments;
  final ValueChanged<List<XFile>> onDropFiles;

  @override
  State<_StudentDocumentDropZone> createState() =>
      _StudentDocumentDropZoneState();
}

class _StudentDocumentDropZoneState extends State<_StudentDocumentDropZone> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) {
        setState(() => _dragging = false);
        widget.onDropFiles(detail.files);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _dragging ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                _dragging ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
            width: _dragging ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(HugeIcons.strokeRoundedUpload01, color: _collegeTeal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Drag and drop documents here, or choose multiple files',
                style: _studentFieldTextStyle.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: widget.onPickFiles,
              icon: const Icon(HugeIcons.strokeRoundedAdd01, size: 17),
              label: const Text('Choose files'),
            ),
            const SizedBox(width: 6),
            FilledButton.tonalIcon(
              onPressed: widget.onScanDocuments,
              icon: const Icon(Icons.document_scanner_outlined, size: 17),
              label: const Text('Scan document'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentHeaderCell extends StatelessWidget {
  const _StudentHeaderCell({
    required this.flex,
    required this.label,
    this.alignEnd = false,
  });

  final int flex;
  final String label;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(label, style: _studentTableHeaderTextStyle),
        ),
      ),
    );
  }
}

class _StudentSortableHeaderCell extends StatelessWidget {
  const _StudentSortableHeaderCell({
    required this.flex,
    required this.label,
    required this.column,
    required this.activeColumn,
    required this.ascending,
    required this.onSort,
  });

  final int flex;
  final String label;
  final _StudentListSortColumn column;
  final _StudentListSortColumn activeColumn;
  final bool ascending;
  final ValueChanged<_StudentListSortColumn> onSort;

  @override
  Widget build(BuildContext context) {
    final active = column == activeColumn;
    return Expanded(
      flex: flex,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSort(column),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: _studentTableHeaderTextStyle.copyWith(
                      color: active
                          ? const Color(0xFF2563EB)
                          : _studentTableHeaderTextStyle.color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  active
                      ? (ascending
                          ? HugeIcons.strokeRoundedArrowUp01
                          : HugeIcons.strokeRoundedArrowDown01)
                      : HugeIcons.strokeRoundedUnfoldMore,
                  size: 14,
                  color: active
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentTableSortLabel extends StatelessWidget {
  const _StudentTableSortLabel({
    required this.label,
    required this.column,
    required this.activeColumn,
    required this.ascending,
    required this.onSort,
  });

  final String label;
  final _StudentListSortColumn column;
  final _StudentListSortColumn activeColumn;
  final bool ascending;
  final ValueChanged<_StudentListSortColumn> onSort;

  @override
  Widget build(BuildContext context) {
    final active = column == activeColumn;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSort(column),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: _studentTableHeaderTextStyle.copyWith(
                  color: active
                      ? const Color(0xFF2563EB)
                      : _studentTableHeaderTextStyle.color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              active
                  ? (ascending
                      ? HugeIcons.strokeRoundedArrowUp01
                      : HugeIcons.strokeRoundedArrowDown01)
                  : HugeIcons.strokeRoundedUnfoldMore,
              size: 14,
              color: active ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentListPaginationBar extends StatelessWidget {
  const _StudentListPaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  List<int> _visiblePageNumbers() {
    if (totalPages <= 5) {
      return List.generate(totalPages, (i) => i);
    }
    var start = currentPage - 2;
    var end = currentPage + 2;
    if (start < 0) {
      end -= start;
      start = 0;
    }
    if (end >= totalPages) {
      start -= end - totalPages + 1;
      end = totalPages - 1;
    }
    start = start.clamp(0, totalPages - 1);
    return List.generate(end - start + 1, (i) => start + i);
  }

  @override
  Widget build(BuildContext context) {
    if (totalItems == 0) return const SizedBox.shrink();

    final rangeStart = currentPage * pageSize + 1;
    final rangeEnd = math.min((currentPage + 1) * pageSize, totalItems);
    final showPager = totalPages > 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              showPager
                  ? 'Showing $rangeStart–$rangeEnd of $totalItems students'
                  : '$totalItems student${totalItems == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showPager) ...[
            IconButton(
              tooltip: 'Previous page',
              onPressed:
                  currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
              icon: const Icon(HugeIcons.strokeRoundedArrowLeft01),
              iconSize: 22,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              color: const Color(0xFF64748B),
            ),
            for (final page in _visiblePageNumbers())
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  color: page == currentPage
                      ? const Color(0xFF2563EB)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    onTap: () => onPageChanged(page),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        '${page + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: page == currentPage
                              ? Colors.white
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Next page',
              onPressed: currentPage < totalPages - 1
                  ? () => onPageChanged(currentPage + 1)
                  : null,
              icon: const Icon(HugeIcons.strokeRoundedArrowRight01),
              iconSize: 22,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              color: const Color(0xFF64748B),
            ),
          ],
        ],
      ),
    );
  }
}

class _StudentDataRow extends StatelessWidget {
  const _StudentDataRow({
    required this.student,
    this.striped = false,
    required this.canEdit,
    required this.isAdmin,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final _StudentRow student;
  final bool striped;
  final bool canEdit;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final batch = _schoolYearForStudent(student);
    return Material(
      color: striped ? const Color(0xFFFAFBFC) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: const Color(0xFFF1F5F9),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Row(
            children: [
              _StudentCell(
                flex: 2,
                text: StudentNumber.displayValue(student.studentNo),
                bold: true,
              ),
              _StudentCell(flex: 3, text: _nameCase(student.fullName)),
              _StudentCell(flex: 3, text: _sentenceCase(student.course)),
              _StudentCell(
                flex: 2,
                text: batch.isEmpty ? 'Unassigned' : batch,
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _RecordEditAction(onPressed: canEdit ? onEdit : null),
                        if (isAdmin) ...[
                          const SizedBox(width: 2),
                          _RecordDeleteAction(
                            onPressed: onDelete,
                            tooltip: 'Move to trash',
                          ),
                        ],
                      ],
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

class _ResizableStudentModalFrame extends StatefulWidget {
  const _ResizableStudentModalFrame({required this.child});

  final Widget child;

  @override
  State<_ResizableStudentModalFrame> createState() =>
      _ResizableStudentModalFrameState();
}

class _ResizableStudentModalFrameState
    extends State<_ResizableStudentModalFrame> {
  double? _width;
  double? _height;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final maxWidth = math.max(0.0, screen.width - 24);
    final maxHeight = math.max(0.0, screen.height - 24);
    final minWidth = math.min(420.0, maxWidth);
    final minHeight = math.min(360.0, maxHeight);
    final width = (_width ?? math.min(820.0, maxWidth))
        .clamp(minWidth, maxWidth)
        .toDouble();
    final height = (_height ?? math.min(720.0, maxHeight))
        .clamp(minHeight, maxHeight)
        .toDouble();

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          Positioned(
            right: 2,
            bottom: 2,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) {
                setState(() {
                  _width = (width + details.delta.dx)
                      .clamp(minWidth, maxWidth)
                      .toDouble();
                  _height = (height + details.delta.dy)
                      .clamp(minHeight, maxHeight)
                      .toDouble();
                });
              },
              child: const SizedBox(
                width: 28,
                height: 28,
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(
                      HugeIcons.strokeRoundedFullScreen,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentDetailPanel extends StatefulWidget {
  const _StudentDetailPanel({
    required this.student,
    required this.documents,
    this.onAddFiles,
    this.onDownloadPdfs,
    this.onEdit,
  });

  final _StudentRow student;
  final List<_DocRow> documents;
  final Future<List<_DocRow>> Function(List<XFile> files)? onAddFiles;
  final Future<void> Function()? onDownloadPdfs;
  final VoidCallback? onEdit;

  @override
  State<_StudentDetailPanel> createState() => _StudentDetailPanelState();
}

class _StudentDetailPanelState extends State<_StudentDetailPanel> {
  int _tabIndex = 0;
  late List<_DocRow> _documents = List.of(widget.documents);
  bool _downloadingPdfs = false;

  @override
  void didUpdateWidget(covariant _StudentDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.documents, widget.documents)) {
      _documents = List.of(widget.documents);
    }
  }

  Future<void> _addFiles(List<XFile> files) async {
    final onAddFiles = widget.onAddFiles;
    if (onAddFiles == null || files.isEmpty) return;
    final updated = await onAddFiles(files);
    if (!mounted) return;
    setState(() => _documents = List.of(updated));
  }

  Future<void> _downloadPdfs() async {
    final download = widget.onDownloadPdfs;
    if (download == null || _downloadingPdfs) return;
    setState(() => _downloadingPdfs = true);
    try {
      await download();
    } finally {
      if (mounted) setState(() => _downloadingPdfs = false);
    }
  }

  void _openDocumentViewer(BuildContext context, _DocRow doc) {
    if (!_canPreviewDocument(doc)) {
      _showInfo(context, 'Preview is not available for this document.');
      return;
    }

    _showResizableDocumentViewer(context, document: doc);
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final student = widget.student;
    final documents = _documents;
    final batch = _schoolYearForStudent(student);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 14 : 20,
            compact ? 14 : 18,
            compact ? 6 : 12,
            12,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 54 : 72,
                height: compact ? 54 : 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  HugeIcons.strokeRoundedUser03,
                  color: Color(0xFF0369A1),
                  size: 34,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameCase(student.fullName),
                      style: _studentTitleTextStyle.copyWith(
                        fontSize: compact ? 22 : 30,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      StudentNumber.displayValue(student.studentNo),
                      style: _studentSubtitleTextStyle,
                    ),
                  ],
                ),
              ),
              if (widget.onDownloadPdfs != null) ...[
                IconButton(
                  onPressed: _downloadingPdfs ? null : _downloadPdfs,
                  icon: _downloadingPdfs
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(HugeIcons.strokeRoundedDownload01),
                  tooltip: 'Download all PDFs as ZIP',
                ),
                const SizedBox(width: 4),
              ],
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  HugeIcons.strokeRoundedCancel01,
                  color: Color(0xFF475569),
                  size: 30,
                ),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20),
          child: Row(
            children: [
              _StudentDetailTab(
                selected: _tabIndex == 0,
                icon: HugeIcons.strokeRoundedUser03,
                label: 'Overview',
                onTap: () => setState(() => _tabIndex = 0),
              ),
              const SizedBox(width: 22),
              _StudentDetailTab(
                selected: _tabIndex == 1,
                icon: HugeIcons.strokeRoundedFile02,
                label: 'Documents',
                badge: '${documents.length}',
                onTap: () => setState(() => _tabIndex = 1),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFCBD5E1)),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              compact ? 14 : 20,
              22,
              compact ? 14 : 20,
              22,
            ),
            child: _tabIndex == 0
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _StudentDetailSectionTitle(
                        icon: HugeIcons.strokeRoundedInformationCircle,
                        label: 'Student Information',
                      ),
                      const SizedBox(height: 16),
                      _StudentDetailInfoGridModern(
                        student: student,
                        batch: batch.isEmpty ? 'Unassigned' : batch,
                      ),
                    ],
                  )
                : _StudentDocumentsTable(
                    documents: documents,
                    canPreviewImage: _canPreviewDocument,
                    onPreview: (doc) => _openDocumentViewer(context, doc),
                    onAddFiles: widget.onAddFiles == null ? null : _addFiles,
                  ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        Padding(
          padding:
              EdgeInsets.fromLTRB(compact ? 12 : 20, 14, compact ? 12 : 20, 16),
          child: Row(
            children: [
              Icon(HugeIcons.strokeRoundedClock01,
                  size: 17, color: _studentTextMuted),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Created: ${student.graduationDate.isEmpty ? student.lastEnrollmentDate : student.graduationDate}',
                  style: _studentMutedTextStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 24),
              Icon(HugeIcons.strokeRoundedDatabaseSync,
                  size: 17, color: _studentTextMuted),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Last updated: ${documents.isEmpty ? student.lastEnrollmentDate : documents.first.uploaded}',
                  style: _studentMutedTextStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              if (widget.onEdit != null)
                OutlinedButton.icon(
                  onPressed: widget.onEdit,
                  icon: const Icon(HugeIcons.strokeRoundedView, size: 18),
                  label: const Text('View Student'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _studentTextBlack,
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StudentDetailInfoGrid extends StatelessWidget {
  const _StudentDetailInfoGrid({required this.student});

  final _StudentRow student;

  @override
  Widget build(BuildContext context) {
    final batch = _schoolYearForStudent(student);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
          _StudentDetailField(label: 'Program', value: student.course),
          _StudentDetailField(
            label: 'Batch',
            value: batch.isEmpty ? 'Unassigned' : batch,
          ),
          _StudentDetailField(
            label: 'Sex',
            value: student.sex.trim().isEmpty ? '-' : student.sex,
          ),
          _StudentDetailField(
            label: 'Birth date',
            value: student.birthDate.trim().isEmpty ? '-' : student.birthDate,
          ),
          _StudentDetailField(
            label: 'Status',
            value: student.status.isEmpty ? '—' : student.status,
          ),
          _StudentDetailField(
            label: 'Phone',
            value:
                student.phoneNumber.trim().isEmpty ? '-' : student.phoneNumber,
          ),
          _StudentDetailField(
            label: 'Email',
            value: (student.email ?? '').trim().isEmpty ? '—' : student.email!,
          ),
        ],
      ),
    );
  }
}

class _StudentDetailTab extends StatelessWidget {
  const _StudentDetailTab({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF2563EB) : const Color(0xFF64748B);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? const Color(0xFF2563EB) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 9),
            Text(
              label,
              style: _studentFieldTextStyle.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badge!, style: _studentBadgeTextStyle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StudentDetailSectionTitle extends StatelessWidget {
  const _StudentDetailSectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: const Color(0xFF2563EB)),
        const SizedBox(width: 12),
        Text(
          label,
          style: _studentSectionTitleTextStyle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _StudentDetailInfoGridModern extends StatelessWidget {
  const _StudentDetailInfoGridModern({
    required this.student,
    required this.batch,
  });

  final _StudentRow student;
  final String batch;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = width >= 900
              ? 3
              : width >= 560
                  ? 2
                  : 1;
          final fields = [
            _StudentModernField(
              label: 'Full Name',
              value: _nameCase(student.fullName),
              icon: HugeIcons.strokeRoundedUser03,
            ),
            _StudentModernField(
              label: 'Student ID',
              value: StudentNumber.displayValue(student.studentNo),
            ),
            if (_cleanTextValue(student.sex).isNotEmpty)
              _StudentModernField(label: 'Sex', value: student.sex),
            if (_cleanTextValue(student.birthDate).isNotEmpty)
              _StudentModernField(
                label: 'Birth date',
                value: student.birthDate,
              ),
            if (_cleanTextValue(student.email ?? '').isNotEmpty)
              _StudentModernField(
                label: 'Email',
                value: student.email!,
                icon: HugeIcons.strokeRoundedMail01,
                linkStyle: true,
              ),
            if (_cleanTextValue(student.phoneNumber).isNotEmpty)
              _StudentModernField(
                label: 'Phone',
                value: student.phoneNumber,
                icon: HugeIcons.strokeRoundedTelephone,
              ),
            _StudentModernField(label: 'Program', value: student.course),
            _StudentModernField(label: 'Batch', value: batch),
            if (_cleanTextValue(student.graduationDate).isNotEmpty)
              _StudentModernField(
                label: 'Date Graduated',
                value: student.graduationDate,
                icon: HugeIcons.strokeRoundedCalendar01,
              ),
          ];

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: fields.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: 104,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              return _StudentInfoTile(child: fields[index]);
            },
          );
        },
      ),
    );
  }
}

class _StudentInfoTile extends StatelessWidget {
  const _StudentInfoTile({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }
}

class _StudentModernField extends StatelessWidget {
  const _StudentModernField({
    required this.label,
    required this.value,
    this.icon,
    this.linkStyle = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool linkStyle;

  @override
  Widget build(BuildContext context) {
    final displayValue =
        _cleanTextValue(value).isEmpty ? 'Unassigned' : _cleanTextValue(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _studentDetailLabelTextStyle),
        const SizedBox(height: 6),
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: const Color(0xFF2563EB)),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: SelectableText(
                displayValue,
                maxLines: 2,
                style: _studentFieldTextStyle.copyWith(
                  color:
                      linkStyle ? const Color(0xFF2563EB) : _studentTextBlack,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StudentDetailField extends StatelessWidget {
  const _StudentDetailField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final displayValue =
        _cleanTextValue(value).isEmpty ? '-' : _cleanTextValue(value);
    return SizedBox(
      width: MediaQuery.sizeOf(context).width < 560 ? double.infinity : 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _studentDetailLabelTextStyle),
          const SizedBox(height: 4),
          SelectableText(displayValue, style: _studentFieldTextStyle),
        ],
      ),
    );
  }
}

class _StudentDocumentsTable extends StatefulWidget {
  const _StudentDocumentsTable({
    required this.documents,
    required this.canPreviewImage,
    required this.onPreview,
    this.onEditDocument,
    this.onDeleteDocument,
    this.onDownloadDocument,
    this.onAddFiles,
  });

  final List<_DocRow> documents;
  final bool Function(_DocRow doc) canPreviewImage;
  final ValueChanged<_DocRow> onPreview;
  final ValueChanged<_DocRow>? onEditDocument;
  final ValueChanged<_DocRow>? onDeleteDocument;
  final ValueChanged<_DocRow>? onDownloadDocument;
  final Future<void> Function(List<XFile> files)? onAddFiles;

  @override
  State<_StudentDocumentsTable> createState() => _StudentDocumentsTableState();
}

class _StudentDocumentsTableState extends State<_StudentDocumentsTable> {
  bool _dragging = false;
  bool _uploading = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'gif', 'webp'],
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final files = result.files
        .where((file) => file.path != null && file.path!.trim().isNotEmpty)
        .map((file) => XFile(file.path!, name: file.name))
        .toList();
    await _addFiles(files);
  }

  Future<void> _addFiles(List<XFile> files) async {
    final onAddFiles = widget.onAddFiles;
    if (onAddFiles == null || files.isEmpty || _uploading) return;
    setState(() => _uploading = true);
    try {
      await onAddFiles(files);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final documents = widget.documents;
    final canAdd = widget.onAddFiles != null && !_uploading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              HugeIcons.strokeRoundedFile02,
              color: Color(0xFF2563EB),
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Documents',
              style: _studentSectionTitleTextStyle.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${documents.length}', style: _studentBadgeTextStyle),
            ),
            const Spacer(),
          ],
        ),
        if (widget.onAddFiles != null) ...[
          const SizedBox(height: 12),
          DropTarget(
            onDragEntered: (_) => setState(() => _dragging = true),
            onDragExited: (_) => setState(() => _dragging = false),
            onDragDone: (detail) async {
              setState(() => _dragging = false);
              await _addFiles(detail.files);
            },
            child: InkWell(
              onTap: canAdd ? _pickFiles : null,
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: _dragging
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _dragging
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFE2E8F0),
                    width: _dragging ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    _uploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            HugeIcons.strokeRoundedUpload01,
                            color: Color(0xFF2563EB),
                          ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _uploading
                            ? 'Adding document...'
                            : 'Drag and drop PDF or image files here',
                        style: _studentFieldTextStyle.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: canAdd ? _pickFiles : null,
                      icon: const Icon(HugeIcons.strokeRoundedAdd01, size: 17),
                      label: const Text('Choose files'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final tableWidth =
                constraints.maxWidth < 680 ? 680.0 : constraints.maxWidth;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      const _StudentDocumentTableHeader(),
                      if (documents.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No documents uploaded for this student yet.',
                            style: _studentMutedTextStyle,
                          ),
                        )
                      else
                        for (var i = 0; i < documents.length; i++)
                          _StudentDocumentTableRow(
                            index: i + 1,
                            doc: documents[i],
                            showDivider: i < documents.length - 1,
                            canPreview: widget.canPreviewImage(documents[i]),
                            onPreview: () => widget.onPreview(documents[i]),
                          ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 18,
                        ),
                        color: Colors.white,
                        child: Row(
                          children: [
                            Text(
                              'Showing ${documents.isEmpty ? 0 : 1} to ${documents.length} of ${documents.length} document${documents.length == 1 ? '' : 's'}',
                              style: _studentMutedTextStyle,
                            ),
                            const Spacer(),
                            OutlinedButton(
                              onPressed: null,
                              child: const Icon(
                                  HugeIcons.strokeRoundedArrowLeft01),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                                onPressed: null, child: const Text('1')),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: null,
                              child: const Icon(
                                  HugeIcons.strokeRoundedArrowRight01),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _StudentDocumentTableHeader extends StatelessWidget {
  const _StudentDocumentTableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Color(0xFF475569),
      fontSize: 12,
      fontWeight: FontWeight.w700,
    );
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      child: const Row(
        children: [
          SizedBox(width: 36, child: Text('#', style: style)),
          Expanded(flex: 4, child: Text('Document', style: style)),
          Expanded(flex: 2, child: Text('Type', style: style)),
          Expanded(flex: 2, child: Text('Tag', style: style)),
          Expanded(flex: 2, child: Text('Uploaded', style: style)),
        ],
      ),
    );
  }
}

class _StudentDocumentTableRow extends StatelessWidget {
  const _StudentDocumentTableRow({
    required this.index,
    required this.doc,
    required this.showDivider,
    required this.canPreview,
    required this.onPreview,
  });

  final int index;
  final _DocRow doc;
  final bool showDivider;
  final bool canPreview;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final tag = doc.tags.split(',').map((e) => e.trim()).firstWhere(
          (e) => e.isNotEmpty,
          orElse: () => _studentDocumentTypeLabel(doc),
        );
    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Row(
        children: [
          SizedBox(
              width: 36, child: Text('$index', style: _studentFieldTextStyle)),
          Expanded(
            flex: 4,
            child: InkWell(
              onTap: canPreview ? onPreview : null,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      _studentDocumentIcon(doc),
                      color: const Color(0xFF2563EB),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _documentDisplayName(doc),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _studentFieldTextStyle.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          doc.type,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _studentMutedTextStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _StudentDocPill(text: _studentDocumentTypeLabel(doc)),
          ),
          Expanded(flex: 2, child: _StudentDocPill(text: tag)),
          Expanded(
            flex: 2,
            child: Text(doc.uploaded, style: _studentMutedTextStyle),
          ),
        ],
      ),
    );
  }
}

class _StudentDocPill extends StatelessWidget {
  const _StudentDocPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF2563EB),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StudentDocAction extends StatelessWidget {
  const _StudentDocAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        style: IconButton.styleFrom(
          minimumSize: const Size(34, 34),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      ),
    );
  }
}

String _studentDocumentTypeLabel(_DocRow doc) {
  if (doc.documentType.trim().isNotEmpty) return doc.documentType.trim();
  final ext = p.extension(doc.title).replaceFirst('.', '').trim();
  if (ext.isNotEmpty) return ext.toUpperCase();
  if (doc.type.contains('/')) return doc.type.split('/').last.toUpperCase();
  return doc.type.trim().isEmpty ? 'Other' : doc.type;
}

IconData _studentDocumentIcon(_DocRow doc) {
  final type = doc.type.toLowerCase();
  if (type.startsWith('image/')) return HugeIcons.strokeRoundedImage01;
  if (type.contains('pdf')) return HugeIcons.strokeRoundedPdf01;
  if (type.contains('word')) return HugeIcons.strokeRoundedFile02;
  if (type.contains('excel') || type.contains('spreadsheet')) {
    return HugeIcons.strokeRoundedTable;
  }
  return HugeIcons.strokeRoundedFile01;
}

class _StudentDocListTile extends StatelessWidget {
  const _StudentDocListTile({
    required this.doc,
    required this.showDivider,
    required this.canPreview,
    required this.onPreview,
  });

  final _DocRow doc;
  final bool showDivider;
  final bool canPreview;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Icon(
            HugeIcons.strokeRoundedFile02,
            size: 18,
            color: Color(0xFF64748B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _documentDisplayName(doc),
                  style: _studentFieldTextStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${doc.type} · ${doc.uploaded}',
                  style: _studentSubtitleTextStyle.copyWith(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (canPreview)
            IconButton(
              onPressed: onPreview,
              tooltip: 'Preview',
              icon: Icon(
                _isPdfDocument(doc)
                    ? HugeIcons.strokeRoundedPdf01
                    : HugeIcons.strokeRoundedImage01,
                size: 18,
                color: const Color(0xFF16A34A),
              ),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _StudentCell extends StatelessWidget {
  const _StudentCell({
    required this.flex,
    required this.text,
    this.bold = false,
  });

  final int flex;
  final String text;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: _studentFieldTextStyle.copyWith(
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _StudentDocumentCard extends StatefulWidget {
  const _StudentDocumentCard({
    required this.index,
    required this.draft,
    required this.documentTypes,
    required this.onRemove,
    required this.onPickDate,
    required this.onPickFile,
    required this.onChanged,
  });

  final int index;
  final _StudentDocumentDraft draft;
  final List<String> documentTypes;
  final VoidCallback onRemove;
  final VoidCallback onPickDate;
  final VoidCallback onPickFile;
  final VoidCallback onChanged;

  @override
  State<_StudentDocumentCard> createState() => _StudentDocumentCardState();
}

class _StudentDocumentCardState extends State<_StudentDocumentCard> {
  late final TextEditingController _titleController;
  late final TextEditingController _tagsController;
  late final TextEditingController _remarksController;
  late final TextEditingController _receivedController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.draft.title);
    _tagsController = TextEditingController(text: widget.draft.tags);
    _remarksController = TextEditingController(text: widget.draft.remarks);
    _receivedController = TextEditingController(
      text: _formatDate(widget.draft.receivedAt),
    );
  }

  @override
  void didUpdateWidget(covariant _StudentDocumentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft.receivedAt != widget.draft.receivedAt) {
      _receivedController.text = _formatDate(widget.draft.receivedAt);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagsController.dispose();
    _remarksController.dispose();
    _receivedController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final fileName = draft.fileName?.trim() ?? '';
    final filePath = draft.filePath?.trim() ?? '';
    final hasFile = fileName.isNotEmpty || filePath.isNotEmpty;
    final fileLabel = fileName.isNotEmpty ? fileName : p.basename(filePath);
    final fileExtension = filePath.isEmpty ? '-' : p.extension(filePath);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Text(
                  'Student document: #${widget.index}',
                  style: _studentDocumentTitleTextStyle,
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(HugeIcons.strokeRoundedDelete02,
                      color: Color(0xFFDC2626)),
                  tooltip: 'Remove document',
                ),
              ],
            ),
          ),
          _StudentLabeledField(
            label: 'Title',
            required: true,
            child: TextField(
              controller: _titleController,
              style: _studentInputTextStyle,
              onChanged: (v) {
                draft.title = v;
                widget.onChanged();
              },
              decoration: _studentInputDecoration(hint: 'Document title'),
            ),
          ),
          _StudentLabeledField(
            label: 'Tags',
            child: TextField(
              controller: _tagsController,
              style: _studentInputTextStyle,
              onChanged: (v) {
                draft.tags = v;
                widget.onChanged();
              },
              decoration: _studentInputDecoration(
                hint: 'Comma-separated tags',
              ),
            ),
          ),
          _StudentLabeledField(
            label: 'Document type',
            required: true,
            child: DropdownButtonFormField<String>(
              initialValue: draft.documentType,
              style: _studentInputTextStyle,
              decoration: _studentInputDecoration(),
              dropdownColor: Colors.white,
              items: widget.documentTypes
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t, style: _studentInputTextStyle),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => draft.documentType = v);
                widget.onChanged();
              },
            ),
          ),
          _StudentLabeledField(
            label: 'File',
            required: true,
            child: InkWell(
              onTap: widget.onPickFile,
              child: InputDecorator(
                decoration: _studentInputDecoration(
                  hint: 'Choose file to upload',
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasFile ? fileLabel : 'Choose file to upload',
                        overflow: TextOverflow.ellipsis,
                        style: hasFile
                            ? _studentInputTextStyle
                            : _studentHintTextStyle,
                      ),
                    ),
                    Icon(
                      HugeIcons.strokeRoundedFileUpload,
                      size: 20,
                      color: hasFile ? _collegeTeal : _studentTextMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          _StudentLabeledField(
            label: 'Open',
            child: Text(
              hasFile ? 'Use View docs or See all after save.' : '-',
              style: _studentMutedTextStyle,
            ),
          ),
          _StudentLabeledField(
            label: 'Viewer',
            child: Text(
              hasFile
                  ? 'Documents are grouped by student after save.'
                  : 'Choose a file to upload.',
              style: _studentMutedTextStyle,
            ),
          ),
          _StudentLabeledField(
            label: 'Format',
            child: Text(
              fileExtension == '-' ? '-' : fileExtension.toUpperCase(),
              style: hasFile
                  ? _studentInputTextStyle
                  : _studentFieldTextStyle.copyWith(color: _studentTextMuted),
            ),
          ),
          _StudentLabeledField(
            label: 'Received at',
            required: true,
            child: TextField(
              readOnly: true,
              onTap: widget.onPickDate,
              controller: _receivedController,
              style: _studentInputTextStyle,
              decoration: _studentInputDecoration().copyWith(
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (draft.receivedAt == null)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          HugeIcons.strokeRoundedAlert01,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                      ),
                    IconButton(
                      tooltip: 'Pick date',
                      onPressed: widget.onPickDate,
                      icon: const Icon(
                        HugeIcons.strokeRoundedCalendar01,
                        size: 18,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _StudentLabeledField(
            label: 'Uploaded by',
            child: Text('—', style: _studentMutedTextStyle),
          ),
          _StudentLabeledField(
            label: 'Remarks',
            child: TextField(
              controller: _remarksController,
              maxLines: 4,
              style: _studentInputTextStyle,
              onChanged: (v) {
                draft.remarks = v;
                widget.onChanged();
              },
              decoration: _studentInputDecoration(hint: 'Optional notes'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _StudentDepartmentProgramFilterBar extends StatelessWidget {
  const _StudentDepartmentProgramFilterBar({
    required this.department,
    required this.program,
    required this.status,
    required this.departments,
    required this.programs,
    required this.statuses,
    required this.sortSelection,
    required this.onDepartmentChanged,
    required this.onProgramChanged,
    required this.onStatusChanged,
    required this.onSortChanged,
    this.onClear,
  });

  final String? department;
  final String? program;
  final String? status;
  final List<String> departments;
  final List<String> programs;
  final List<String> statuses;
  final String sortSelection;
  final ValueChanged<String?> onDepartmentChanged;
  final ValueChanged<String?> onProgramChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onSortChanged;
  final VoidCallback? onClear;

  static const _filterDecoration = InputDecoration(
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: _RecordListTheme.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: Color(0xFF2563EB), width: 1.5),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: _RecordListTheme.border),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackFilters = constraints.maxWidth < 720;
          final departmentField = _buildFilterField(
            label: 'Department',
            icon: HugeIcons.strokeRoundedUniversity,
            child: DropdownButtonFormField<String?>(
              key: ValueKey('department:${department ?? 'all'}'),
              initialValue: department,
              isExpanded: true,
              menuMaxHeight: _studentSelectorMenuMaxHeight,
              borderRadius: BorderRadius.circular(8),
              style: _studentFilterDropdownTextStyle,
              decoration: _filterDecoration.copyWith(
                prefixIcon: const Icon(
                  HugeIcons.strokeRoundedUniversity,
                  size: 18,
                  color: _RecordListTheme.textHint,
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
              ),
              dropdownColor: Colors.white,
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'All departments',
                    style: _studentFilterDropdownTextStyle,
                  ),
                ),
                ...departments.map(
                  (d) => DropdownMenuItem<String?>(
                    value: d,
                    child: Text(
                      d,
                      overflow: TextOverflow.ellipsis,
                      style: _studentFilterDropdownTextStyle,
                    ),
                  ),
                ),
              ],
              onChanged: onDepartmentChanged,
            ),
          );
          final programField = _buildFilterField(
            label: 'Program',
            icon: HugeIcons.strokeRoundedSchool,
            child: DropdownButtonFormField<String?>(
              key: ValueKey('program:${program ?? 'all'}'),
              initialValue: program != null && programs.contains(program)
                  ? program
                  : null,
              isExpanded: true,
              menuMaxHeight: _studentSelectorMenuMaxHeight,
              borderRadius: BorderRadius.circular(8),
              style: _studentFilterDropdownTextStyle,
              decoration: _filterDecoration.copyWith(
                prefixIcon: const Icon(
                  HugeIcons.strokeRoundedSchool,
                  size: 18,
                  color: _RecordListTheme.textHint,
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
              ),
              dropdownColor: Colors.white,
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'All programs',
                    style: _studentFilterDropdownTextStyle,
                  ),
                ),
                ...programs.map(
                  (p) => DropdownMenuItem<String?>(
                    value: p,
                    child: Text(
                      p,
                      overflow: TextOverflow.ellipsis,
                      style: _studentFilterDropdownTextStyle,
                    ),
                  ),
                ),
              ],
              onChanged: onProgramChanged,
            ),
          );
          final statusField = _buildFilterField(
            label: 'AY',
            icon: HugeIcons.strokeRoundedCalendar03,
            child: DropdownButtonFormField<String?>(
              key: ValueKey('academic-year:${status ?? 'all'}'),
              initialValue:
                  status != null && statuses.contains(status) ? status : null,
              isExpanded: true,
              style: _studentFilterDropdownTextStyle,
              decoration: _filterDecoration.copyWith(
                prefixIcon: const Icon(
                  HugeIcons.strokeRoundedCalendar03,
                  size: 18,
                  color: _RecordListTheme.textHint,
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
              ),
              dropdownColor: Colors.white,
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'All AY',
                    style: _studentFilterDropdownTextStyle,
                  ),
                ),
                ...statuses.map(
                  (item) => DropdownMenuItem<String?>(
                    value: item,
                    child: Text(
                      item,
                      overflow: TextOverflow.ellipsis,
                      style: _studentFilterDropdownTextStyle,
                    ),
                  ),
                ),
              ],
              onChanged: onStatusChanged,
            ),
          );
          final sortField = _buildFilterField(
            label: 'Sort by',
            icon: HugeIcons.strokeRoundedSorting01,
            child: DropdownButtonFormField<String>(
              key: ValueKey('sort:$sortSelection'),
              initialValue: sortSelection,
              isExpanded: true,
              style: _studentFilterDropdownTextStyle,
              decoration: _filterDecoration,
              dropdownColor: Colors.white,
              items: const [
                DropdownMenuItem(
                  value: 'studentNo:asc',
                  child: Text('Student no. (ascending)'),
                ),
                DropdownMenuItem(
                  value: 'studentNo:desc',
                  child: Text('Student no. (descending)'),
                ),
                DropdownMenuItem(
                  value: 'name:asc',
                  child: Text('Name (A–Z)'),
                ),
                DropdownMenuItem(
                  value: 'name:desc',
                  child: Text('Name (Z–A)'),
                ),
                DropdownMenuItem(
                  value: 'program:asc',
                  child: Text('Program (A–Z)'),
                ),
                DropdownMenuItem(
                  value: 'program:desc',
                  child: Text('Program (Z–A)'),
                ),
                DropdownMenuItem(
                  value: 'batch:asc',
                  child: Text('Batch (oldest first)'),
                ),
                DropdownMenuItem(
                  value: 'batch:desc',
                  child: Text('Batch (newest first)'),
                ),
              ],
              onChanged: onSortChanged,
            ),
          );

          final fullWidth = constraints.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SizedBox(
                width: stackFilters ? fullWidth : 220,
                child: departmentField,
              ),
              SizedBox(
                width: stackFilters ? fullWidth : 280,
                child: programField,
              ),
              SizedBox(
                width: stackFilters ? fullWidth : 170,
                child: statusField,
              ),
              SizedBox(
                width: stackFilters ? fullWidth : 230,
                child: sortField,
              ),
              if (onClear != null) _buildClearButton(onClear!),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterField({
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: _RecordListTheme.textMuted),
            const SizedBox(width: 6),
            Text(label, style: _studentFilterLabelTextStyle),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildClearButton(VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(HugeIcons.strokeRoundedFilterRemove, size: 16),
      label: const Text('Clear'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _RecordListTheme.textPrimary,
        side: const BorderSide(color: _RecordListTheme.border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _StudentActiveFilterSummary extends StatelessWidget {
  const _StudentActiveFilterSummary({
    required this.department,
    required this.program,
    required this.status,
    required this.searchQuery,
    required this.resultCount,
    required this.totalCount,
  });

  final String? department;
  final String? program;
  final String? status;
  final String searchQuery;
  final int resultCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (department != null && department!.isNotEmpty) {
      chips.add(_StudentFilterChip(
        label: _shortDepartmentLabel(department!),
        icon: HugeIcons.strokeRoundedUniversity,
      ));
    }
    if (program != null && program!.isNotEmpty) {
      chips.add(_StudentFilterChip(
        label: program!,
        icon: HugeIcons.strokeRoundedSchool,
      ));
    }
    if (status != null && status!.isNotEmpty) {
      chips.add(_StudentFilterChip(
        label: status!,
        icon: HugeIcons.strokeRoundedCalendar03,
      ));
    }
    if (searchQuery.isNotEmpty) {
      chips.add(_StudentFilterChip(
        label: 'Search: $searchQuery',
        icon: HugeIcons.strokeRoundedSearch01,
      ));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFEFF6FF),
        border: Border(
          bottom: BorderSide(color: _RecordListTheme.border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: chips,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$resultCount of $totalCount',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2563EB),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentFilterChip extends StatelessWidget {
  const _StudentFilterChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF2563EB)),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _RecordListTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
