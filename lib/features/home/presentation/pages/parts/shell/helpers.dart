part of '../../dashboard_shell_page.dart';

String _cleanTextValue(Object? value) {
  final text = (value ?? '').toString().trim();
  return text.toLowerCase() == 'null' ? '' : text;
}

String _sentenceCase(String value) {
  final trimmed = _cleanTextValue(value);
  if (trimmed.isEmpty) return trimmed;
  final lower = trimmed.toLowerCase();
  return '${lower[0].toUpperCase()}${lower.substring(1)}';
}

String _nameCase(String value) {
  final lower = _cleanTextValue(value).toLowerCase();
  return lower.replaceAllMapped(RegExp(r'[a-z]+'), (match) {
    final word = match.group(0)!;
    return '${word[0].toUpperCase()}${word.substring(1)}';
  });
}

List<int> _distributePercentages(List<int> counts, int total) {
  if (total == 0 || counts.isEmpty) {
    return List<int>.filled(counts.length, 0);
  }
  final exact = counts.map((c) => c * 100.0 / total).toList();
  final result = exact.map((v) => v.floor()).toList();
  var remaining = 100 - result.fold<int>(0, (sum, value) => sum + value);
  final order = List<int>.generate(counts.length, (i) => i)
    ..sort(
      (a, b) => (exact[b] - result[b]).compareTo(exact[a] - result[a]),
    );
  var cursor = 0;
  while (remaining > 0) {
    result[order[cursor % order.length]]++;
    remaining--;
    cursor++;
  }
  return result;
}

/// Short school-year label for chart axes (e.g. 2024-2025 → 24-25).
String _shortSchoolYearLabel(String year) {
  final trimmed = year.trim();
  final parts = trimmed.split('-');
  if (parts.length != 2) return trimmed;
  String two(String y) {
    if (y.length == 4) return y.substring(2);
    if (y.length == 2) return y;
    return y;
  }

  return '${two(parts[0])}-${two(parts[1])}';
}

String _schoolYearFromStudentNo(String studentNo) {
  return StudentNumber.schoolYearFromId(studentNo);
}

String _schoolYearForStudent(_StudentRow student) {
  return StudentNumber.resolveSchoolYear(
    storedSchoolYear: student.schoolYear,
    studentNo: student.studentNo,
  );
}

String _currentSchoolYear() {
  final y = DateTime.now().year;
  return '$y-${y + 1}';
}

/// Program code from student ID prefix (e.g. BSHM-26-A-00001 → BSHM).
String _programCodeFromStudentNo(String studentNo) {
  final match = RegExp(r'^([A-Z0-9]+)-\d{2}-A-', caseSensitive: false)
      .firstMatch(studentNo.trim());
  final code = match?.group(1)?.trim().toUpperCase();
  if (code == null || code.isEmpty) return '';
  return code;
}

/// Default Data Analytics filter: always the current batch when listed,
/// otherwise the most recent year that has graduate data.
String? _defaultAnalyticsFilterYear(
  List<String> availableYears,
  List<_YearCount> bySchoolYear,
) {
  if (availableYears.isEmpty) return null;

  final current = _currentSchoolYear();
  if (availableYears.contains(current)) return current;

  int graduatesFor(String year) {
    for (final entry in bySchoolYear) {
      if (entry.year == year) return entry.students;
    }
    return 0;
  }

  for (final year in availableYears) {
    if (graduatesFor(year) > 0) return year;
  }
  return availableYears.first;
}

/// School-year rows ordered oldest → newest (for charts and tables).
List<_YearCount> _schoolYearsChronological(List<_YearCount> years) {
  final copy = [...years];
  copy.sort((a, b) {
    final aStart = int.tryParse(a.year.split('-').first) ?? 0;
    final bStart = int.tryParse(b.year.split('-').first) ?? 0;
    return aStart.compareTo(bStart);
  });
  return copy;
}

/// Batches for analytics filters, with the current year first when present.
List<String> _analyticsFilterYears(List<String> years) {
  if (years.isEmpty) return years;
  final current = _currentSchoolYear();
  if (!years.contains(current)) return years;
  return [current, ...years.where((year) => year != current)];
}

bool _studentInSchoolYear(
  _StudentRow student,
  String schoolYear,
  List<_DocRow> docs,
) {
  final filter = schoolYear.trim();
  if (filter.isEmpty) return true;
  if (_schoolYearForStudent(student) == filter) return true;
  final name = student.fullName.trim().toLowerCase();
  final no = student.studentNo.trim().toLowerCase();
  return docs.any((doc) {
    if (_schoolYearForDocument(doc, students: [student]) != filter) {
      return false;
    }
    final key = doc.student.toLowerCase();
    return (name.isNotEmpty && key.contains(name)) ||
        (no.isNotEmpty && key.contains(no));
  });
}

bool _docInSchoolYear(_DocRow doc, String schoolYear) {
  final filter = schoolYear.trim();
  if (filter.isEmpty) return true;
  return _schoolYearForDocument(doc) == filter;
}

String _schoolYearForDocument(
  _DocRow doc, {
  List<_StudentRow> students = const [],
}) {
  final stored = doc.schoolYear.trim();
  if (stored.isNotEmpty && stored.toLowerCase() != 'unknown') return stored;

  final fromDocStudentNo = _schoolYearFromStudentNo(doc.studentNo);
  if (fromDocStudentNo.isNotEmpty) return fromDocStudentNo;

  final docStudentKey = doc.student.trim().toLowerCase();
  if (docStudentKey.isEmpty || students.isEmpty) return '';
  for (final student in students) {
    final name = student.fullName.trim().toLowerCase();
    final no = student.studentNo.trim().toLowerCase();
    final matchesName = name.isNotEmpty &&
        (docStudentKey == name || docStudentKey.contains(name));
    final matchesNo =
        no.isNotEmpty && (docStudentKey == no || docStudentKey.contains(no));
    if (matchesName || matchesNo) {
      final year = _schoolYearForStudent(student);
      if (year.isNotEmpty) return year;
    }
  }
  return '';
}

List<String> _collectSchoolYears({
  required List<_StudentRow> students,
  required List<_DocRow> docs,
}) {
  final years = <String>{};
  for (final doc in docs) {
    final year = _schoolYearForDocument(doc, students: students);
    if (year.isNotEmpty) years.add(year);
  }
  for (final student in students) {
    final year = _schoolYearForStudent(student);
    if (year.isNotEmpty) years.add(year);
  }
  final list = years.toList()
    ..sort((a, b) {
      final aStart = int.tryParse(a.split('-').first) ?? 0;
      final bStart = int.tryParse(b.split('-').first) ?? 0;
      return bStart.compareTo(aStart);
    });
  return list;
}

void _showInfo(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0x66000000),
    builder: (dialogContext) => AlertDialog(
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: const Icon(
        Icons.info_rounded,
        size: 38,
        color: Color(0xFF0F766E),
      ),
      title: const Text('Notification', textAlign: TextAlign.center),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Text(message, textAlign: TextAlign.center),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
