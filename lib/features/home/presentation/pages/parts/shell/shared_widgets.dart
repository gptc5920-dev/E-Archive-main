part of '../../dashboard_shell_page.dart';

Future<void> _showResizableDocumentViewer(
  BuildContext context, {
  required _DocRow document,
}) {
  final localPath = _localPreviewPath(document);
  final remoteUrl = document.remoteImageUrl.trim();
  return showDialog<void>(
    context: context,
    builder: (_) => _ResizableDocumentViewerDialog(
      document: document,
      title: _documentDisplayName(document),
      localPath: localPath,
      remoteUrl: remoteUrl,
    ),
  );
}

String _documentDisplayName(_DocRow doc) {
  final title = doc.title.trim();
  final cleanedTitle = _basenameOnly(title);
  if (cleanedTitle.isNotEmpty) return cleanedTitle;

  final localPath = doc.localFilePath?.trim() ?? '';
  final cleanedPath = _basenameOnly(localPath);
  return cleanedPath.isEmpty ? 'Untitled Document' : cleanedPath;
}

bool _documentMatchesSearch(
  _DocRow doc,
  String query, {
  Iterable<String> additionalValues = const [],
}) {
  final terms = query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty)
      .toList();
  if (terms.isEmpty) return true;

  final localPath = doc.localFilePath?.trim() ?? '';
  final localImagePath = doc.localImagePath?.trim() ?? '';
  final remotePath = Uri.tryParse(doc.remoteImageUrl)?.path ?? '';
  final searchableText = <String>[
    _documentDisplayName(doc),
    doc.id,
    doc.title,
    doc.student,
    doc.type,
    doc.size,
    doc.uploaded,
    doc.schoolYear,
    doc.studentNo,
    doc.program,
    doc.college,
    doc.documentType,
    doc.storagePath,
    doc.tags,
    doc.uploader,
    doc.deletedAt,
    doc.deletedBy,
    localPath,
    _basenameOnly(localPath),
    localImagePath,
    _basenameOnly(localImagePath),
    doc.remoteImageUrl,
    _basenameOnly(remotePath),
    ...additionalValues,
  ].join('\n').toLowerCase();

  // Terms may match different fields, for example a student name followed by
  // a document type or filename.
  return terms.every(searchableText.contains);
}

String _basenameOnly(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  final normalized = trimmed.replaceAll(r'\', '/');
  final base = p.posix.basename(normalized).trim();
  return base == '.' ? trimmed : base;
}

bool _isPdfDocument(_DocRow doc) {
  final type = doc.type.toLowerCase();
  final titleExt = p.extension(doc.title).toLowerCase();
  final pathExt = p.extension(doc.localFilePath?.trim() ?? '').toLowerCase();
  return type.contains('pdf') || titleExt == '.pdf' || pathExt == '.pdf';
}

bool _isImageDocument(_DocRow doc) {
  final type = doc.type.toLowerCase();
  return type.contains('image/') ||
      (doc.localImagePath?.trim().isNotEmpty ?? false) ||
      doc.remoteImageUrl.trim().isNotEmpty;
}

bool _canPreviewDocument(_DocRow doc) {
  final path = doc.localFilePath?.trim() ?? '';
  return _isImageDocument(doc) || (_isPdfDocument(doc) && path.isNotEmpty);
}

String _localPreviewPath(_DocRow doc) {
  if (_isPdfDocument(doc)) return doc.localFilePath?.trim() ?? '';
  return doc.localImagePath?.trim() ?? doc.localFilePath?.trim() ?? '';
}

Future<Uint8List> _readDocumentBytes({
  required String localPath,
  required String remoteUrl,
}) async {
  if (localPath.isNotEmpty) {
    final file = File(localPath);
    if (!await file.exists()) {
      throw FileSystemException('File was not found', localPath);
    }
    return file.readAsBytes();
  }

  if (remoteUrl.isEmpty) {
    throw const FileSystemException('No local or remote file is available');
  }

  final uri = Uri.parse(remoteUrl);
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Server returned ${response.statusCode}',
        uri: uri,
      );
    }
    final buffer = BytesBuilder(copy: false);
    await for (final chunk in response) {
      buffer.add(chunk);
    }
    return buffer.takeBytes();
  } finally {
    client.close(force: true);
  }
}

Future<Uint8List> _buildPrintableImagePdf(
  Uint8List imageBytes,
  PdfPageFormat format,
) async {
  final pdf = pw.Document();
  final image = pw.MemoryImage(imageBytes);
  pdf.addPage(
    pw.Page(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => pw.Center(
        child: pw.Image(image, fit: pw.BoxFit.contain),
      ),
    ),
  );
  return pdf.save();
}

