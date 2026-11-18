/// Helpers for manually entered student IDs.
class StudentNumber {
  StudentNumber._();

  static const String example = 'KC-22-A-00000';
  static const String notAvailable = 'N/A';

  /// Formats free-form student ID input while preserving the N/A option.
  static String formatInput(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9-/]'), '');
  }

  static bool isNotAvailable(String value) {
    return value.trim().toUpperCase() == notAvailable;
  }

  /// N/A represents a missing ID in storage so more than one student can use it.
  static String storageValue(String value) {
    final trimmed = value.trim();
    return isNotAvailable(trimmed) ? '' : trimmed;
  }

  static String displayValue(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty || isNotAvailable(trimmed) ? notAvailable : trimmed;
  }

  static final RegExp _legacyFormatPattern = RegExp(
    r'^([A-Z0-9]+)-(\d{2})-A-(\d{5})$',
    caseSensitive: false,
  );

  /// Reads the legacy batch encoded in an existing student ID.
  static String schoolYearFromId(String studentNo) {
    final match = _legacyFormatPattern.firstMatch(studentNo.trim());
    if (match == null) return '';
    final yy = int.tryParse(match.group(2)!);
    if (yy == null) return '';
    final startYear = yy >= 70 ? 1900 + yy : 2000 + yy;
    return '$startYear-${startYear + 1}';
  }

  /// Prefers the independently stored batch and falls back for legacy rows.
  static String resolveSchoolYear({
    required String storedSchoolYear,
    required String studentNo,
  }) {
    final stored = storedSchoolYear.trim();
    return stored.isNotEmpty ? stored : schoolYearFromId(studentNo);
  }

  /// Resolves a program code from a course name, e.g. `(BEEd)` to `BEED`.
  static String programCodeFromName(String programName) {
    final trimmed = programName.trim();
    if (trimmed.isEmpty) return 'KC';

    final paren = RegExp(r'\(([^)]+)\)\s*$').firstMatch(trimmed);
    if (paren != null) {
      final code = paren.group(1)!.trim();
      if (code.isNotEmpty) return code.toUpperCase();
    }

    final bsIn = RegExp(
      r'^bachelor\s+of\s+science\s+in\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(trimmed.replaceAll(RegExp(r'\([^)]*\)'), '').trim());
    if (bsIn != null) {
      final restWords = bsIn
          .group(1)!
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .toList();
      if (restWords.isNotEmpty) {
        return 'BS${restWords.map((word) => word[0].toUpperCase()).join()}';
      }
    }

    final words = trimmed
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'KC';

    final skip = {'of', 'in', 'and', 'the', 'major'};
    final letters = <String>[];
    for (final word in words) {
      final lower = word.toLowerCase();
      if (skip.contains(lower)) continue;
      if (lower == 'bachelor' || lower == 'science') continue;
      letters.add(word[0].toUpperCase());
      if (letters.length >= 2) break;
    }
    return letters.isEmpty ? 'KC' : letters.join();
  }

  static String resolveProgramCode({
    required String programName,
    String? courseCode,
  }) {
    final fromApi = courseCode?.trim();
    if (fromApi != null && fromApi.isNotEmpty) {
      return fromApi.toUpperCase();
    }
    return programCodeFromName(programName);
  }
}
