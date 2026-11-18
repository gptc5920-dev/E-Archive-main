import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:e_archive_server/compliance_service.dart';
import 'package:e_archive_server/document_classifier.dart';
import 'package:e_archive_server/mysql_store.dart';
import 'package:path/path.dart' as p;

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  final MySqlStore _store = MySqlStore();
  ComplianceService? _compliance;
  bool _initialized = false;
  Future<void>? _initialization;
  String _backupLocation = '';

  String userRole = '';
  String userName = 'system';

  Future<void> ensureInitialized() {
    if (_initialized) return Future<void>.value();
    return _initialization ??= _initialize().whenComplete(() {
      _initialization = null;
    });
  }

  Future<void> _initialize() async {
    try {
      final root = await _dataRoot();
      await root.create(recursive: true);
      final uploadsDir = Directory(p.join(root.path, 'uploads'));

      await _store.open(uploadsDir);
      _compliance = ComplianceService(_store);
      final configuredLocation = File(p.join(root.path, 'backup_location.txt'));
      if (await configuredLocation.exists()) {
        _backupLocation = (await configuredLocation.readAsString()).trim();
      }
      if (_backupLocation.isEmpty) {
        _backupLocation = p.join(root.path, 'backups');
      }
      await Directory(_backupLocation).create(recursive: true);
      _initialized = true;
    } catch (_) {
      await _store.close();
      rethrow;
    }
  }

  Future<List<Map<String, Object?>>> fetchStudents({
    int? courseId,
    String? course,
  }) async {
    await ensureInitialized();
    return _store.fetchStudents(courseId: courseId, courseName: course);
  }

  Future<Map<String, Object?>> insertStudent({
    required String studentNo,
    required String fullName,
    required String course,
    required int year,
    required String status,
    String schoolYear = '',
    String email = '',
    String sex = '',
    String birthDate = '',
    String phoneNumber = '',
    String notes = '',
    String graduationDate = '',
    String lastEnrollmentDate = '',
    String retentionBasis = 'graduation_date',
  }) async {
    await ensureInitialized();
    final row = await _store.insertStudent(
      studentNo: studentNo,
      fullName: fullName,
      course: course,
      year: year,
      status: status,
      schoolYear: schoolYear,
      email: email,
      sex: sex,
      birthDate: birthDate,
      phoneNumber: phoneNumber,
      notes: notes,
      graduationDate: graduationDate,
      lastEnrollmentDate: lastEnrollmentDate,
      retentionBasis: retentionBasis,
    );
    await _audit(
      action: 'student_created',
      resourceType: 'student',
      resourceId: '${row['id']}',
      details: fullName,
    );
    return row;
  }

  Future<Map<String, Object?>?> updateStudent({
    required int id,
    required String studentNo,
    required String fullName,
    required String course,
    required int year,
    required String status,
    String schoolYear = '',
    String email = '',
    String sex = '',
    String birthDate = '',
    String phoneNumber = '',
    String notes = '',
    String graduationDate = '',
    String lastEnrollmentDate = '',
    String retentionBasis = 'graduation_date',
  }) async {
    await ensureInitialized();
    final row = await _store.updateStudent(
      id: id,
      studentNo: studentNo,
      fullName: fullName,
      course: course,
      year: year,
      status: status,
      schoolYear: schoolYear,
      email: email,
      sex: sex,
      birthDate: birthDate,
      phoneNumber: phoneNumber,
      notes: notes,
      graduationDate: graduationDate,
      lastEnrollmentDate: lastEnrollmentDate,
      retentionBasis: retentionBasis,
    );
    if (row != null) {
      await _audit(
        action: 'student_updated',
        resourceType: 'student',
        resourceId: '$id',
        details: fullName,
      );
    }
    return row;
  }

  Future<bool> deleteStudent(int id) async {
    await ensureInitialized();
    await _requireAccess(resource: 'students', action: 'delete');
    final ok = await _store.deleteStudent(id, deletedBy: userName);
    if (ok) {
      await _audit(
        action: 'student_deleted',
        resourceType: 'student',
        resourceId: '$id',
      );
    }
    return ok;
  }

  Future<List<Map<String, Object?>>> fetchDeletedStudents() async {
    await ensureInitialized();
    return _store.fetchDeletedStudents();
  }

  Future<bool> restoreStudent(int id) async {
    await ensureInitialized();
    await _requireAccess(resource: 'students', action: 'delete');
    final ok = await _store.restoreStudent(id);
    if (ok) {
      await _audit(
        action: 'student_restored',
        resourceType: 'student',
        resourceId: '$id',
      );
    }
    return ok;
  }

  Future<bool> purgeStudent(int id) async {
    await ensureInitialized();
    await _requireAccess(resource: 'students', action: 'delete');
    final ok = await _store.purgeStudent(id);
    if (ok) {
      await _audit(
        action: 'student_removed',
        resourceType: 'student',
        resourceId: '$id',
      );
    }
    return ok;
  }

  Future<List<Map<String, Object?>>> fetchCourses({int? collegeId}) async {
    await ensureInitialized();
    return _store.fetchCourses(collegeId: collegeId);
  }

  Future<Map<String, Object?>> insertCourse({
    required String name,
    int? collegeId,
  }) async {
    await ensureInitialized();
    final row = await _store.insertCourse(name: name, collegeId: collegeId);
    await _audit(
      action: 'course_created',
      resourceType: 'course',
      resourceId: '${row['id']}',
      details: name,
    );
    return row;
  }

  Future<Map<String, Object?>> updateCourse({
    required int id,
    required String name,
    int? collegeId,
  }) async {
    await ensureInitialized();
    final row = await _store.updateCourse(
      id: id,
      name: name,
      collegeId: collegeId,
    );
    if (row == null) throw StateError('Program not found');
    await _audit(
      action: 'course_updated',
      resourceType: 'course',
      resourceId: '$id',
      details: name,
    );
    return row;
  }

  Future<bool> deleteCourse(int id) async {
    await ensureInitialized();
    await _requireAccess(resource: 'courses', action: 'delete');
    final ok = await _store.deleteCourse(id);
    if (ok) {
      await _audit(
        action: 'course_deleted',
        resourceType: 'course',
        resourceId: '$id',
      );
    }
    return ok;
  }

  Future<List<Map<String, Object?>>> fetchColleges() async {
    await ensureInitialized();
    return _store.fetchColleges();
  }

  Future<List<Map<String, Object?>>> fetchDeletedColleges() async {
    await ensureInitialized();
    return _store.fetchDeletedColleges();
  }

  Future<Map<String, Object?>> insertCollege({required String name}) async {
    await ensureInitialized();
    final row = await _store.insertCollege(name: name);
    await _audit(
      action: 'college_created',
      resourceType: 'college',
      resourceId: '${row['id']}',
      details: name,
    );
    return row;
  }

  Future<Map<String, Object?>> updateCollege({
    required int id,
    required String name,
  }) async {
    await ensureInitialized();
    final row = await _store.updateCollege(id: id, name: name);
    if (row == null) throw StateError('College not found');
    await _audit(
      action: 'college_updated',
      resourceType: 'college',
      resourceId: '$id',
      details: name,
    );
    return row;
  }

  Future<bool> deleteCollege(int id) async {
    await ensureInitialized();
    await _requireAccess(resource: 'colleges', action: 'delete');
    final ok = await _store.deleteCollege(id, deletedBy: userName);
    if (ok) {
      await _audit(
        action: 'college_deleted',
        resourceType: 'college',
        resourceId: '$id',
      );
    }
    return ok;
  }

  Future<bool> restoreCollege(int id) async {
    await ensureInitialized();
    await _requireAccess(resource: 'colleges', action: 'delete');
    final ok = await _store.restoreCollege(id);
    if (ok) {
      await _audit(
        action: 'college_restored',
        resourceType: 'college',
        resourceId: '$id',
      );
    }
    return ok;
  }

  Future<bool> purgeCollege(int id) async {
    await ensureInitialized();
    await _requireAccess(resource: 'colleges', action: 'delete');
    final ok = await _store.purgeCollege(id);
    if (ok) {
      await _audit(
        action: 'college_removed',
        resourceType: 'college',
        resourceId: '$id',
      );
    }
    return ok;
  }

  Future<List<Map<String, Object?>>> fetchDocuments() async {
    await ensureInitialized();
    return _store.fetchDocuments();
  }

  Future<Map<String, Object?>> fetchDocumentPage({
    int limit = 100,
    int? beforeId,
    bool includeTotal = true,
    String search = '',
    String schoolYear = '',
    String college = '',
    String program = '',
    String documentType = '',
  }) async {
    await ensureInitialized();
    return _store.fetchDocumentPage(
      limit: limit,
      beforeId: beforeId,
      includeTotal: includeTotal,
      search: search,
      schoolYear: schoolYear,
      college: college,
      program: program,
      documentType: documentType,
    );
  }

  Future<Map<String, Object?>> fetchDocumentSummary() async {
    await ensureInitialized();
    return _store.fetchDocumentSummary();
  }

  Future<List<Map<String, Object?>>> fetchDeletedDocuments() async {
    await ensureInitialized();
    return _store.fetchDeletedDocuments();
  }

  Future<Map<String, Object?>> insertDocument({
    required String title,
    required String student,
    required String sourceImagePath,
    String mimeType = 'image',
    String studentNo = '',
    String course = '',
    String program = '',
    String schoolYear = '',
    String documentType = '',
    bool isComplete = true,
    String college = '',
    String studentCategory = '',
    String tags = '',
    String storagePath = '',
  }) async {
    await ensureInitialized();
    await _requireAccess(resource: 'documents', action: 'upload');
    final source = File(sourceImagePath);
    if (!await source.exists()) {
      throw StateError('Image file not found: $sourceImagePath');
    }

    final sizeBytes = await source.length();
    final contentHash = (await sha256.bind(source.openRead()).first).toString();
    final originalName = p.basename(sourceImagePath);
    final safeName = _safeFileName(originalName);

    var resolvedProgram = program.trim();
    if (resolvedProgram.isEmpty && course.trim().isNotEmpty) {
      resolvedProgram =
          (await _store.programCodeForCourse(course.trim())) ?? course.trim();
    }

    var resolvedCollege = college.trim();
    if (resolvedCollege.isEmpty && course.trim().isNotEmpty) {
      resolvedCollege =
          (await _store.collegeNameForCourse(course.trim())) ?? '';
    }

    var resolvedCategory = studentCategory.trim();
    if (resolvedCategory.isEmpty) resolvedCategory = 'Graduated';
    final resolvedDocumentType =
        documentType.trim().isEmpty ? 'Other' : documentType.trim();

    final baseRelativePath = DocumentClassifier.buildRelativePath(
      schoolYear: schoolYear.trim().isEmpty ? 'Unknown' : schoolYear.trim(),
      college: resolvedCollege.isEmpty ? 'General' : resolvedCollege,
      program: resolvedProgram.isEmpty ? 'General' : resolvedProgram,
      studentCategory: resolvedCategory,
      studentNo: studentNo.trim(),
      studentName: student.trim(),
      documentType: resolvedDocumentType,
      fileName: safeName,
      isComplete: isComplete,
    );
    final relativePath = await _uniqueUploadRelativePath(baseRelativePath);

    final uploadsRoot = p.normalize(_store.uploadsDir.absolute.path);
    final destinationPath = p.normalize(
      p.join(uploadsRoot, relativePath),
    );
    if (!p.isWithin(uploadsRoot, destinationPath)) {
      throw StateError('The generated upload path is invalid.');
    }
    final destination = File(destinationPath);
    await destination.parent.create(recursive: true);
    await source.openRead().pipe(destination.openWrite());

    final row = await _store.insertDocument(
      title: title.trim().isEmpty ? 'Untitled' : title.trim(),
      student: student.trim(),
      imagePath: destination.path,
      mimeType: mimeType.trim().isEmpty ? 'image' : mimeType.trim(),
      sizeBytes: sizeBytes,
      documentType: resolvedDocumentType,
      schoolYear: schoolYear.trim(),
      program: resolvedProgram,
      studentNo: studentNo.trim(),
      storagePath: storagePath.trim().isEmpty
          ? relativePath.replaceAll(Platform.pathSeparator, '/')
          : storagePath.trim(),
      college: resolvedCollege.isEmpty ? 'General' : resolvedCollege,
      studentCategory: DocumentClassifier.normalizeCategory(resolvedCategory),
      contentHash: contentHash,
      tags: tags.trim(),
      uploader: userName.trim().isEmpty ? 'system' : userName.trim(),
    );

    await _audit(
      action: 'document_uploaded',
      resourceType: 'document',
      resourceId: '${row['id']}',
      details: title,
    );

    final duplicate = await _compliance!.findDuplicateByHash(contentHash);
    return {
      ...row,
      'duplicate_detected': duplicate != null && duplicate['id'] != row['id'],
      'duplicate_of': duplicate?['id'],
    };
  }

  Future<String> _uniqueUploadRelativePath(String relativePath) async {
    var candidate = relativePath;
    var destination = File(p.join(_store.uploadsDir.path, candidate));
    if (!await destination.exists()) return candidate;

    final directory = p.dirname(relativePath);
    final extension = p.extension(relativePath);
    final stem = p.basenameWithoutExtension(relativePath);
    var index = 2;
    do {
      candidate = p.join(directory, '$stem-$index$extension');
      destination = File(p.join(_store.uploadsDir.path, candidate));
      index++;
    } while (await destination.exists());
    return candidate;
  }

  Future<bool> deleteDocument(int id, {bool deleteFile = true}) async {
    await ensureInitialized();
    await _requireAccess(resource: 'documents', action: 'delete');
    final ok = await _store.deleteDocument(id, deletedBy: userName);
    if (ok) {
      await _audit(
        action: 'document_deleted',
        resourceType: 'document',
        resourceId: '$id',
      );
    }
    return ok;
  }

  Future<bool> restoreDocument(int id) async {
    await ensureInitialized();
    await _requireAccess(resource: 'documents', action: 'delete');
    final ok = await _store.restoreDocument(id);
    if (ok) {
      await _audit(
        action: 'document_restored',
        resourceType: 'document',
        resourceId: '$id',
      );
    }
    return ok;
  }

  Future<bool> purgeDocument(int id) async {
    await ensureInitialized();
    await _requireAccess(resource: 'documents', action: 'delete');
    final ok = await _store.purgeDocument(id);
    if (ok) {
      await _audit(
        action: 'document_removed',
        resourceType: 'document',
        resourceId: '$id',
      );
    }
    return ok;
  }

  Future<Map<String, Object?>> fetchComplianceOverview() async {
    await ensureInitialized();
    return _compliance!.fetchOverview();
  }

  Future<List<Map<String, Object?>>> fetchRetentionMonitoring() async {
    await ensureInitialized();
    return _compliance!.fetchRetentionMonitoring();
  }

  Future<List<Map<String, Object?>>> fetchRetentionPolicies() async {
    await ensureInitialized();
    return _compliance!.fetchRetentionPolicies();
  }

  Future<List<Map<String, Object?>>> fetchAccessRules() async {
    await ensureInitialized();
    return _compliance!.fetchAccessRules();
  }

  Future<List<Map<String, Object?>>> fetchDuplicateGroups() async {
    await ensureInitialized();
    return _compliance!.fetchDuplicates();
  }

  Future<Map<String, Object?>> fetchComplianceAnalytics() async {
    await ensureInitialized();
    return _compliance!.fetchDecisionAnalytics();
  }

  Future<Map<String, Object?>> createBackup() async {
    await ensureInitialized();
    await _requireAccess(resource: 'compliance', action: 'manage');
    final row = await _compliance!.createBackup(
      backupDirectory: _backupLocation,
    );
    await _audit(
      action: 'backup_created',
      resourceType: 'backup',
      resourceId: '${row['label'] ?? ''}',
      details: 'Backup created by user.',
    );
    return row;
  }

  Future<List<Map<String, Object?>>> fetchBackups() async {
    await ensureInitialized();
    return _compliance!.fetchBackups();
  }

  Future<Map<String, Object?>> restoreBackup(String label) async {
    await ensureInitialized();
    await _requireAccess(resource: 'backup', action: 'restore');
    final row = await _compliance!.restoreBackup(label);
    await _audit(
      action: 'backup_restored',
      resourceType: 'backup',
      resourceId: label,
      details: 'Backup restored by user.',
    );
    return row;
  }

  Future<Map<String, Object?>> fetchPrivacyCompliance() async {
    await ensureInitialized();
    return _compliance!.fetchPrivacyCompliance();
  }

  Future<List<Map<String, Object?>>> fetchDisposalRecommendations() async {
    await ensureInitialized();
    return _compliance!.fetchDisposalRecommendations();
  }

  Future<Map<String, Object?>> approveDisposal(int documentId) async {
    await ensureInitialized();
    await _requireAccess(resource: 'compliance', action: 'manage');
    return _compliance!.approveDisposal(documentId);
  }

  Future<Map<String, Object?>> fetchIsoCompliance() async {
    await ensureInitialized();
    return _compliance!.fetchIsoCompliance();
  }

  Future<List<Map<String, Object?>>> fetchAuditLogs({int limit = 100}) async {
    await ensureInitialized();
    return _compliance!.fetchAuditLogs(limit: limit);
  }

  Future<Map<String, Object?>?> authenticateUser({
    required String username,
    required String password,
  }) async {
    await ensureInitialized();
    return _store.authenticateUser(username: username, password: password);
  }

  Future<List<Map<String, Object?>>> fetchUsers() async {
    await ensureInitialized();
    return _store.fetchUsers();
  }

  Future<Map<String, Object?>> insertUser({
    required String userNo,
    required String fullName,
    String username = '',
    String email = '',
    required String role,
    required String password,
    String status = 'active',
    String position = '',
  }) async {
    await ensureInitialized();
    await _requireAccess(resource: 'users', action: 'manage');
    final row = await _store.insertUser(
      userNo: userNo,
      fullName: fullName,
      username: username,
      email: email,
      role: role,
      password: password,
      status: status,
      position: position,
    );
    await _audit(
      action: 'user_created',
      resourceType: 'user',
      resourceId: userNo,
      details: fullName,
    );
    return row;
  }

  Future<Map<String, Object?>> updateUserAccount({
    required String userNo,
    required String fullName,
    String username = '',
    String email = '',
    required String role,
    String password = '',
    String status = 'active',
    String position = '',
  }) async {
    await ensureInitialized();
    await _requireAccess(resource: 'users', action: 'manage');
    final row = await _store.updateUserAccount(
      userNo: userNo,
      fullName: fullName,
      username: username,
      email: email,
      role: role,
      password: password,
      status: status,
      position: position,
    );
    if (row == null) throw StateError('User not found');
    await _audit(
      action: 'user_updated',
      resourceType: 'user',
      resourceId: userNo,
      details: fullName,
    );
    return row;
  }

  Future<Map<String, Object?>> updateUserRole({
    required String userNo,
    required String role,
  }) async {
    await ensureInitialized();
    await _requireAccess(resource: 'users', action: 'manage');
    final row = await _store.updateUserRole(userNo: userNo, role: role);
    if (row == null) throw StateError('User not found');
    await _audit(
      action: 'user_role_updated',
      resourceType: 'user',
      resourceId: userNo,
      details: role,
    );
    return row;
  }

  Future<Map<String, Object?>> updateUserStatus({
    required String userNo,
    required String status,
  }) async {
    await ensureInitialized();
    await _requireAccess(resource: 'users', action: 'manage');
    final row = await _store.updateUserStatus(userNo: userNo, status: status);
    if (row == null) throw StateError('User not found');
    await _audit(
      action: 'user_status_updated',
      resourceType: 'user',
      resourceId: userNo,
      details: status,
    );
    return row;
  }

  Future<bool> deleteUser(String userNo) async {
    await ensureInitialized();
    await _requireAccess(resource: 'users', action: 'manage');
    final ok = await _store.deleteUser(userNo);
    if (ok) {
      await _audit(
        action: 'user_deleted',
        resourceType: 'user',
        resourceId: userNo,
      );
    }
    return ok;
  }

  Future<Map<String, Object?>> updateDocumentMetadata({
    required int id,
    required String title,
    required String documentType,
    required String schoolYear,
    required String program,
    required String studentNo,
    required String storagePath,
    required String college,
    required String tags,
  }) async {
    await ensureInitialized();
    final row = await _store.updateDocumentMetadata(
      id: id,
      title: title,
      documentType: documentType,
      schoolYear: schoolYear,
      program: program,
      studentNo: studentNo,
      storagePath: storagePath,
      college: college,
      tags: tags,
    );
    if (row == null) throw StateError('Document not found');
    await _audit(
      action: 'document_updated',
      resourceType: 'document',
      resourceId: '$id',
      details: title,
    );
    return row;
  }

  Future<List<Map<String, Object?>>> fetchDisposableStudentRecords() async {
    await ensureInitialized();
    return _store.fetchDisposableStudentRecords();
  }

  Future<Map<String, Object?>> approveStudentDisposal(String studentNo) async {
    await ensureInitialized();
    await _requireAccess(resource: 'disposal', action: 'manage');
    final row = await _compliance!.approveStudentDisposal(
      studentNo,
      actor: userName,
    );
    return row;
  }

  Future<Map<String, Object?>> markStudentDisposed(String studentNo) async {
    await ensureInitialized();
    await _requireAccess(resource: 'disposal', action: 'manage');
    final row = await _compliance!.markStudentDisposed(
      studentNo,
      actor: userName,
    );
    return row;
  }

  Future<Map<String, Object?>> fetchDisposableStudentReport() async {
    await ensureInitialized();
    final rows = await _store.fetchDisposableStudentRecords();
    var pending = 0;
    var approved = 0;
    var disposed = 0;
    for (final row in rows) {
      switch ((row['disposal_status'] ?? 'pending').toString().toLowerCase()) {
        case 'approved':
          approved += 1;
          break;
        case 'disposed':
          disposed += 1;
          break;
        default:
          pending += 1;
      }
    }
    return {
      'total': rows.length,
      'pending': pending,
      'approved': approved,
      'disposed': disposed,
    };
  }

  Future<Map<String, Object?>> restoreBackupFromFile(File source) async {
    await ensureInitialized();
    await _requireAccess(resource: 'backup', action: 'restore');
    final row = await _compliance!.restoreBackupFile(
      source,
      backupDirectory: _backupLocation,
    );
    await _audit(
      action: 'backup_file_restored',
      resourceType: 'backup',
      resourceId: '${row['label'] ?? source.path}',
      details: 'Backup file restored by user.',
    );
    return row;
  }

  Future<void> configureBackupLocation(String path) async {
    await ensureInitialized();
    if (path.trim().isEmpty) return;
    final location = p.normalize(p.absolute(path.trim()));
    await Directory(location).create(recursive: true);
    final root = await _dataRoot();
    await File(p.join(root.path, 'backup_location.txt'))
        .writeAsString(location, flush: true);
    _backupLocation = location;
  }

  Future<String> backupLocation() async {
    await ensureInitialized();
    return _backupLocation;
  }

  Future<void> _requireAccess({
    required String resource,
    required String action,
  }) async {
    final rules = await _store.fetchAccessRules();
    final allowed = _compliance!.isAccessAllowed(
      role: userRole,
      resource: resource,
      action: action,
      rules: rules,
    );
    if (!allowed) {
      throw StateError('Access denied by rule-based policy.');
    }
  }

  Future<void> _audit({
    required String action,
    String resourceType = '',
    String resourceId = '',
    String details = '',
  }) async {
    await _compliance!.logAudit(
      actor: userName.trim().isEmpty ? 'system' : userName.trim(),
      action: action,
      resourceType: resourceType,
      resourceId: resourceId,
      details: details,
    );
  }

  Future<Directory> _dataRoot() async {
    final override = Platform.environment['E_ARCHIVE_DATA_DIR'];
    if (override != null && override.trim().isNotEmpty) {
      return Directory(override.trim());
    }

    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.trim().isNotEmpty) {
        return Directory(p.join(appData, 'E-Archive'));
      }
    }

    return Directory(p.join(Directory.current.path, 'e_archive_data'));
  }

  String _safeFileName(String name) {
    final base = p.basename(name);
    return base.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }
}