String _printablePdfName(_DocRow document) {
  var name = _documentDisplayName(document).trim();
  if (name.isEmpty) name = 'document';
  name = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  return p.extension(name).toLowerCase() == '.pdf' ? name : '$name.pdf';
}

Future<File> _writePrintablePdfTempFile({
  required _DocRow document,
  required Uint8List pdfBytes,
}) async {
  final fileName =
      '${DateTime.now().microsecondsSinceEpoch}_${_printablePdfName(document)}';
  final file = File(p.join(Directory.systemTemp.path, fileName));
  await file.writeAsBytes(pdfBytes, flush: true);
  return file;
}

Future<void> _openPdfWithSystemViewer(File file) async {
  if (Platform.isWindows) {
    await Process.start('cmd', ['/c', 'start', '', file.path]);
    return;
  }
  if (Platform.isMacOS) {
    await Process.start('open', [file.path]);
    return;
  }
  if (Platform.isLinux) {
    await Process.start('xdg-open', [file.path]);
  }
}

Future<void> _openPrintablePdfFallback({
  required _DocRow document,
  required Uint8List pdfBytes,
}) async {
  final file = await _writePrintablePdfTempFile(
    document: document,
    pdfBytes: pdfBytes,
  );
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await _openPdfWithSystemViewer(file);
    return;
  }

  final opened = await Printing.sharePdf(
    bytes: pdfBytes,
    filename: p.basename(file.path),
  );
  if (!opened) throw StateError('Could not open the printable PDF.');
}

Future<void> _printDocument(
  BuildContext context, {
  required _DocRow document,
}) async {
  final isPdf = _isPdfDocument(document);
  final isImage = _isImageDocument(document);
  if (!isPdf && !isImage) {
    _showInfo(context, 'Printing is available for PDFs and images.');
    return;
  }

  final localPath = _localPreviewPath(document);
  final remoteUrl = document.remoteImageUrl.trim();
  try {
    final sourceBytes = await _readDocumentBytes(
      localPath: localPath,
      remoteUrl: isImage ? remoteUrl : '',
    );
    final printableBytes = isPdf
        ? sourceBytes
        : await _buildPrintableImagePdf(sourceBytes, PdfPageFormat.a4);

    final result = await printDocumentWithFallback(
      name: _printablePdfName(document),
      onLayout: (format) async {
        if (isPdf) return sourceBytes;
        return _buildPrintableImagePdf(sourceBytes, format);
      },
      openFallback: () => _openPrintablePdfFallback(
        document: document,
        pdfBytes: printableBytes,
      ),
    );
    if (!context.mounted) return;
    if (result == DocumentPrintResult.openedFallback) {
      _showInfo(
        context,
        'Could not print directly. Opened PDF; use Print in the PDF viewer.',
      );
    }
  } catch (error) {
    if (!context.mounted) return;
    _showInfo(context, 'Could not print or open document: $error');
  }
}

Future<void> _openPdfDocumentRefInSystemViewer(
  BuildContext context,
  PdfDocumentRef documentRef,
) async {
  final path = documentRef is PdfDocumentRefFile ? documentRef.file : '';
  if (path.isEmpty) {
    _showInfo(context, 'No local PDF file is available.');
    return;
  }

  try {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('File was not found', path);
    }
    await _openPdfWithSystemViewer(file);
  } catch (error) {
    if (!context.mounted) return;
    _showInfo(context, 'Could not open PDF in the system reader: $error');
  }
}

