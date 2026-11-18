import 'dart:io';

import 'package:e_archive/features/documents/scanner/domain/scanner_models.dart';
import 'package:e_archive/features/documents/scanner/services/scanner_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('rotating a scanner page refreshes the image file', () async {
    final service = ScannerService();
    final session = await service.createSessionDirectory();
    addTearDown(() => service.cleanup(session));

    final source = File('${session.path}${Platform.pathSeparator}page.jpg');
    final image = img.Image(width: 80, height: 120)
      ..setPixelRgb(10, 10, 0, 0, 0);
    await source.writeAsBytes(img.encodeJpg(image));
    final page = ScannedPage(
      id: 'page-1',
      file: source,
      scannedAt: DateTime.utc(2026, 7, 14),
    );

    final rotated = await service.rotatePage(page, right: true);
    final decoded = img.decodeImage(await rotated.file.readAsBytes());

    expect(rotated.revision, 1);
    expect(rotated.file.path, isNot(page.file.path));
    expect(await page.file.exists(), isFalse);
    expect(decoded, isNotNull);
    expect(decoded!.width, 120);
    expect(decoded.height, 80);
  });

  test('scanner pages can produce combined PDF and PNG outputs', () async {
    final service = ScannerService();
    final session = await service.createSessionDirectory();
    addTearDown(() => service.cleanup(session));

    final source = File('${session.path}${Platform.pathSeparator}page.jpg');
    final image = img.Image(width: 80, height: 120)
      ..setPixelRgb(10, 10, 0, 0, 0);
    await source.writeAsBytes(img.encodeJpg(image));
    final page = ScannedPage(
      id: 'page-1',
      file: source,
      scannedAt: DateTime.utc(2026, 7, 14),
    );
    const device = ScannerDevice(id: 'test', name: 'Test scanner');
    const settings = ScannerSettings();

    final pdf = await service.createOutput(
      pages: [page],
      sessionDirectory: session,
      format: ScannerOutputFormat.combinedPdf,
      fileName: 'Student record',
      device: device,
      settings: settings,
    );
    expect(pdf.files, hasLength(1));
    expect(pdf.files.single.path, endsWith('.pdf'));
    expect(await pdf.files.single.length(), greaterThan(0));

    final png = await service.createOutput(
      pages: [page],
      sessionDirectory: session,
      format: ScannerOutputFormat.png,
      fileName: 'Student record image',
      device: device,
      settings: settings,
    );
    expect(png.files, hasLength(1));
    expect(png.files.single.path, endsWith('.png'));
    expect(png.metadataTags, contains('scanner:Test scanner'));
  });
}
