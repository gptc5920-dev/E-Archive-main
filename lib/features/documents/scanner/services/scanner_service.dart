import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;

import '../domain/scanner_models.dart';

class ScannerService {
  Future<List<ScannerDevice>> discoverDevices() async {
    _requireWindows();
    const script = r'''
$ErrorActionPreference = 'Stop'
$manager = New-Object -ComObject WIA.DeviceManager
$result = @()
foreach ($info in $manager.DeviceInfos) {
  if ($info.Type -ne 1) { continue }
  $name = ''
  $manufacturer = ''
  $description = ''
  foreach ($property in $info.Properties) {
    if ($property.Name -eq 'Name') { $name = [string]$property.Value }
    if ($property.Name -eq 'Manufacturer') { $manufacturer = [string]$property.Value }
    if ($property.Name -eq 'Description') { $description = [string]$property.Value }
  }
  if ([string]::IsNullOrWhiteSpace($name)) { $name = [string]$info.DeviceID }
  $result += [PSCustomObject]@{
    id = [string]$info.DeviceID
    name = $name
    manufacturer = $manufacturer
    description = $description
    # Do not call DeviceInfo.Connect during discovery. Some vendor drivers can
    # enumerate a device but fail (or get blocked by Windows) when loaded. A
    # connection should only be attempted in response to an explicit scan.
    minimumDpi = 150
    maximumDpi = 600
    supportsDuplex = $false
  }
}
ConvertTo-Json -Compress -InputObject @($result)
''';
    final output = await _runPowerShell(script);
    if (output.trim().isEmpty) return const [];
    final decoded = jsonDecode(output);
    final items = decoded is List ? decoded : [decoded];
    return items
        .whereType<Map>()
        .map(
          (item) => ScannerDevice(
            id: '${item['id'] ?? ''}',
            name: '${item['name'] ?? 'USB scanner'}',
            manufacturer: '${item['manufacturer'] ?? ''}',
            description: '${item['description'] ?? ''}',
            minimumDpi: (item['minimumDpi'] as num?)?.toInt() ?? 150,
            maximumDpi: (item['maximumDpi'] as num?)?.toInt() ?? 600,
            supportsDuplex: item['supportsDuplex'] == true,
          ),
        )
        .where((device) => device.id.isNotEmpty)
        .toList();
  }

  Future<Directory> createSessionDirectory() async {
    final root =
        Directory(p.join(Directory.systemTemp.path, 'e_archive_scans'));
    await root.create(recursive: true);
    final session = Directory(
      p.join(root.path, 'scan_${DateTime.now().microsecondsSinceEpoch}'),
    );
    await session.create(recursive: true);
    return session;
  }

  Future<ScannedPage> scanPage({
    required ScannerDevice device,
    required ScannerSettings settings,
    required Directory sessionDirectory,
  }) async {
    _requireWindows();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final destination = p.join(sessionDirectory.path, 'page_$id.jpg');
    final dimensions = _paperDimensions(settings.paperSize, settings.dpi);
    final intent = switch (settings.colorMode) {
      ScannerColorMode.color => 1,
      ScannerColorMode.grayscale => 2,
      ScannerColorMode.blackAndWhite => 4,
    };
    final script = '''
\$ErrorActionPreference = 'Stop'
function Set-WiaProperty([object]\$properties, [int]\$id, [object]\$value) {
  foreach (\$property in \$properties) {
    if ([int]\$property.PropertyID -eq \$id) {
      try { \$property.Value = \$value } catch { }
      return
    }
  }
}
\$manager = New-Object -ComObject WIA.DeviceManager
\$deviceInfo = \$null
foreach (\$info in \$manager.DeviceInfos) {
  if ([string]\$info.DeviceID -eq ${_psQuote(device.id)}) { \$deviceInfo = \$info; break }
}
if (\$null -eq \$deviceInfo) { throw 'Scanner disconnected or driver unavailable.' }
\$device = \$deviceInfo.Connect()
if (\$device.Items.Count -lt 1) { throw 'No scanning source is available.' }
\$item = \$device.Items.Item(1)
Set-WiaProperty \$item.Properties 6146 $intent
Set-WiaProperty \$item.Properties 6147 ${settings.dpi}
Set-WiaProperty \$item.Properties 6148 ${settings.dpi}
Set-WiaProperty \$item.Properties 6151 ${dimensions.$1}
Set-WiaProperty \$item.Properties 6152 ${dimensions.$2}
${settings.duplex ? 'Set-WiaProperty \$device.Properties 3088 5' : ''}
\$image = \$item.Transfer('{B96B3CAE-0728-11D3-9D7B-0000F81EF32E}')
\$image.SaveFile(${_psQuote(destination)})
Write-Output ${_psQuote(destination)}
''';
    try {
      await _runPowerShell(script, timeout: const Duration(minutes: 5));
      final file = File(destination);
      if (!await file.exists() || await file.length() == 0) {
        throw const ScannerException('The scanner did not return an image.');
      }
      return ScannedPage(id: id, file: file, scannedAt: DateTime.now());
    } on ScannerException {
      rethrow;
    } catch (error) {
      throw ScannerException(_friendlyScanError('$error'));
    }
  }