Widget _buildPdfErrorBanner(
  BuildContext context,
  Object error,
  StackTrace? stackTrace,
  PdfDocumentRef documentRef,
) {
  final message = error is PdfPasswordException
      ? 'The embedded Windows viewer could not open this PDF. This can be a '
          'viewer compatibility issue even when the file has no password.'
      : 'The PDF may be damaged, incomplete, or use a format that is not '
          'supported by the embedded viewer.';

  return ColoredBox(
    color: const Color(0xFFF8FAFC),
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.picture_as_pdf_outlined,
                size: 54,
                color: Color(0xFFDC2626),
              ),
              const SizedBox(height: 14),
              const Text(
                'Could not open this PDF',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  height: 1.45,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Try the installed PDF reader. If it opens there, you can '
                'continue using that reader or export a compatible copy.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: documentRef is PdfDocumentRefFile
                    ? () => _openPdfDocumentRefInSystemViewer(
                          context,
                          documentRef,
                        )
                    : null,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open in system PDF reader'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ResizableDocumentViewerDialog extends StatefulWidget {
  const _ResizableDocumentViewerDialog({
    required this.document,
    required this.title,
    required this.localPath,
    required this.remoteUrl,
  });

  final _DocRow document;
  final String title;
  final String localPath;
  final String remoteUrl;

  @override
  State<_ResizableDocumentViewerDialog> createState() =>
      _ResizableDocumentViewerDialogState();
}

class _ResizableDocumentViewerDialogState
    extends State<_ResizableDocumentViewerDialog> {
  double _width = 920;
  double _height = 640;
  bool _downloading = false;
  bool _printing = false;

  bool get _isPdf => _isPdfDocument(widget.document);

  String get _downloadName {
    var name = widget.title.trim();
    if (name.isEmpty) name = _isPdf ? 'document' : 'image';
    name = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    if (p.extension(name).isEmpty) {
      final remoteExtension = p.extension(
        Uri.tryParse(widget.remoteUrl)?.path ?? '',
      );
      name += remoteExtension.isEmpty
          ? (_isPdf ? '.pdf' : '.png')
          : remoteExtension;
    }
    return name;
  }

  Future<void> _download() async {
    if (_downloading) return;
    final target = await FilePicker.platform.saveFile(
      dialogTitle: _isPdf ? 'Save PDF' : 'Save image',
      fileName: _downloadName,
    );
    if (target == null || !mounted) return;

    setState(() => _downloading = true);
    try {
      if (widget.localPath.isNotEmpty) {
        await File(widget.localPath).copy(target);
      } else {
        final client = HttpClient();
        try {
          final request = await client.getUrl(Uri.parse(widget.remoteUrl));
          final response = await request.close();
          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw HttpException(
              'Server returned ${response.statusCode}',
              uri: Uri.parse(widget.remoteUrl),
            );
          }
          await response.pipe(File(target).openWrite());
        } finally {
          client.close(force: true);
        }
      }
      if (!mounted) return;
      _showInfo(
        context,
        _isPdf
            ? 'PDF downloaded successfully.'
            : 'Image downloaded successfully.',
      );
    } catch (error) {
      if (!mounted) return;
      _showInfo(context, 'Could not download file: $error');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _print() async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      await _printDocument(context, document: widget.document);
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Widget _buildPreview() {
    final previewKey = ValueKey(
      '${widget.document.id}|${widget.localPath}|${widget.remoteUrl}',
    );
    if (_isPdf) {
      if (widget.localPath.isEmpty) {
        return const Center(child: Text('No local PDF file is available.'));
      }
      return PdfViewer.file(
        key: previewKey,
        widget.localPath,
        params: const PdfViewerParams(
          margin: 12,
          backgroundColor: Color(0xFFF8FAFC),
          errorBannerBuilder: _buildPdfErrorBanner,
        ),
      );
    }

    return InteractiveViewer(
      minScale: 0.6,
      maxScale: 6,
      child: Center(
        child: widget.localPath.isNotEmpty
            ? Image.file(
                key: previewKey,
                File(widget.localPath),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text(
                  'Could not load local image.',
                ),
              )
            : Image.network(
                key: previewKey,
                widget.remoteUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text(
                  'Could not load image from server.',
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final maxWidth = math.max(280.0, screen.width - 32);
    final maxHeight = math.max(240.0, screen.height - 32);
    final minWidth = math.min(440.0, maxWidth);
    final minHeight = math.min(320.0, maxHeight);
    final width = _width.clamp(minWidth, maxWidth);
    final height = _height.clamp(minHeight, maxHeight);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
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
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: _downloading ? null : _download,
                          tooltip: _isPdf ? 'Download PDF' : 'Download image',
                          icon: _downloading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(HugeIcons.strokeRoundedDownload01,
                                  size: 21),
                        ),
                        IconButton(
                          onPressed: _printing ? null : _print,
                          tooltip: _isPdf ? 'Print PDF' : 'Print image',
                          icon: _printing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(HugeIcons.strokeRoundedPrinter,
                                  size: 21),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Close',
                          icon: const Icon(HugeIcons.strokeRoundedCancel01,
                              size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _buildPreview(),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Drag the bottom-right corner to resize',
                      style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) {
                    setState(() {
                      _width =
                          (_width + details.delta.dx).clamp(minWidth, maxWidth);
                      _height = (_height + details.delta.dy)
                          .clamp(minHeight, maxHeight);
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
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF2563EB), size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DashedBox extends StatelessWidget {
  const _DashedBox({required this.height, required this.child});
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E8EB), width: 2),
      ),
      child: child,
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155))),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2563EB)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF475569), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

@Deprecated('Use _RecordDataTable inside _RecordListCard')
class _TableCard extends StatelessWidget {
  const _TableCard({required this.headers, required this.rows});
  final List<String> headers;
  final List<List<Widget>> rows;

  @override
  Widget build(BuildContext context) {
    return _RecordDataTable(headers: headers, rows: rows);
  }
}
