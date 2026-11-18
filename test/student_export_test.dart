import 'package:e_archive/core/utils/student_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StudentExport', () {
    test('creates the requested surname-first ZIP base name', () {
      expect(
        StudentExport.archiveBaseName(
          fullName: 'Jhonlloyd B. Fullon',
          programCode: 'BSIS',
          schoolYear: '2026-2027',
        ),
        'FULLON, JHONLLOYD B. BSIS-2026',
      );
    });

    test('keeps compound Filipino surnames together', () {
      expect(
        StudentExport.surnameFirst('Juan Miguel Dela Cruz'),
        'Dela Cruz, Juan Miguel',
      );
    });

    test('creates numbered and safe PDF entry names', () {
      expect(
        StudentExport.pdfEntryName(label: 'Transcript: Final.pdf', index: 1),
        '02 - Transcript_ Final.pdf',
      );
    });
  });
}