  Future<ScannedPage> rotatePage(
    ScannedPage page, {
    required bool right,
  }) async {
    final nextRevision = page.revision + 1;
    final output = p.join(
      page.file.parent.path,
      'page_${page.id}_rotation_$nextRevision.jpg',
    );
    final args = [page.file.path, output, right];
    final rotated = File(output);
    try {
      await Isolate.run(() => _rotateImage(args));
      if (!await rotated.exists() || await rotated.length() == 0) {
        throw const ScannerException(
          'The rotated scanner preview could not be created.',
        );
      }
      try {
        if (await page.file.exists()) await page.file.delete();
      } catch (_) {
        // Windows may briefly retain the old preview file in the image cache.
        // It remains inside the temporary session and is removed on cleanup.
      }
      return ScannedPage(
        id: page.id,
        file: rotated,
        scannedAt: page.scannedAt,
        revision: nextRevision,
      );
    } catch (error) {
      if (await rotated.exists()) {
        try {
          await rotated.delete();
        } catch (_) {}
      }
      if (error is ScannerException) rethrow;
      throw ScannerException('Could not rotate the scanned page: $error');
    }
  }

  Future<ScannerOutput> createOutput({
    required List<ScannedPage> pages,
    required Directory sessionDirectory,
    required ScannerOutputFormat format,
    required String fileName,
    required ScannerDevice device,
    required ScannerSettings settings,
  }) async {
    if (pages.isEmpty) throw const ScannerException('Scan at least one page.');
    final baseName =
        _safeFileName(fileName.isEmpty ? 'Scanned document' : fileName);
    final request = <String, Object?>{
      'paths': pages.map((page) => page.file.path).toList(),
      'directory': sessionDirectory.path,
      'baseName': baseName,
      'format': format.name,
    };
    try {
      final paths = await Isolate.run(() => _createScannerOutput(request));
      final now = DateTime.now().toIso8601String();
      return ScannerOutput(
        files: paths.map(File.new).toList(),
        sessionDirectory: sessionDirectory,
        metadataTags: [
          'scanned',
          'scanner:${device.name}',
          'scan_date:$now',
          'dpi:${settings.dpi}',
          'color:${settings.colorMode.name}',
          'pages:${pages.length}',
          'original:$baseName',
        ],
      );
    } catch (error) {
      throw ScannerException('Failed to create the selected output: $error');
    }
  }

