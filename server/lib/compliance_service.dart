import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'mysql_store.dart';

/// Records management, privacy, retention, and ISO compliance helpers.
class ComplianceService {
  ComplianceService(this._store);

  final MySqlStore _store;

  static const _backupFormat = 'e_archive_mysql_backup_v1';
  static const _sqlBackupFormat = 'e_archive_mysql_sql_backup_v1';
  static const _databaseDumpName = 'database.sql';
  static const _legacyDatabaseDumpName = 'database.json';
  static const _backupTables = [
    'users',
    'colleges',
    'courses',
    'students',
    'documents',
    'retention_policies',
    'access_rules',
    'audit_logs',
    'backup_records',
    'disposal_queue',
  ];

  static String hashBytes(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  Future<Map<String, Object?>> fetchOverview() async {
    final retention = await fetchRetentionMonitoring();
    final duplicates = await fetchDuplicates();
    final disposal = await fetchDisposalRecommendations();
    final privacy = await fetchPrivacyCompliance();
    final iso = await fetchIsoCompliance();
    final backups = await fetchBackups();

    final active = retention.where((r) {
      final status = (r['status'] ?? '').toString();
      return status == 'active' || status == 'expiring_soon';
    }).length;
    final expired = retention.where((r) => r['status'] == 'expired').length;

    return {
      'retention_total': retention.length,
      'retention_active': active,
      'retention_expired': expired,
      'duplicate_groups': duplicates.length,
      'disposal_pending':
          disposal.where((d) => (d['status'] ?? '') == 'pending').length,
      'privacy_score': privacy['compliance_score'],
      'iso_score': iso['overall_score'],
      'backup_count': backups.length,
      'last_backup': backups.isEmpty ? null : backups.first['created_at'],
    };
  }

  Future<List<Map<String, Object?>>> fetchRetentionPolicies() async {
    return _store.fetchRetentionPolicies();
  }

  Future<List<Map<String, Object?>>> fetchRetentionMonitoring() async {
    final policies = await _store.fetchRetentionPolicies();
    final policyByType = <String, Map<String, Object?>>{};
    for (final policy in policies) {
      policyByType[(policy['document_type'] ?? '').toString()] = policy;
    }

    final defaultYears =
        policies.isEmpty ? 7 : (policies.first['retention_years'] as int? ?? 7);

    final docs = await _store.fetchDocuments();
    final now = DateTime.now().toUtc();
    final results = <Map<String, Object?>>[];

    for (final doc in docs) {
      final docType = (doc['document_type'] ?? 'Other').toString();
      final policy = policyByType[docType] ?? policyByType['Other'];
      final years = policy?['retention_years'] as int? ?? defaultYears;
      final createdRaw = (doc['created_at'] ?? '').toString();
      final created =
          DateTime.tryParse(createdRaw.replaceFirst(' ', 'T')) ?? now;
      final expiry = created.add(Duration(days: years * 365));
      final daysLeft = expiry.difference(now).inDays;

      String status;
      if (daysLeft < 0) {
        status = 'expired';
      } else if (daysLeft <= 90) {
        status = 'expiring_soon';
      } else {
        status = 'active';
      }

      results.add({
        ...doc,
        'retention_years': years,
        'expiry_date': expiry.toIso8601String(),
        'days_remaining': daysLeft,
        'status': status,
        'legal_basis':
            policy?['legal_basis'] ?? 'RA 9470 (National Archives Act)',
        'iso_reference': policy?['iso_reference'] ?? 'ISO 15489-1:2016',
      });
    }

    results.sort((a, b) {
      final da = a['days_remaining'] as int? ?? 0;
      final db = b['days_remaining'] as int? ?? 0;
      return da.compareTo(db);
    });
    return results;
  }

  Future<List<Map<String, Object?>>> fetchAccessRules() async {
    return _store.fetchAccessRules();
  }

  bool isAccessAllowed({
    required String role,
    required String resource,
    required String action,
    List<Map<String, Object?>>? rules,
  }) {
    final normalizedRole = role.toLowerCase();
    final ruleList = rules ?? [];
    for (final rule in ruleList) {
      final ruleRole = (rule['role'] ?? '').toString().toLowerCase();
      final ruleResource = (rule['resource'] ?? '').toString();
      final ruleAction = (rule['action'] ?? '').toString();
      if (ruleRole == normalizedRole &&
          ruleResource == resource &&
          ruleAction == action) {
        return (rule['allowed'] ?? 0) == 1;
      }
    }
    return normalizedRole == 'admin';
  }

  Future<List<Map<String, Object?>>> fetchDuplicates() async {
    final docs = await _store.fetchDocuments();
    final byHash = <String, List<Map<String, Object?>>>{};

    for (final doc in docs) {
      final hash = (doc['content_hash'] ?? '').toString();
      if (hash.isEmpty) continue;
      byHash.putIfAbsent(hash, () => []).add(doc);
    }

    final groups = <Map<String, Object?>>[];
    for (final entry in byHash.entries) {
      if (entry.value.length < 2) continue;
      groups.add({
        'content_hash': entry.key,
        'count': entry.value.length,
        'documents': entry.value,
        'total_size_bytes': entry.value.fold<int>(
          0,
          (sum, d) => sum + ((d['size_bytes'] as int?) ?? 0),
        ),
      });
    }
    groups.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return groups;
  }

  Future<Map<String, Object?>> fetchDecisionAnalytics() async {
    final responses = await Future.wait([
      _store.fetchDocumentAnalytics(),
      fetchRetentionMonitoring(),
    ]);
    final analytics = responses[0] as Map<String, Object?>;
    final retention = (responses[1] as List).cast<Map<String, Object?>>();
    final byType = (analytics['by_type'] as Map).cast<String, int>();
    final byCollege = (analytics['by_college'] as Map).cast<String, int>();
    final byYear = (analytics['by_year'] as Map).cast<String, int>();
    final totalBytes = analytics['total_size_bytes'] as int? ?? 0;

    final expired = retention.where((r) => r['status'] == 'expired').length;
    final expiringSoon =
        retention.where((r) => r['status'] == 'expiring_soon').length;
    final duplicateDocs = analytics['duplicate_documents'] as int? ?? 0;

    final recommendations = <Map<String, String>>[];
    if (expired > 0) {
      recommendations.add({
        'priority': 'high',
        'title': 'Review expired records',
        'detail':
            '$expired document(s) exceeded retention period. Schedule disposal review.',
      });
    }
    if (duplicateDocs > 0) {
      recommendations.add({
        'priority': 'medium',
        'title': 'Resolve duplicate uploads',
        'detail':
            '$duplicateDocs redundant copy(ies) detected. Consolidate to save storage.',
      });
    }
    if (expiringSoon > 0) {
      recommendations.add({
        'priority': 'medium',
        'title': 'Plan upcoming disposals',
        'detail':
            '$expiringSoon document(s) expire within 90 days. Prepare approval workflow.',
      });
    }
    if (recommendations.isEmpty) {
      recommendations.add({
        'priority': 'low',
        'title': 'Records in good standing',
        'detail': 'No urgent compliance actions required at this time.',
      });
    }

    return {
      'totals': {
        'students': analytics['student_count'],
        'documents': analytics['document_count'],
        'storage_bytes': totalBytes,
        'storage_mb': (totalBytes / (1024 * 1024)).toStringAsFixed(2),
      },
      'retention_summary': {
        'active': retention.where((r) => r['status'] == 'active').length,
        'expiring_soon': expiringSoon,
        'expired': expired,
      },
      'documents_by_type': byType,
      'documents_by_college': byCollege,
      'documents_by_school_year': byYear,
      'duplicate_groups': analytics['duplicate_groups'],
      'decisions': recommendations,
    };
  }

  Future<Map<String, Object?>> createBackup(
      {String backupDirectory = ''}) async {
    final timestamp = DateTime.now().toUtc();
    final label =
        'backup_${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}${timestamp.second.toString().padLeft(2, '0')}';

    final backupBase = backupDirectory.trim().isEmpty
        ? p.join(_store.uploadsDir.parent.path, 'backups')
        : backupDirectory.trim();
    final backupRoot = Directory(p.join(backupBase, label));
    await backupRoot.create(recursive: true);
    Directory? previousUploads;
    final previousRecords = await _store.fetchBackupRecords();
    if (previousRecords.isNotEmpty) {
      final previousPath =
          (previousRecords.first['backup_path'] ?? '').toString().trim();
      if (previousPath.isNotEmpty) {
        final candidate = Directory(p.join(previousPath, 'uploads'));
        if (await candidate.exists()) previousUploads = candidate;
      }
    }

    final databaseDump = File(p.join(backupRoot.path, _databaseDumpName));
    var uploadsBytes = 0;
    final uploadsDest = Directory(p.join(backupRoot.path, 'uploads'));
    if (_store.uploadsDir.existsSync()) {
      await _copyDirectory(
        _store.uploadsDir,
        uploadsDest,
        reuseFrom: previousUploads,
      );
      uploadsBytes = await _directorySize(uploadsDest);
    }

    final databaseSummary = await _writeDatabaseDump(
      databaseDump,
      label: label,
      createdAt: timestamp,
    );
    final databaseBytes = await databaseDump.length();
    final totalBytes = databaseBytes + uploadsBytes;

    await _store.insertBackupRecord(
      label: label,
      backupPath: backupRoot.path,
      sizeBytes: totalBytes,
      status: 'completed',
    );

    await _store.insertAuditLog(
      actor: 'system',
      action: 'backup_created',
      resourceType: 'backup',
      resourceId: label,
      details:
          'Backup size: ${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB',
    );

    final manifest = {
      'label': label,
      'created_at': timestamp.toIso8601String(),
      'database': ServerConfig.mysqlDsn,
      'database_dump': _databaseDumpName,
      'database_bytes': databaseBytes,
      'tables': databaseSummary['tables'],
      'row_count': databaseSummary['row_count'],
      'uploads_bytes': uploadsBytes,
      'total_bytes': totalBytes,
    };
    await File(p.join(backupRoot.path, 'manifest.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );

    final record = (await _store.fetchBackupRecords()).firstWhere(
      (row) => (row['label'] ?? '').toString() == label,
      orElse: () => {'label': label, 'backup_path': backupRoot.path},
    );
    return {...record, 'manifest': manifest};
  }

  Future<List<Map<String, Object?>>> fetchBackups() async {
    final records = await _store.fetchBackupRecords();
    final validRecords = <Map<String, Object?>>[];
    final seenLabels = <String>{};

    Future<void> addBackupRecord(
      Map<String, Object?> record,
      String backupPath,
    ) async {
      final normalizedPath = backupPath.trim();
      if (normalizedPath.isEmpty) return;

      final manifestFile = File(p.join(normalizedPath, 'manifest.json'));
      final databaseFile = await _databaseDumpFileForBackup(normalizedPath);
      if (!manifestFile.existsSync() || !databaseFile.existsSync()) {
        return;
      }

      final manifest = await _readJsonMap(manifestFile);
      final label =
          (record['label'] ?? manifest['label'] ?? p.basename(normalizedPath))
              .toString();
      if (label.trim().isEmpty || !seenLabels.add(label)) return;

      final databaseBytes =
          _intValue(manifest['database_bytes']) ?? databaseFile.lengthSync();
      final uploadsBytes = _intValue(manifest['uploads_bytes']) ?? 0;
      final rowCount = _intValue(manifest['row_count']) ?? 0;
      final totalBytes = _intValue(manifest['total_bytes']) ??
          _intValue(record['size_bytes']) ??
          databaseBytes + uploadsBytes;
      validRecords.add({
        ...record,
        'label': label,
        'backup_path': normalizedPath,
        'created_at': record['created_at'] ?? manifest['created_at'] ?? '',
        'status': record['status'] ?? 'completed',
        'available': true,
        'database_bytes': databaseBytes,
        'database_dump': p.basename(databaseFile.path),
        'uploads_bytes': uploadsBytes,
        'row_count': rowCount,
        'size_bytes': totalBytes,
        'manifest': manifest,
      });
    }

    for (final record in records) {
      try {
        await addBackupRecord(
          record,
          (record['backup_path'] ?? '').toString(),
        );
      } catch (_) {
        continue;
      }
    }

    final backupRoot =
        Directory(p.join(_store.uploadsDir.parent.path, 'backups'));
    if (backupRoot.existsSync()) {
      for (final entity in backupRoot.listSync()) {
        if (entity is! Directory) continue;
        try {
          await addBackupRecord(
            {
              'label': p.basename(entity.path),
              'backup_path': entity.path,
              'status': 'completed',
            },
            entity.path,
          );
        } catch (_) {
          continue;
        }
      }
    }

    validRecords.sort((a, b) {
      final aDate = DateTime.tryParse('${a['created_at'] ?? ''}');
      final bDate = DateTime.tryParse('${b['created_at'] ?? ''}');
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return validRecords;
  }

  Future<File> backupDatabaseFile(String label) async {
    final records = await fetchBackups();
    final match = records.where(
      (r) => (r['label'] ?? '').toString() == label.trim(),
    );
    if (match.isEmpty) {
      throw StateError('Backup not found: $label');
    }

    final backupPath = (match.first['backup_path'] ?? '').toString();
    final databaseFile = await _databaseDumpFileForBackup(backupPath);
    if (!databaseFile.existsSync()) {
      throw StateError('Backup database dump missing');
    }
    return databaseFile;
  }

  Future<Map<String, Object?>> restoreBackup(String label) async {
    final records = await fetchBackups();
    final match = records.cast<Map<String, Object?>>().where(
          (r) => (r['label'] ?? '').toString() == label,
        );

    final backupPath = match.isNotEmpty
        ? (match.first['backup_path'] ?? '').toString()
        : p.join(_store.uploadsDir.parent.path, 'backups', label);
    if (backupPath.trim().isEmpty) {
      throw StateError('Backup not found: $label');
    }

    final backupDir = Directory(backupPath);
    if (!backupDir.existsSync()) {
      throw StateError('Backup directory missing on disk');
    }

    final databaseDump = await _databaseDumpFileForBackup(backupPath);
    if (!databaseDump.existsSync()) {
      throw StateError('Backup database dump missing');
    }

    await _restoreDatabaseDump(databaseDump);

    final uploadsBackup = Directory(p.join(backupPath, 'uploads'));
    if (uploadsBackup.existsSync()) {
      if (_store.uploadsDir.existsSync()) {
        await _store.uploadsDir.delete(recursive: true);
      }
      await _copyDirectory(uploadsBackup, _store.uploadsDir);
    }

    await _store.insertAuditLog(
      actor: 'system',
      action: 'backup_restored',
      resourceType: 'backup',
      resourceId: label,
      details: 'MySQL data and uploads restored from $label.',
    );

    return {'restored': true, 'label': label};
  }

  Future<Map<String, Object?>> restoreBackupFile(
    File source, {
    String backupDirectory = '',
  }) async {
    if (!source.existsSync()) {
      throw StateError('Selected backup file is missing.');
    }

    final timestamp = DateTime.now().toUtc();
    final isSql = p.extension(source.path).toLowerCase() == '.sql';
    final dump = isSql ? null : await _readJsonMap(source);
    if (!isSql && dump?['format'] != _backupFormat) {
      throw StateError(
          'Unsupported backup file. Please choose database.sql from an E-Archive backup.');
    }

    final originalLabel = (isSql
            ? p.basenameWithoutExtension(source.path)
            : (dump?['label'] ?? p.basenameWithoutExtension(source.path)))
        .toString()
        .trim();
    final label = 'uploaded_${_compactTimestamp(timestamp)}'
        '${originalLabel.isEmpty ? '' : '_${_safeLabelPart(originalLabel)}'}';

    final backupBase = backupDirectory.trim().isEmpty
        ? p.join(_store.uploadsDir.parent.path, 'backups')
        : backupDirectory.trim();
    final backupRoot = Directory(p.join(backupBase, label));
    await backupRoot.create(recursive: true);

    final databaseDump = File(p.join(
      backupRoot.path,
      isSql ? _databaseDumpName : _legacyDatabaseDumpName,
    ));
    await source.copy(databaseDump.path);

    var uploadsBytes = 0;
    final siblingUploads = Directory(p.join(source.parent.path, 'uploads'));
    final uploadsDest = Directory(p.join(backupRoot.path, 'uploads'));
    if (siblingUploads.existsSync()) {
      await _copyDirectory(siblingUploads, uploadsDest);
      uploadsBytes = await _directorySize(uploadsDest);
    }

    final databaseBytes = await databaseDump.length();
    final rowCount = isSql
        ? await _countSqlInserts(databaseDump)
        : _intValue(dump?['row_count']) ?? 0;
    final totalBytes = databaseBytes + uploadsBytes;
    final manifest = {
      'label': label,
      'source_label': originalLabel,
      'created_at': timestamp.toIso8601String(),
      'database': ServerConfig.mysqlDsn,
      'database_dump': p.basename(databaseDump.path),
      'database_bytes': databaseBytes,
      'row_count': rowCount,
      'uploads_bytes': uploadsBytes,
      'total_bytes': totalBytes,
      'imported_from': source.path,
    };
    await File(p.join(backupRoot.path, 'manifest.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );

    await _restoreDatabaseDump(databaseDump);

    if (uploadsDest.existsSync()) {
      if (_store.uploadsDir.existsSync()) {
        await _store.uploadsDir.delete(recursive: true);
      }
      await _copyDirectory(uploadsDest, _store.uploadsDir);
    }

    await _store.insertBackupRecord(
      label: label,
      backupPath: backupRoot.path,
      sizeBytes: totalBytes,
      status: 'uploaded',
    );

    await _store.insertAuditLog(
      actor: 'system',
      action: 'backup_uploaded_restored',
      resourceType: 'backup',
      resourceId: label,
      details: 'MySQL data restored from uploaded backup file.',
    );

    return {
      'restored': true,
      'uploaded': true,
      'label': label,
      'backup_path': backupRoot.path,
    };
  }

  Future<Map<String, Object?>> fetchPrivacyCompliance() async {
    final docs = await _store.fetchDocuments();
    final students = await _store.fetchStudents();
    final auditCount = (await _store.fetchAuditLogs(limit: 1000)).length;
    final backups = await fetchBackups();

    final checks = <Map<String, Object?>>[
      {
        'requirement': 'RA 10173 — Lawful processing basis',
        'status': 'compliant',
        'detail':
            'Records processed for legitimate educational/registrar purposes.',
        'reference': 'Data Privacy Act of 2012, Sec. 11',
      },
      {
        'requirement': 'RA 10173 — Security measures',
        'status': backups.isNotEmpty ? 'compliant' : 'partial',
        'detail': backups.isNotEmpty
            ? 'Backup procedures in place (${backups.length} backup(s)).'
            : 'No backups recorded. Create a backup to strengthen data protection.',
        'reference': 'Data Privacy Act of 2012, Sec. 20',
      },
      {
        'requirement': 'RA 10173 — Access logging',
        'status': auditCount > 0 ? 'compliant' : 'partial',
        'detail': auditCount > 0
            ? '$auditCount audit event(s) recorded.'
            : 'Enable activity logging for accountability.',
        'reference': 'NPC Circular 16-01',
      },
      {
        'requirement': 'PII inventory',
        'status': 'compliant',
        'detail':
            '${students.length} student record(s) and ${docs.length} document(s) catalogued.',
        'reference': 'RA 10173, Sec. 16 (Rights of data subjects)',
      },
      {
        'requirement': 'Retention limits',
        'status': 'compliant',
        'detail':
            'Retention policies configured per document type (ISO 15489 aligned).',
        'reference': 'RA 9470 + ISO 15489-1:2016',
      },
    ];

    final compliant = checks.where((c) => c['status'] == 'compliant').length;
    final partial = checks.where((c) => c['status'] == 'partial').length;
    final score = ((compliant + partial * 0.5) / checks.length * 100).round();

    return {
      'framework': 'Philippine Data Privacy Act (RA 10173)',
      'compliance_score': score,
      'checks': checks,
      'data_subjects': students.length,
      'personal_data_records': docs.length,
    };
  }

  Future<List<Map<String, Object?>>> fetchDisposalRecommendations() async {
    final retention = await fetchRetentionMonitoring();
    final existing = await _store.fetchDisposalQueue();
    final existingByDoc = {
      for (final row in existing) (row['document_id'] as int? ?? -1): row,
    };

    final recommendations = <Map<String, Object?>>[];
    for (final row in retention) {
      final status = (row['status'] ?? '').toString();
      if (status != 'expired' && status != 'expiring_soon') continue;

      final docId = row['id'] as int?;
      if (docId == null) continue;

      final queued = existingByDoc[docId];
      if (queued != null) {
        recommendations.add({...queued, 'document': row});
        continue;
      }

      final reason = status == 'expired'
          ? 'Retention period exceeded'
          : 'Retention period ends within 90 days';

      recommendations.add({
        'document_id': docId,
        'status': 'pending',
        'reason': reason,
        'recommended_date': row['expiry_date'],
        'document': row,
      });
    }

    recommendations.sort((a, b) {
      final sa = (a['document'] as Map?)?['status']?.toString() ?? '';
      final sb = (b['document'] as Map?)?['status']?.toString() ?? '';
      if (sa == 'expired' && sb != 'expired') return -1;
      if (sb == 'expired' && sa != 'expired') return 1;
      return 0;
    });
    return recommendations;
  }

  Future<List<Map<String, Object?>>> fetchDisposableStudentRecords() async {
    final rows = await _store.fetchDisposableStudentRecords();
    final now = DateTime.now().toUtc();
    final results = <Map<String, Object?>>[];
    for (final row in rows) {
      final graduationDate = (row['graduation_date'] ?? '').toString().trim();
      final enrollmentDate =
          (row['last_enrollment_date'] ?? '').toString().trim();
      final createdAt = (row['created_at'] ?? '').toString().trim();
      final retentionRaw = graduationDate.isNotEmpty
          ? graduationDate
          : (enrollmentDate.isNotEmpty ? enrollmentDate : createdAt);
      final retentionDate = _parseDate(retentionRaw);
      if (retentionDate == null) continue;

      final basis = graduationDate.isNotEmpty
          ? 'Graduation Date'
          : (enrollmentDate.isNotEmpty
              ? 'Last Enrollment Date'
              : 'Institution Retention Basis');
      final yearsStored = now.difference(retentionDate.toUtc()).inDays ~/ 365;
      final disposalStatus =
          (row['disposal_status'] ?? 'pending').toString().trim();

      results.add({
        'student_name': row['full_name'] ?? '',
        'student_id': row['student_no'] ?? '',
        'course_program': row['course'] ?? '',
        'graduation_last_enrollment_date': _dateOnly(retentionDate),
        'retention_basis': basis,
        'years_stored': yearsStored,
        'disposal_status':
            disposalStatus.isEmpty ? 'pending' : disposalStatus.toLowerCase(),
        'approved_at': row['disposal_approved_at'] ?? '',
        'approved_by': row['disposal_approved_by'] ?? '',
        'disposed_at': row['disposed_at'] ?? '',
        'notes': row['disposal_notes'] ?? '',
      });
    }

    results.sort((a, b) {
      final statusOrder = {
        'pending': 0,
        'approved': 1,
        'disposed': 2,
      };
      final sa = statusOrder[(a['disposal_status'] ?? '').toString()] ?? 3;
      final sb = statusOrder[(b['disposal_status'] ?? '').toString()] ?? 3;
      if (sa != sb) return sa.compareTo(sb);
      final ya = a['years_stored'] as int? ?? 0;
      final yb = b['years_stored'] as int? ?? 0;
      return yb.compareTo(ya);
    });
    return results;
  }

  Future<Map<String, Object?>> approveStudentDisposal(
    String studentNo, {
    String actor = 'admin',
  }) async {
    final row = await _store.updateStudentDisposalStatus(
      studentNo: studentNo,
      status: 'approved',
      actor: actor,
      notes: 'Approved for disposal after 20-year retention review.',
    );
    if (row == null) throw StateError('Student record not found');
    await _store.insertAuditLog(
      actor: actor,
      action: 'student_disposal_approved',
      resourceType: 'student',
      resourceId: studentNo,
      details: 'Record approved for soft disposal after retention review.',
    );
    return row;
  }

  Future<Map<String, Object?>> markStudentDisposed(
    String studentNo, {
    String actor = 'admin',
  }) async {
    final row = await _store.updateStudentDisposalStatus(
      studentNo: studentNo,
      status: 'disposed',
      actor: actor,
      notes: 'Soft-disposed and retained in archive for audit traceability.',
    );
    if (row == null) throw StateError('Student record not found');
    await _store.insertAuditLog(
      actor: actor,
      action: 'student_marked_disposed',
      resourceType: 'student',
      resourceId: studentNo,
      details: 'Record marked disposed without permanent deletion.',
    );
    return row;
  }

  Future<Map<String, Object?>> fetchDisposableStudentReport() async {
    final rows = await fetchDisposableStudentRecords();
    int countStatus(String status) => rows
        .where((row) => (row['disposal_status'] ?? '').toString() == status)
        .length;
    return {
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'retention_years': 20,
      'pending': countStatus('pending'),
      'approved': countStatus('approved'),
      'disposed': countStatus('disposed'),
      'total': rows.length,
      'records': rows,
    };
  }

  Future<Map<String, Object?>> approveDisposal(int documentId) async {
    final row = await _store.upsertDisposalQueue(
      documentId: documentId,
      status: 'approved',
      reason: 'Approved for secure disposal',
    );
    await _store.insertAuditLog(
      actor: 'admin',
      action: 'disposal_approved',
      resourceType: 'document',
      resourceId: '$documentId',
      details: 'Disposal approved per retention policy',
    );
    return row;
  }

  Future<Map<String, Object?>> fetchIsoCompliance() async {
    final policies = await _store.fetchRetentionPolicies();
    final auditLogs = await _store.fetchAuditLogs(limit: 50);
    final accessRules = await _store.fetchAccessRules();
    final docs = await _store.fetchDocuments();

    final controls = <Map<String, Object?>>[
      {
        'standard': 'ISO 15489-1:2016',
        'control': 'Records classification',
        'status': docs.isNotEmpty ? 'implemented' : 'partial',
        'detail':
            'Documents classified by type, college, program, and school year.',
      },
      {
        'standard': 'ISO 15489-1:2016',
        'control': 'Retention schedules',
        'status': policies.isNotEmpty ? 'implemented' : 'not_implemented',
        'detail': '${policies.length} retention polic(ies) defined.',
      },
      {
        'standard': 'ISO 15489-1:2016',
        'control': 'Metadata capture',
        'status': 'implemented',
        'detail':
            'Document metadata includes student, program, school year, and storage path.',
      },
      {
        'standard': 'ISO 30301:2019',
        'control': 'Access control rules',
        'status': accessRules.isNotEmpty ? 'implemented' : 'partial',
        'detail': '${accessRules.length} rule-based access polic(ies) active.',
      },
      {
        'standard': 'ISO 27001:2022',
        'control': 'Audit trail',
        'status': auditLogs.isNotEmpty ? 'implemented' : 'partial',
        'detail': '${auditLogs.length} audit event(s) on record.',
      },
      {
        'standard': 'ISO 15489-1:2016',
        'control': 'Disposal procedures',
        'status': 'implemented',
        'detail':
            'Disposal recommendations generated from retention monitoring.',
      },
    ];

    final implemented =
        controls.where((c) => c['status'] == 'implemented').length;
    final partial = controls.where((c) => c['status'] == 'partial').length;
    final score =
        ((implemented + partial * 0.5) / controls.length * 100).round();

    return {
      'standards': ['ISO 15489-1:2016', 'ISO 30301:2019', 'ISO 27001:2022'],
      'overall_score': score,
      'controls': controls,
    };
  }

  Future<Map<String, Object?>> logAudit({
    required String actor,
    required String action,
    String resourceType = '',
    String resourceId = '',
    String details = '',
  }) async {
    return _store.insertAuditLog(
      actor: actor,
      action: action,
      resourceType: resourceType,
      resourceId: resourceId,
      details: details,
    );
  }

  Future<List<Map<String, Object?>>> fetchAuditLogs({int limit = 100}) async {
    return _store.fetchAuditLogs(limit: limit);
  }

  Future<Map<String, Object?>?> findDuplicateByHash(String hash) async {
    if (hash.isEmpty) return null;
    return _store.findDocumentByHash(hash);
  }

  Future<void> _copyDirectory(
    Directory source,
    Directory dest, {
    Directory? reuseFrom,
  }) async {
    await dest.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final name = p.basename(entity.path);
      final target = p.join(dest.path, name);
      if (entity is File) {
        final reusable =
            reuseFrom == null ? null : File(p.join(reuseFrom.path, name));
        if (!await _tryCreateSnapshotLink(entity, reusable, target)) {
          await entity.copy(target);
        }
      } else if (entity is Directory) {
        await _copyDirectory(
          entity,
          Directory(target),
          reuseFrom: reuseFrom == null
              ? null
              : Directory(p.join(reuseFrom.path, name)),
        );
      }
    }
  }

  Future<bool> _tryCreateSnapshotLink(
    File source,
    File? reusable,
    String target,
  ) async {
    if (reusable == null || !await reusable.exists()) return false;
    if (await source.length() != await reusable.length()) return false;
    try {
      final result = Platform.isWindows
          ? await Process.run(
              'fsutil',
              ['hardlink', 'create', target, reusable.path],
              runInShell: false,
            )
          : await Process.run(
              'ln',
              [reusable.path, target],
              runInShell: false,
            );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<int> _directorySize(Directory dir) async {
    var total = 0;
    if (!dir.existsSync()) return 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  Future<Map<String, Object?>> _writeDatabaseDump(
    File target, {
    required String label,
    required DateTime createdAt,
  }) async {
    final tableCounts = <String, int>{};
    var rowCount = 0;
    final sink = target.openWrite();
    try {
      sink
        ..writeln('-- E-Archive MySQL backup')
        ..writeln('-- format: $_sqlBackupFormat')
        ..writeln('-- label: $label')
        ..writeln('-- created_at: ${createdAt.toIso8601String()}')
        ..writeln('-- database: ${ServerConfig.mysqlDatabase}')
        ..writeln('SET FOREIGN_KEY_CHECKS = 0;')
        ..writeln();

      for (final table in _backupTables) {
        var tableCount = 0;
        var lastId = 0;
        sink.writeln('DELETE FROM ${_identifier(table)};');
        while (true) {
          final rows = await _store.db.rawQuery(
            'SELECT * FROM ${_identifier(table)} '
            'WHERE id > ? ORDER BY id ASC LIMIT 1000',
            [lastId],
          );
          if (rows.isEmpty) break;
          for (final row in rows) {
            if (row.isEmpty) continue;
            final columns = row.keys.toList();
            final values = columns.map((column) => _sqlLiteral(row[column]));
            sink.writeln(
              'INSERT INTO ${_identifier(table)} '
              '(${columns.map(_identifier).join(', ')}) '
              'VALUES (${values.join(', ')});',
            );
          }
          tableCount += rows.length;
          rowCount += rows.length;
          final id = rows.last['id'];
          if (id is! num) break;
          lastId = id.toInt();
          if (rows.length < 1000) break;
        }
        tableCounts[table] = tableCount;
        sink
          ..writeln('-- table: $table rows: $tableCount')
          ..writeln();
      }
      sink
        ..writeln('SET FOREIGN_KEY_CHECKS = 1;')
        ..writeln('-- row_count: $rowCount');
    } finally {
      await sink.flush();
      await sink.close();
    }

    return {'tables': tableCounts, 'row_count': rowCount};
  }

  Future<void> _restoreDatabaseDump(File source) async {
    if (p.extension(source.path).toLowerCase() == '.sql') {
      await _restoreSqlDump(source);
      return;
    }

    final dump = await _readJsonMap(source);
    if (dump['format'] != _backupFormat) {
      throw StateError('Unsupported backup format');
    }

    final tables = dump['tables'];
    if (tables is! Map) {
      throw StateError('Backup table data is missing');
    }

    await _store.db.execute('SET FOREIGN_KEY_CHECKS = 0');
    try {
      for (final table in _backupTables.reversed) {
        if (tables[table] != null) {
          await _store.db.rawDelete('DELETE FROM ${_identifier(table)}');
        }
      }

      for (final table in _backupTables) {
        final tableData = tables[table];
        if (tableData is! Map) continue;
        final rows = tableData['rows'];
        if (rows is! List) continue;

        for (final row in rows) {
          if (row is! Map || row.isEmpty) continue;
          final columns = row.keys.map((key) => key.toString()).toList();
          final placeholders = List.filled(columns.length, '?').join(', ');
          final sql = 'INSERT INTO ${_identifier(table)} '
              '(${columns.map(_identifier).join(', ')}) '
              'VALUES ($placeholders)';
          final values = [
            for (final column in columns) _restoreValue(column, row[column]),
          ];
          await _store.db.rawInsert(sql, values);
        }
      }
    } finally {
      await _store.db.execute('SET FOREIGN_KEY_CHECKS = 1');
    }
  }

  Future<void> _restoreSqlDump(File source) async {
    final text = await source.readAsString();
    if (!text.contains('format: $_sqlBackupFormat')) {
      throw StateError('Unsupported SQL backup format');
    }

    final statements = _splitSqlStatements(text);
    await _store.db.execute('SET FOREIGN_KEY_CHECKS = 0');
    try {
      for (final statement in statements) {
        var trimmed = statement.trim();
        if (trimmed.isEmpty) continue;
        if (trimmed.startsWith('--')) continue;
        if (trimmed.endsWith(';')) {
          trimmed = trimmed.substring(0, trimmed.length - 1).trim();
        }
        await _store.db.execute(trimmed);
      }
    } finally {
      await _store.db.execute('SET FOREIGN_KEY_CHECKS = 1');
    }
  }

  Future<File> _databaseDumpFileForBackup(String backupPath) async {
    final sqlFile = File(p.join(backupPath, _databaseDumpName));
    if (await sqlFile.exists()) return sqlFile;

    final manifestFile = File(p.join(backupPath, 'manifest.json'));
    if (await manifestFile.exists()) {
      try {
        final manifest = await _readJsonMap(manifestFile);
        final dumpName = (manifest['database_dump'] ?? '').toString().trim();
        if (dumpName.isNotEmpty) {
          final manifestFile = File(p.join(backupPath, dumpName));
          if (await manifestFile.exists()) return manifestFile;
        }
      } catch (_) {
        // Fall through to legacy filename probing.
      }
    }

    return File(p.join(backupPath, _legacyDatabaseDumpName));
  }

  Future<int> _countSqlInserts(File source) async {
    if (!await source.exists()) return 0;
    final text = await source.readAsString();
    return RegExp(r'^\s*INSERT\s+INTO\s+', multiLine: true)
        .allMatches(text)
        .length;
  }

  List<String> _splitSqlStatements(String sql) {
    final statements = <String>[];
    final current = StringBuffer();
    var inString = false;

    for (var i = 0; i < sql.length; i += 1) {
      final char = sql[i];
      final next = i + 1 < sql.length ? sql[i + 1] : '';

      if (!inString && char == '-' && next == '-') {
        while (i < sql.length && sql[i] != '\n') {
          i += 1;
        }
        continue;
      }

      current.write(char);
      if (char == "'") {
        if (inString && next == "'") {
          current.write(next);
          i += 1;
        } else {
          inString = !inString;
        }
      } else if (char == ';' && !inString) {
        statements.add(current.toString());
        current.clear();
      }
    }

    final tail = current.toString().trim();
    if (tail.isNotEmpty) statements.add(tail);
    return statements;
  }

  String _sqlLiteral(Object? value) {
    if (value == null) return 'NULL';
    if (value is bool) return value ? '1' : '0';
    if (value is num) return value.toString();
    if (value is DateTime) return "'${_mysqlDateTime(value.toUtc())}'";
    final text = value.toString().replaceAll(r'\', r'\\').replaceAll("'", "''");
    return "'$text'";
  }

  Future<Map<String, Object?>> _readJsonMap(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw StateError('Invalid JSON file: ${file.path}');
    }
    return decoded.cast<String, Object?>();
  }

  int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Object? _restoreValue(String column, Object? value) {
    if (value is String &&
        (column == 'created_at' ||
            column == 'last_login_at' ||
            column.endsWith('_at'))) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return _mysqlDateTime(parsed.toUtc());
      }
    }
    return value;
  }

  DateTime? _parseDate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return DateTime.tryParse(trimmed.replaceFirst(' ', 'T'));
  }

  String _dateOnly(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}-'
        '${two(value.month)}-${two(value.day)}';
  }

  String _mysqlDateTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    final month = two(value.month);
    final day = two(value.day);
    final hour = two(value.hour);
    final minute = two(value.minute);
    final second = two(value.second);
    return '${value.year}-$month-$day $hour:$minute:$second';
  }

  String _compactTimestamp(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}_'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}';
  }

  String _safeLabelPart(String value) {
    final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    return safe.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  }

  String _identifier(String value) {
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(value)) {
      throw ArgumentError.value(value, 'identifier', 'Invalid SQL identifier');
    }
    return '`$value`';
  }
}
