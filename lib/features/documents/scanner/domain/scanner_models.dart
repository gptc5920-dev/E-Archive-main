import 'dart:io';

enum ScannerColorMode { color, grayscale, blackAndWhite }

enum ScannerPaperSize { a4, letter, legal }

enum ScannerOutputFormat { combinedPdf, separatePdf, jpg, png }

class ScannerDevice {
  const ScannerDevice({
    required this.id,
    required this.name,
    this.manufacturer = '',
    this.description = '',
    this.minimumDpi = 150,
    this.maximumDpi = 600,
    this.supportsDuplex = false,
  });

  final String id;
  final String name;
  final String manufacturer;
  final String description;
  final int minimumDpi;
  final int maximumDpi;
  final bool supportsDuplex;
}

class ScannerSettings {
  const ScannerSettings({
    this.colorMode = ScannerColorMode.color,
    this.dpi = 300,
    this.paperSize = ScannerPaperSize.a4,
    this.multiPage = true,
    this.duplex = false,
  });

  final ScannerColorMode colorMode;
  final int dpi;
  final ScannerPaperSize paperSize;
  final bool multiPage;
  final bool duplex;

  ScannerSettings copyWith({
    ScannerColorMode? colorMode,
    int? dpi,
    ScannerPaperSize? paperSize,
    bool? multiPage,
    bool? duplex,
  }) {
    return ScannerSettings(
      colorMode: colorMode ?? this.colorMode,
      dpi: dpi ?? this.dpi,
      paperSize: paperSize ?? this.paperSize,
      multiPage: multiPage ?? this.multiPage,
      duplex: duplex ?? this.duplex,
    );
  }
}

class ScannedPage {
  const ScannedPage({
    required this.id,
    required this.file,
    required this.scannedAt,
    this.revision = 0,
  });

  final String id;
  final File file;
  final DateTime scannedAt;
  final int revision;
}

class ScannerOutput {
  const ScannerOutput({
    required this.files,
    required this.sessionDirectory,
    required this.metadataTags,
  });

  final List<File> files;
  final Directory sessionDirectory;
  final List<String> metadataTags;
}

class ScannerException implements Exception {
  const ScannerException(this.message);

  final String message;

  @override
  String toString() => message;
}