  Future<void> cleanup(Directory directory) async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (_) {
      // Temporary cleanup is best-effort; the OS temp cleaner is the fallback.
    }
  }

  (int, int) _paperDimensions(ScannerPaperSize size, int dpi) {
    final inches = switch (size) {
      ScannerPaperSize.a4 => (8.27, 11.69),
      ScannerPaperSize.letter => (8.5, 11.0),
      ScannerPaperSize.legal => (8.5, 14.0),
    };
    return ((inches.$1 * dpi).round(), (inches.$2 * dpi).round());
  }

  void _requireWindows() {
    if (!Platform.isWindows) {
      throw const ScannerException(
          'USB scanning is available on Windows only.');
    }
  }

  String _psQuote(String value) => "'${value.replaceAll("'", "''")}'";

  Future<String> _runPowerShell(
    String script, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final bytes = <int>[];
    for (final unit in script.codeUnits) {
      bytes
        ..add(unit & 0xff)
        ..add(unit >> 8);
    }
    final encoded = base64Encode(bytes);
    ProcessResult result;
    try {
      result = await Process.run(
        'powershell.exe',
        [
          '-NoLogo',
          '-NoProfile',
          '-NonInteractive',
          '-EncodedCommand',
          encoded
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(timeout);
    } on TimeoutException {
      throw const ScannerException(
        'The scanner did not respond. Check for a paper jam or busy device.',
      );
    } on ProcessException {
      throw const ScannerException(
        'Windows PowerShell or the WIA scanner service is unavailable.',
      );
    }
    if (result.exitCode != 0) {
      final error = '${result.stderr}'.trim();
      throw ScannerException(_friendlyScanError(error));
    }
    return '${result.stdout}'.trim();
  }

  String _friendlyScanError(String error) {
    final cleaned = _cleanPowerShellError(error);
    final lower = cleaned.toLowerCase();
    if (lower.contains('driver has been blocked') ||
        lower.contains('blocked from loading')) {
      return 'Windows blocked this scanner driver. Install the latest WIA '
          'driver from the scanner manufacturer, restart Windows, and retry.';
    }
    if (lower.contains('paper') && lower.contains('jam')) {
      return 'The scanner reports a paper jam.';
    }
    if (lower.contains('paper') || lower.contains('feeder')) {
      return 'No paper was detected in the scanner feeder.';
    }
    if (lower.contains('busy') || lower.contains('being used')) {
      return 'The scanner is busy. Close other scanner applications and retry.';
    }
    if (lower.contains('cancel')) return 'Scanning was cancelled.';
    if (lower.contains('disconnect') || lower.contains('offline')) {
      return 'The scanner was disconnected during scanning.';
    }
    if (lower.contains('class not registered') || lower.contains('wia')) {
      return 'No compatible WIA scanner driver was found.';
    }
    return cleaned.isEmpty ? 'The scan failed for an unknown reason.' : cleaned;
  }

  String _cleanPowerShellError(String error) {
    var cleaned = error.trim();
    if (!cleaned.contains('CLIXML')) return cleaned;

    final record = RegExp(
      r'<S S="Error">(.*?)</S>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(cleaned);
    if (record != null) cleaned = record.group(1) ?? cleaned;

    cleaned = cleaned.replaceAllMapped(
      RegExp(r'_x([0-9a-fA-F]{4})_'),
      (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
    );
    cleaned = cleaned
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned;
  }

  String _safeFileName(String value) {
    final safe = value.trim().replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    return safe.isEmpty ? 'Scanned document' : safe;
  }
}

void _rotateImage(List<Object> args) {
  final source = File(args[0] as String).readAsBytesSync();
  final decoded = img.decodeImage(source);
  if (decoded == null) {
    throw StateError('The scanned image could not be decoded.');
  }
  final rotated = img.copyRotate(decoded, angle: (args[2] as bool) ? 90 : -90);
  File(args[1] as String).writeAsBytesSync(img.encodeJpg(rotated, quality: 92));
}

Future<List<String>> _createScannerOutput(Map<String, Object?> request) async {
  final paths = (request['paths'] as List).cast<String>();
  final directory = request['directory'] as String;
  final baseName = request['baseName'] as String;
  final format = request['format'] as String;
  if (format == ScannerOutputFormat.combinedPdf.name) {
    final output = p.join(directory, '$baseName.pdf');
    final document = pw.Document();
    for (final path in paths) {
      final image = pw.MemoryImage(File(path).readAsBytesSync());
      document.addPage(
        pw.Page(
          margin: pw.EdgeInsets.zero,
          build: (_) =>
              pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );
    }
    await File(output).writeAsBytes(await document.save());
    return [output];
  }

  final outputs = <String>[];
  for (var index = 0; index < paths.length; index++) {
    final suffix = (index + 1).toString().padLeft(3, '0');
    final bytes = File(paths[index]).readAsBytesSync();
    if (format == ScannerOutputFormat.separatePdf.name) {
      final output = p.join(directory, '${baseName}_$suffix.pdf');
      final document = pw.Document()
        ..addPage(
          pw.Page(
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Center(
              child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
            ),
          ),
        );
      await File(output).writeAsBytes(await document.save());
      outputs.add(output);
      continue;
    }
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw StateError('Page ${index + 1} is invalid.');
    final extension = format == ScannerOutputFormat.png.name ? 'png' : 'jpg';
    final output = p.join(directory, '${baseName}_$suffix.$extension');
    File(output).writeAsBytesSync(
      extension == 'png'
          ? img.encodePng(decoded)
          : img.encodeJpg(decoded, quality: 92),
    );
    outputs.add(output);
  }
  return outputs;
}
