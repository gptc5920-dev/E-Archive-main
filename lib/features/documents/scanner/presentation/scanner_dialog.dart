import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/scanner_models.dart';
import '../services/scanner_service.dart';

class ScannerDialog extends StatefulWidget {
  const ScannerDialog({
    super.key,
    this.service,
    this.combinedPdfOnly = false,
  });

  final ScannerService? service;
  final bool combinedPdfOnly;

  @override
  State<ScannerDialog> createState() => _ScannerDialogState();
}

class _ScannerDialogState extends State<ScannerDialog> {
  late final ScannerService _service = widget.service ?? ScannerService();
  final _fileNameController = TextEditingController(text: 'Scanned document');
  final List<ScannedPage> _pages = [];
  Directory? _sessionDirectory;
  List<ScannerDevice> _devices = const [];
  ScannerDevice? _device;
  ScannerSettings _settings = const ScannerSettings();
  ScannerOutputFormat _format = ScannerOutputFormat.combinedPdf;
  int _selectedPage = -1;
  int _estimatedBytes = 0;
  bool _discovering = true;
  bool _scanning = false;
  bool _creatingOutput = false;
  bool _handedOff = false;
  String? _error;

  bool get _busy => _discovering || _scanning || _creatingOutput;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    final directory = _sessionDirectory;
    if (!_handedOff && directory != null) _service.cleanup(directory);
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final directory = await _service.createSessionDirectory();
      if (!mounted) {
        await _service.cleanup(directory);
        return;
      }
      _sessionDirectory = directory;
      await _refreshDevices();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _discovering = false;
        _error = '$error';
      });
    }
  }

  Future<void> _refreshDevices() async {
    setState(() {
      _discovering = true;
      _error = null;
    });
    try {
      final devices = await _service.discoverDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _device = devices.where((item) => item.id == _device?.id).firstOrNull ??
            (devices.isEmpty ? null : devices.first);
        _discovering = false;
        if (_device != null &&
            (_settings.dpi < _device!.minimumDpi ||
                _settings.dpi > _device!.maximumDpi)) {
          _settings = _settings.copyWith(
            dpi: [150, 200, 300, 600]
                    .where(
                      (dpi) =>
                          dpi >= _device!.minimumDpi &&
                          dpi <= _device!.maximumDpi,
                    )
                    .firstOrNull ??
                _device!.minimumDpi,
            duplex: false,
          );
        }
        if (devices.isEmpty) {
          _error = 'No USB scanner was detected. Connect the scanner, install '
              'its Windows WIA driver, and select Refresh.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _devices = const [];
        _device = null;
        _discovering = false;
        _error = '$error';
      });
    }
  }

  Future<void> _scanPage() async {
    final device = _device;
    final directory = _sessionDirectory;
    if (device == null || directory == null || _scanning) return;
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final page = await _service.scanPage(
        device: device,
        settings: _settings,
        sessionDirectory: directory,
      );
      if (!mounted) return;
      _pages.add(page);
      _selectedPage = _pages.length - 1;
      await _updateEstimatedSize();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _rotateSelected(bool right) async {
    if (_selectedPage < 0 || _selectedPage >= _pages.length || _busy) return;
    setState(() => _creatingOutput = true);
    try {
      final page = await _service.rotatePage(
        _pages[_selectedPage],
        right: right,
      );
      if (!mounted) return;
      setState(() => _pages[_selectedPage] = page);
      await _updateEstimatedSize();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _creatingOutput = false);
    }
  }

  Future<void> _deletePage(int index) async {
    if (index < 0 || index >= _pages.length || _busy) return;
    final page = _pages.removeAt(index);
    try {
      if (await page.file.exists()) await page.file.delete();
    } catch (_) {}
    if (_pages.isEmpty) {
      _selectedPage = -1;
    } else {
      _selectedPage = _selectedPage.clamp(0, _pages.length - 1);
    }
    await _updateEstimatedSize();
  }

  Future<void> _clearPages() async {
    final pages = List<ScannedPage>.from(_pages);
    _pages.clear();
    _selectedPage = -1;
    setState(() {});
    for (final page in pages) {
      try {
        if (await page.file.exists()) await page.file.delete();
      } catch (_) {}
    }
    await _updateEstimatedSize();
  }

  Future<void> _updateEstimatedSize() async {
    var bytes = 0;
    for (final page in _pages) {
      try {
        bytes += await page.file.length();
      } catch (_) {}
    }
    if (mounted) setState(() => _estimatedBytes = bytes);
  }

  Future<void> _saveToUploadList() async {
    final device = _device;
    final directory = _sessionDirectory;
    if (_pages.isEmpty || device == null || directory == null || _busy) return;
    setState(() {
      _creatingOutput = true;
      _error = null;
    });
    try {
      final output = await _service.createOutput(
        pages: _pages,
        sessionDirectory: directory,
        format:
            widget.combinedPdfOnly ? ScannerOutputFormat.combinedPdf : _format,
        fileName: _fileNameController.text,
        device: device,
        settings: _settings,
      );
      if (!mounted) return;
      _handedOff = true;
      Navigator.of(context).pop(output);
    } catch (error) {
      if (mounted) {
        setState(() {
          _creatingOutput = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _cancel() async {
    if (_busy) return;
    final directory = _sessionDirectory;
    _handedOff = true;
    if (directory != null) await _service.cleanup(directory);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedPage >= 0 && _selectedPage < _pages.length
        ? _pages[_selectedPage]
        : null;
    return PopScope(
      canPop: !_busy,
      child: Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 800),
          child: Column(
            children: [
              _buildHeader(),
              if (_error != null) _buildError(),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 310, child: _buildSettings()),
                    const VerticalDivider(width: 1),
                    Expanded(child: _buildPreview(selected)),
                  ],
                ),
              ),
              const Divider(height: 1),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      child: Row(
        children: [
          const Icon(Icons.document_scanner_outlined, color: Color(0xFF0F766E)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Scan from USB scanner',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Close scanner',
            onPressed: _busy ? null : _cancel,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF7ED),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFC2410C)),
          const SizedBox(width: 10),
          Expanded(child: Text(_error!)),
        ],
      ),
    );
  }

  Widget _buildSettings() {
    final device = _device;
    final supportedDpis = [150, 200, 300, 600]
        .where(
          (dpi) =>
              device == null ||
              (dpi >= device.minimumDpi && dpi <= device.maximumDpi),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text('Scanner selection',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: ValueKey(_device?.id),
          initialValue: _device?.id,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'USB scanner',
            prefixIcon: Icon(Icons.scanner_outlined),
          ),
          items: _devices
              .map(
                (item) => DropdownMenuItem(
                  value: item.id,
                  child: Text(item.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: _busy
              ? null
              : (id) => setState(() {
                    _device =
                        _devices.where((item) => item.id == id).firstOrNull;
                    if (!(_device?.supportsDuplex ?? false)) {
                      _settings = _settings.copyWith(duplex: false);
                    }
                  }),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _refreshDevices,
          icon: _discovering
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: const Text('Refresh scanners'),
        ),
        const SizedBox(height: 20),
        Text('Scan settings', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        DropdownButtonFormField<ScannerColorMode>(
          key: ValueKey(_settings.colorMode),
          initialValue: _settings.colorMode,
          decoration: const InputDecoration(labelText: 'Color mode'),
          items: ScannerColorMode.values
              .map(
                (mode) => DropdownMenuItem(
                  value: mode,
                  child: Text(_colorModeLabel(mode)),
                ),
              )
              .toList(),
          onChanged: _busy
              ? null
              : (value) => setState(
                    () => _settings = _settings.copyWith(colorMode: value),
                  ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          key: ValueKey(_settings.dpi),
          initialValue:
              supportedDpis.contains(_settings.dpi) ? _settings.dpi : null,
          decoration: const InputDecoration(labelText: 'Resolution'),
          items: supportedDpis
              .map((dpi) =>
                  DropdownMenuItem(value: dpi, child: Text('$dpi DPI')))
              .toList(),
          onChanged: _busy
              ? null
              : (value) =>
                  setState(() => _settings = _settings.copyWith(dpi: value)),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<ScannerPaperSize>(
          key: ValueKey(_settings.paperSize),
          initialValue: _settings.paperSize,
          decoration: const InputDecoration(labelText: 'Paper size'),
          items: ScannerPaperSize.values
              .map(
                (size) => DropdownMenuItem(
                  value: size,
                  child: Text(size.name.toUpperCase()),
                ),
              )
              .toList(),
          onChanged: _busy
              ? null
              : (value) => setState(
                    () => _settings = _settings.copyWith(paperSize: value),
                  ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Multi-page scanning'),
          subtitle: const Text('Scan additional pages into this session'),
          value: _settings.multiPage,
          onChanged: _busy
              ? null
              : (value) => setState(
                    () => _settings = _settings.copyWith(multiPage: value),
                  ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Duplex'),
          subtitle: Text(
            device?.supportsDuplex == true
                ? 'Scan both sides using the feeder'
                : 'Not reported by this scanner driver',
          ),
          value: _settings.duplex,
          onChanged: _busy || device?.supportsDuplex != true
              ? null
              : (value) => setState(
                    () => _settings = _settings.copyWith(duplex: value),
                  ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: device == null || _busy ? null : _scanPage,
          icon: _scanning
              ? const SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.document_scanner_outlined),
          label: Text(_pages.isEmpty ? 'Scan page' : 'Scan another page'),
        ),
      ],
    );
  }

  Widget _buildPreview(ScannedPage? selected) {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: const Color(0xFFF1F5F9),
            child: selected == null
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.scanner_outlined,
                            size: 52, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('Scanned page preview will appear here'),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      Positioned.fill(
                        child: InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 5,
                          child: Center(
                            child: Image.file(
                              selected.file,
                              key: ValueKey(
                                '${selected.id}-${selected.revision}-${selected.file.path}',
                              ),
                              cacheWidth: 1600,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Card(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Rotate left',
                                onPressed:
                                    _busy ? null : () => _rotateSelected(false),
                                icon: const Icon(Icons.rotate_left),
                              ),
                              IconButton(
                                tooltip: 'Rotate right',
                                onPressed:
                                    _busy ? null : () => _rotateSelected(true),
                                icon: const Icon(Icons.rotate_right),
                              ),
                              IconButton(
                                tooltip: 'Delete page',
                                onPressed: _busy
                                    ? null
                                    : () => _deletePage(_selectedPage),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        SizedBox(height: 150, child: _buildThumbnails()),
      ],
    );
  }

  Widget _buildThumbnails() {
    if (_pages.isEmpty) return const SizedBox.shrink();
    return ReorderableListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(10),
      itemCount: _pages.length,
      onReorder: _busy
          ? (_, __) {}
          : (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final page = _pages.removeAt(oldIndex);
                _pages.insert(newIndex, page);
                _selectedPage = newIndex;
              });
            },
      itemBuilder: (context, index) {
        final page = _pages[index];
        return Padding(
          key: ValueKey(page.id),
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            onTap: () => setState(() => _selectedPage = index),
            child: Container(
              width: 92,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedPage == index
                      ? const Color(0xFF0F766E)
                      : const Color(0xFFCBD5E1),
                  width: _selectedPage == index ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    page.file,
                    key: ValueKey(
                      '${page.id}-${page.revision}-${page.file.path}',
                    ),
                    cacheWidth: 180,
                    fit: BoxFit.cover,
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      color: Colors.black54,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        'Page ${index + 1}',
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _fileNameController,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Final document name',
                    prefixIcon: Icon(Icons.drive_file_rename_outline),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 220,
                child: widget.combinedPdfOnly
                    ? const InputDecorator(
                        decoration: InputDecoration(labelText: 'Output format'),
                        child: Text('One combined PDF'),
                      )
                    : DropdownButtonFormField<ScannerOutputFormat>(
                        key: ValueKey(_format),
                        initialValue: _format,
                        decoration:
                            const InputDecoration(labelText: 'Output format'),
                        items: ScannerOutputFormat.values
                            .map(
                              (format) => DropdownMenuItem(
                                value: format,
                                child: Text(_outputLabel(format)),
                              ),
                            )
                            .toList(),
                        onChanged: _busy || _pages.isEmpty
                            ? null
                            : (value) =>
                                setState(() => _format = value ?? _format),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('${_pages.length} page${_pages.length == 1 ? '' : 's'}'),
              const SizedBox(width: 16),
              Text('Estimated size: ${_formatBytes(_estimatedBytes)}'),
              if (_device != null) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '${_device!.name} • ${_settings.dpi} DPI • ${_colorModeLabel(_settings.colorMode)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                const Spacer(),
              TextButton(
                onPressed: _pages.isEmpty || _busy ? null : _clearPages,
                child: const Text('Clear all'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                  onPressed: _busy ? null : _cancel,
                  child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _pages.isEmpty || _busy ? null : _saveToUploadList,
                icon: _creatingOutput
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_to_drive_outlined),
                label: Text(
                  widget.combinedPdfOnly
                      ? 'Upload combined PDF'
                      : 'Save to upload list',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _colorModeLabel(ScannerColorMode mode) => switch (mode) {
        ScannerColorMode.color => 'Color',
        ScannerColorMode.grayscale => 'Grayscale',
        ScannerColorMode.blackAndWhite => 'Black and white',
      };

  String _outputLabel(ScannerOutputFormat format) => switch (format) {
        ScannerOutputFormat.combinedPdf => 'One combined PDF',
        ScannerOutputFormat.separatePdf => 'Separate PDF files',
        ScannerOutputFormat.jpg => 'JPG images',
        ScannerOutputFormat.png => 'PNG images',
      };

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
