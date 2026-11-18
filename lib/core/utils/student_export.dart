class StudentExport {
  StudentExport._();

  static final RegExp _invalidFileNameCharacters =
      RegExp(r'[<>:"/\\|?*\x00-\x1F]');

  static const Set<String> _suffixes = {
    'JR',
    'JR.',
    'SR',
    'SR.',
    'II',
    'III',
    'IV',
    'V',
  };

  static const Set<String> _surnamePrefixes = {
    'DA',
    'DE',
    'DEL',
    'DELA',
    'DI',
    'DOS',
    'DU',
    'LA',
    'SAN',
    'SANTA',
    'VAN',
    'VON',
  };

  static String archiveBaseName({
    required String fullName,
    required String programCode,
    required String schoolYear,
  }) {
    final name = surnameFirst(fullName).toUpperCase();
    final code = safeFileNamePart(programCode).toUpperCase();
    final year = RegExp(r'\d{4}').firstMatch(schoolYear)?.group(0) ?? 'UNKNOWN';
    return safeFileNamePart(
      '$name ${code.isEmpty ? 'PROGRAM' : code}-$year',
    );
  }

  static String surnameFirst(String fullName) {
    final normalized = fullName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty || normalized.contains(',')) return normalized;

    final parts = normalized.split(' ');
    if (parts.length < 2) return normalized;

    String? suffix;
    var surnameEnd = parts.length;
    if (_suffixes.contains(parts.last.toUpperCase())) {
      suffix = parts.last;
      surnameEnd -= 1;
    }
    if (surnameEnd < 2) return normalized;

    var surnameStart = surnameEnd - 1;
    if (surnameStart >= 2 &&
        parts[surnameStart - 2].toUpperCase() == 'DE' &&
        parts[surnameStart - 1].toUpperCase() == 'LA') {
      surnameStart -= 2;
    } else if (surnameStart >= 1 &&
        _surnamePrefixes.contains(parts[surnameStart - 1].toUpperCase())) {
      surnameStart -= 1;
    }

    final surname = parts.sublist(surnameStart, surnameEnd).join(' ');
    final givenNames = parts.sublist(0, surnameStart).join(' ');
    final surnameWithSuffix =
        suffix == null ? surname : '$surname $suffix'.trim();
    return givenNames.isEmpty
        ? surnameWithSuffix
        : '$surnameWithSuffix, $givenNames';
  }

  static String safeFileNamePart(String value) {
    final safe = value
        .replaceAll(_invalidFileNameCharacters, '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return safe.replaceFirst(RegExp(r'[. ]+$'), '');
  }

  static String pdfEntryName({
    required String label,
    required int index,
  }) {
    var base = safeFileNamePart(label);
    if (base.toLowerCase().endsWith('.pdf')) {
      base = base.substring(0, base.length - 4).trim();
    }
    if (base.isEmpty) base = 'Document ${index + 1}';
    final number = (index + 1).toString().padLeft(2, '0');
    return '$number - $base.pdf';
  }
}
