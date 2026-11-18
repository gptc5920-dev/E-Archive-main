part of '../../dashboard_shell_page.dart';

enum _StudentFormTab { student, academic, contact, notes, dates, documents }

String _shortDepartmentLabel(String department) {
  final match = RegExp(r'\(([^)]+)\)\s*$').firstMatch(department.trim());
  if (match != null) return match.group(1)!.trim();
  return department;
}

List<DropdownMenuItem<String>> _flatProgramDropdownItems(
    List<String> programs) {
  return programs
      .map(
        (name) => DropdownMenuItem(
          value: name,
          child: Text(name, style: _studentFieldTextStyle),
        ),
      )
      .toList();
}

String? _resolvedProgramDropdownValue(
  String current,
  List<String> selectablePrograms,
) {
  final trimmed = current.trim();
  if (trimmed.isNotEmpty && selectablePrograms.contains(trimmed)) {
    return trimmed;
  }
  if (selectablePrograms.isNotEmpty) return selectablePrograms.first;
  return null;
}
