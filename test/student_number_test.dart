import 'package:e_archive/core/utils/student_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StudentNumber N/A support', () {
    test('preserves N/A while formatting form input', () {
      expect(StudentNumber.formatInput('n/a'), StudentNumber.notAvailable);
    });

    test('stores N/A as a reusable missing value', () {
      expect(StudentNumber.storageValue('N/A'), isEmpty);
      expect(StudentNumber.storageValue(' KC-22-A-00001 '), 'KC-22-A-00001');
    });

    test('displays a missing ID as N/A', () {
      expect(StudentNumber.displayValue(''), StudentNumber.notAvailable);
    });
  });

  group('StudentNumber.resolveSchoolYear', () {
    test('uses the stored batch without changing the student ID', () {
      const studentId = 'BSIT-24-A-00001';

      final batch = StudentNumber.resolveSchoolYear(
        storedSchoolYear: '2022-2023',
        studentNo: studentId,
      );

      expect(batch, '2022-2023');
      expect(studentId, 'BSIT-24-A-00001');
    });

    test('falls back to the ID batch for legacy student rows', () {
      expect(
        StudentNumber.resolveSchoolYear(
          storedSchoolYear: '',
          studentNo: 'BSIT-24-A-00001',
        ),
        '2024-2025',
      );
    });
  });
}
