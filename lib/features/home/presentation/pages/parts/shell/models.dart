part of '../../dashboard_shell_page.dart';

class _StudentRow {
  _StudentRow({
    this.id,
    required this.studentNo,
    required this.fullName,
    required this.course,
    required this.year,
    required this.status,
    required this.email,
    this.schoolYear = '',
    this.sex = '',
    this.birthDate = '',
    this.phoneNumber = '',
    this.notes = '',
    this.graduationDate = '',
    this.lastEnrollmentDate = '',
  });

  final int? id;
  final String studentNo;
  final String fullName;
  final String course;
  final int year;
  final String status;
  final String? email;
  final String schoolYear;
  final String sex;
  final String birthDate;
  final String phoneNumber;
  final String notes;
  final String graduationDate;
  final String lastEnrollmentDate;
}

class _CourseRow {
  const _CourseRow({this.id, required this.name, this.collegeId, this.code});
  final int? id;
  final String name;
  final int? collegeId;
  final String? code;
}

class _DocRow {
  const _DocRow({
    this.id = '',
    required this.title,
    required this.student,
    required this.type,
    required this.size,
    required this.uploaded,
    this.schoolYear = '',
    this.studentNo = '',
    this.program = '',
    this.college = '',
    this.documentType = '',
    this.storagePath = '',
    this.tags = '',
    this.uploader = '',
    this.deletedAt = '',
    this.deletedBy = '',
    this.localFilePath,
    this.localImagePath,
    this.remoteImageUrl = '',
  });

  final String id;
  final String title;
  final String student;
  final String type;
  final String size;
  final String uploaded;
  final String schoolYear;
  final String studentNo;
  final String program;
  final String college;
  final String documentType;
  final String storagePath;
  final String tags;
  final String uploader;
  final String deletedAt;
  final String deletedBy;
  final String? localFilePath;
  final String? localImagePath;
  final String remoteImageUrl;
}

class _AuditRow {
  factory _AuditRow({
    Object? actor,
    Object? action,
    Object? date,
    Object? resourceType,
    Object? resourceId,
    Object? details,
  }) {
    return _AuditRow._(
      actor: _auditText(actor, fallback: 'system'),
      action: _auditText(action),
      date: _auditText(date),
      resourceType: _auditText(resourceType),
      resourceId: _auditText(resourceId),
      details: _auditText(details),
    );
  }

  const _AuditRow._({
    required this.actor,
    required this.action,
    required this.date,
    required this.resourceType,
    required this.resourceId,
    required this.details,
  });

  final String actor;
  final String action;
  final String date;
  final String resourceType;
  final String resourceId;
  final String details;

  String get actionLabel {
    final words = action
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\bdeleted\b', caseSensitive: false), 'removed')
        .replaceAll(RegExp(r'\bdelete\b', caseSensitive: false), 'remove')
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}');
    return words.isEmpty ? 'System Activity' : words.join(' ');
  }

  String get resourceLabel {
    final type = resourceType.trim();
    final id = resourceId.trim();
    if (type.isEmpty && id.isEmpty) return '-';
    if (type.isEmpty) return id;
    if (id.isEmpty) return type;
    return '$type #$id';
  }
}

String _auditText(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
  return text;
}

class _ComplianceDecisionRow {
  const _ComplianceDecisionRow({
    required this.priority,
    required this.title,
    required this.detail,
  });

  final String priority;
  final String title;
  final String detail;
}

class _ComplianceDashboardData {
  const _ComplianceDashboardData({
    this.retentionActive = 0,
    this.retentionExpired = 0,
    this.duplicateGroups = 0,
    this.disposalPending = 0,
    this.privacyScore = 0,
    this.isoScore = 0,
    this.backupCount = 0,
    this.decisionCount = 0,
    this.lastBackup,
    this.decisions = const [],
  });

  final int retentionActive;
  final int retentionExpired;
  final int duplicateGroups;
  final int disposalPending;
  final int privacyScore;
  final int isoScore;
  final int backupCount;
  final int decisionCount;
  final String? lastBackup;
  final List<_ComplianceDecisionRow> decisions;
}
