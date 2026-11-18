import 'package:e_archive/core/utils/document_printing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('net.nfet.printing');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var fallbackCalls = 0;
  var printCalls = 0;
  var canPrint = true;
  var completed = true;
  Object? printError;
  Uint8List? renderedBytes;
  final sourceBytes = Uint8List.fromList('%PDF-1.4\nTest content'.codeUnits);

  Future<DocumentPrintResult> printDocument() => printDocumentWithFallback(
        name: 'student-record.pdf',
        onLayout: (_) async => sourceBytes,
        openFallback: () async => fallbackCalls++,
      );

  Future<void> sendNativeCall(String method, Map<String, Object?> args,
      [void Function(ByteData?)? reply]) async {
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
      reply ?? (_) {},
    );
  }

  setUp(() {
    fallbackCalls = 0;
    printCalls = 0;
    canPrint = true;
    completed = true;
    printError = null;
    renderedBytes = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'printingInfo') return {'canPrint': canPrint};
      if (call.method == 'printPdf') {
        printCalls++;
        if (printError != null) throw printError!;
        final args = Map<String, Object?>.from(call.arguments as Map);
        expect(args['name'], 'student-record.pdf');
        if (completed) {
          await sendNativeCall('onLayout', args, (reply) {
            renderedBytes =
                const StandardMethodCodec().decodeEnvelope(reply!) as Uint8List;
          });
        }
        await sendNativeCall('onCompleted', {
          'job': args['job'],
          'completed': completed,
        });
        return 1;
      }
      throw MissingPluginException();
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('native printing receives the document bytes, not just its filename',
      () async {
    expect(await printDocument(), DocumentPrintResult.printed);
    expect(printCalls, 1);
    expect(renderedBytes, sourceBytes);
    expect(fallbackCalls, 0);
  });

  test('cancelling the native dialog does not open the fallback', () async {
    completed = false;
    expect(await printDocument(), DocumentPrintResult.cancelled);
    expect(fallbackCalls, 0);
  });

  test('native print errors open the fallback', () async {
    printError = PlatformException(code: 'PRINT_FAILED');
    expect(await printDocument(), DocumentPrintResult.openedFallback);
    expect(fallbackCalls, 1);
  });

  test('unavailable printing opens the fallback without submitting a job',
      () async {
    canPrint = false;
    expect(await printDocument(), DocumentPrintResult.openedFallback);
    expect(printCalls, 0);
    expect(fallbackCalls, 1);
  });

  test('fallback errors are propagated to the UI', () async {
    canPrint = false;
    await expectLater(
      printDocumentWithFallback(
        name: 'student-record.pdf',
        onLayout: (_) async => sourceBytes,
        openFallback: () async => throw StateError('Viewer unavailable'),
      ),
      throwsStateError,
    );
  });
}
