import 'dart:io';

import 'package:e_archive_server/document_classifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('DocumentClassifier', () {
    test('keeps generated upload paths inside the upload root', () {
      final relativePath = DocumentClassifier.buildRelativePath(
        schoolYear: '..',
        college: '..',
        program: '..',
        studentCategory: '..',
        studentNo: '..',
        studentName: '..',
        documentType: '..',
        fileName: '..',
        isComplete: true,
      );

      final root = p.normalize(p.absolute('uploads'));
      final resolved = p.normalize(p.join(root, relativePath));

      expect(p.isWithin(root, resolved), isTrue);
      expect(
        relativePath.split(Platform.pathSeparator),
        isNot(contains('..')),
      );
    });

    test('sanitizes incomplete upload file names', () {
      final relativePath = DocumentClassifier.buildRelativePath(
        schoolYear: '2025-2026',
        college: 'College',
        program: 'Program',
        studentCategory: 'Graduated',
        studentNo: 'ST-001',
        studentName: 'Student Name',
        documentType: 'Other',
        fileName: '..',
        isComplete: false,
      );

      expect(p.basename(relativePath), 'upload.bin');
    });
  });
}
