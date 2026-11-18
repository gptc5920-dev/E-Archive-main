import 'package:printing/printing.dart';

enum DocumentPrintResult { printed, cancelled, openedFallback }

/// Uses the native print dialog, which renders PDF pages through the driver.
Future<DocumentPrintResult> printDocumentWithFallback({
  required String name,
  required LayoutCallback onLayout,
  required Future<void> Function() openFallback,
}) async {
  try {
    final info = await Printing.info();
    if (info.canPrint) {
      final printed = await Printing.layoutPdf(name: name, onLayout: onLayout);
      // Cancellation is a completed user action, not a printing failure.
      return printed
          ? DocumentPrintResult.printed
          : DocumentPrintResult.cancelled;
    }
  } catch (_) {
    // Native failures can be PlatformExceptions or plugin completion errors.
    // Offer the prepared PDF in the system viewer so the user can print it.
  }

  // Let fallback errors reach the caller instead of reporting success.
  await openFallback();
  return DocumentPrintResult.openedFallback;
}
