import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'config.dart';
import 'compliance_service.dart';
import 'document_classifier.dart';
import 'mysql_store.dart';

bool _isUniqueConstraintError(Object e) {
  final text = e.toString().toLowerCase();
  return text.contains('duplicate entry') || text.contains('1062');
}

bool _isDeleteRestrictedError(Object e) {
  final text = e.toString().toLowerCase();
  return text.contains('cannot move this') ||
      text.contains('cannot permanently remove this') ||
      text.contains('cannot delete this');
}

String _errorMessage(Object e) => e.toString().replaceFirst('Bad state: ', '');

Handler createApiHandler(MySqlStore store, Directory uploadsDir) {
  final router = Router();
  final compliance = ComplianceService(store);

  String userRole(Request request) {
    return (request.headers['x-user-role'] ??
            request.headers['X-User-Role'] ??
            '')
        .toLowerCase();
  }

  String userActor(Request request) {
    return request.headers['x-user-name'] ??
        request.headers['X-User-Name'] ??
        'system';
  }

  Future<bool> checkAccess(
    Request request, {
    required String resource,
    required String action,
  }) async {
    final rules = await store.fetchAccessRules();
    return compliance.isAccessAllowed(
      role: userRole(request),
      resource: resource,
      action: action,
      rules: rules,
    );
  }

  Future<void> audit(
    Request request, {
    required String action,
    String resourceType = '',
    String resourceId = '',
    String details = '',
  }) async {
    await compliance.logAudit(
      actor: userActor(request),
      action: action,
      resourceType: resourceType,
      resourceId: resourceId,
      details: details,
    );
  }

  String publicBaseUrl(Request request) {
    final host = request.requestedUri.host;
    final port = ServerConfig.apiPort;
    return 'http://$host:$port';
  }

  Response jsonResponse(Object body, {int statusCode = 200}) {
    return Response(
      statusCode,
      body: jsonEncode(body),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  Response errorResponse(String message, {int statusCode = 500}) {
    return jsonResponse({'error': message}, statusCode: statusCode);
  }

  router.get('/api/health', (Request request) {
    return jsonResponse({
      'status': 'ok',
      'database': 'mysql',
      'database_name': ServerConfig.mysqlDatabase,
    });
  });

  router.post('/api/auth/login', (Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final username = '${data['username'] ?? ''}'.trim();
      final password = '${data['password'] ?? ''}';
      final account = await store.authenticateUser(
        username: username,
        password: password,
      );
      return jsonResponse(
        {
          'authenticated': account != null,
          if (account != null) 'role': account['role'],
        },
        statusCode: account != null ? 200 : 401,
      );
    } on FormatException {
      return errorResponse('Invalid JSON request body.', statusCode: 400);
    } catch (_) {
      return errorResponse('Login request could not be processed.');
    }
  });

  router.get('/api/users', (Request request) async {
    try {
      if (!await checkAccess(request, resource: 'users', action: 'manage')) {
        return errorResponse('Access denied by rule-based policy.',
            statusCode: 403);
      }
      return jsonResponse(await store.fetchUsers());
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.post('/api/users', (Request request) async {
    try {
      if (!await checkAccess(request, resource: 'users', action: 'manage')) {
        return errorResponse('Access denied by rule-based policy.',
            statusCode: 403);
      }
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final row = await store.insertUser(
        userNo: '${data['user_no'] ?? ''}'.trim(),
        username: '${data['username'] ?? ''}'.trim(),
        fullName: '${data['full_name'] ?? ''}'.trim(),
        email: '${data['email'] ?? ''}'.trim(),
        role: '${data['role'] ?? 'staff'}'.trim(),
        password: '${data['password'] ?? ''}',
        status: '${data['status'] ?? 'active'}'.trim(),
        position: '${data['position'] ?? ''}'.trim(),
      );
      await audit(
        request,
        action: 'user_created',
        resourceType: 'user',
        resourceId: '${row['user_no']}',
        details: row['email']?.toString() ?? '',
      );
      return jsonResponse(row, statusCode: 201);
    } catch (e) {
      if (_isUniqueConstraintError(e) ||
          e.toString().toLowerCase().contains(
                'student number already exists',
              )) {
        return errorResponse('User number or email already exists.',
            statusCode: 409);
      }
      return errorResponse('$e');
    }
  });

  router.put('/api/users/<userNo>/role',
      (Request request, String userNo) async {
    try {
      if (!await checkAccess(request, resource: 'users', action: 'manage')) {
        return errorResponse('Access denied by rule-based policy.',
            statusCode: 403);
      }
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final role = '${data['role'] ?? ''}'.trim();
      if (role.isEmpty) {
        return errorResponse('role is required', statusCode: 400);
      }
      final row = await store.updateUserRole(userNo: userNo, role: role);
      if (row == null) {
        return errorResponse('User not found', statusCode: 404);
      }
      await audit(
        request,
        action: 'user_role_updated',
        resourceType: 'user',
        resourceId: userNo,
        details: role,
      );
      return jsonResponse(row);
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.delete('/api/users/<userNo>', (Request request, String userNo) async {
    try {
      if (!await checkAccess(request, resource: 'users', action: 'manage')) {
        return errorResponse('Access denied by rule-based policy.',
            statusCode: 403);
      }
      final ok = await store.deleteUser(userNo);
      if (!ok) {
        return errorResponse('User not found', statusCode: 404);
      }
      await audit(
        request,
        action: 'user_deleted',
        resourceType: 'user',
        resourceId: userNo,
      );
      return jsonResponse({'deleted': true});
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.get('/api/students', (Request request) async {
    try {
      final courseIdParam = request.url.queryParameters['course_id'];
      final courseName = request.url.queryParameters['course']?.trim();
      final courseId =
          courseIdParam != null ? int.tryParse(courseIdParam) : null;
      final rows = await store.fetchStudents(
        courseId: courseId,
        courseName: courseName,
      );
      return jsonResponse(rows);
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.post('/api/students', (Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final row = await store.insertStudent(
        studentNo: '${data['student_no'] ?? ''}'.trim(),
        fullName: '${data['full_name'] ?? ''}'.trim(),
        course: '${data['course'] ?? ''}'.trim(),
        year: int.tryParse('${data['year'] ?? 1}') ?? 1,
        status: 'graduated',
        email: '${data['email'] ?? ''}'.trim(),
        schoolYear: '${data['school_year'] ?? ''}'.trim(),
        sex: '${data['sex'] ?? ''}'.trim(),
        birthDate: '${data['birth_date'] ?? data['birthDate'] ?? ''}'.trim(),
        phoneNumber:
            '${data['phone_number'] ?? data['phoneNumber'] ?? ''}'.trim(),
        notes: '${data['notes'] ?? ''}'.trim(),
        graduationDate: '${data['graduation_date'] ?? ''}'.trim(),
        lastEnrollmentDate: '${data['last_enrollment_date'] ?? ''}'.trim(),
        retentionBasis:
            '${data['retention_basis'] ?? 'graduation_date'}'.trim(),
      );
      await audit(
        request,
        action: 'student_created',
        resourceType: 'student',
        resourceId: '${row['id']}',
        details: row['full_name']?.toString() ?? '',
      );
      return jsonResponse(row, statusCode: 201);
    } catch (e) {
      if (_isUniqueConstraintError(e)) {
        return errorResponse('Student number already exists.', statusCode: 409);
      }
      return errorResponse('$e');
    }
  });

  router.delete('/api/students/<id>', (Request request, String id) async {
    try {
      final studentId = int.tryParse(id);
      if (studentId == null) {
        return errorResponse('Invalid student id', statusCode: 400);
      }
      if (!await checkAccess(request, resource: 'students', action: 'delete')) {
        return errorResponse('Access denied by rule-based policy.',
            statusCode: 403);
      }
      final ok = await store.deleteStudent(studentId);
      if (!ok) {
        return errorResponse('Student not found', statusCode: 404);
      }
      await audit(
        request,
        action: 'student_deleted',
        resourceType: 'student',
        resourceId: id,
      );
      return jsonResponse({'deleted': true});
    } catch (e) {
      if (_isDeleteRestrictedError(e)) {
        return errorResponse(_errorMessage(e), statusCode: 409);
      }
      return errorResponse('$e');
    }
  });

  router.get('/api/trash/students', (Request request) async {
    try {
      return jsonResponse(await store.fetchDeletedStudents());
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.post('/api/trash/students/<id>/restore',
      (Request request, String id) async {
    final studentId = int.tryParse(id);
    if (studentId == null) {
      return errorResponse('Invalid student id', statusCode: 400);
    }
    if (!await checkAccess(request, resource: 'students', action: 'delete')) {
      return errorResponse('Access denied by rule-based policy.',
          statusCode: 403);
    }
    final ok = await store.restoreStudent(studentId);
    return ok
        ? jsonResponse({'restored': true})
        : errorResponse('Student not found in Trash', statusCode: 404);
  });

  router.delete('/api/trash/students/<id>', (Request request, String id) async {
    try {
      final studentId = int.tryParse(id);
      if (studentId == null) {
        return errorResponse('Invalid student id', statusCode: 400);
      }
      if (!await checkAccess(request, resource: 'students', action: 'delete')) {
        return errorResponse('Access denied by rule-based policy.',
            statusCode: 403);
      }
      final ok = await store.purgeStudent(studentId);
      return ok
          ? jsonResponse({'deleted': true})
          : errorResponse('Student not found in Trash', statusCode: 404);
    } catch (e) {
      if (_isDeleteRestrictedError(e)) {
        return errorResponse(_errorMessage(e), statusCode: 409);
      }
      return errorResponse('$e');
    }
  });

  router.get('/api/courses', (Request request) async {
    try {
      final collegeIdParam = request.url.queryParameters['college_id'];
      final collegeId =
          collegeIdParam != null ? int.tryParse(collegeIdParam) : null;
      final rows = await store.fetchCourses(collegeId: collegeId);
      return jsonResponse(rows);
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.post('/api/courses', (Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final name = '${data['name'] ?? ''}'.trim();
      if (name.isEmpty) {
        return errorResponse('Name is required.', statusCode: 400);
      }
      final collegeIdRaw = data['college_id'];
      final collegeId =
          collegeIdRaw == null ? null : int.tryParse('$collegeIdRaw');
      if (collegeId == null) {
        return errorResponse(
          'college_id is required. Add programs from a college.',
          statusCode: 400,
        );
      }
      final row = await store.insertCourse(
        name: name,
        collegeId: collegeId,
      );
      return jsonResponse(row, statusCode: 201);
    } catch (e) {
      if (_isUniqueConstraintError(e)) {
        return errorResponse('Program name already exists.', statusCode: 409);
      }
      return errorResponse('$e');
    }
  });

  router.put('/api/courses/<id>', (Request request, String id) async {
    try {
      final courseId = int.tryParse(id);
      if (courseId == null) {
        return errorResponse('Invalid program id', statusCode: 400);
      }
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final name = '${data['name'] ?? ''}'.trim();
      if (name.isEmpty) {
        return errorResponse('Name is required.', statusCode: 400);
      }
      final collegeIdRaw = data['college_id'];
      final collegeId =
          collegeIdRaw == null ? null : int.tryParse('$collegeIdRaw');
      final row = await store.updateCourse(
        id: courseId,
        name: name,
        collegeId: collegeId,
      );
      if (row == null) {
        return errorResponse('Program not found', statusCode: 404);
      }
      return jsonResponse(row);
    } catch (e) {
      if (_isUniqueConstraintError(e)) {
        return errorResponse('Program name already exists.', statusCode: 409);
      }
      return errorResponse('$e');
    }
  });

  router.delete('/api/courses/<id>', (Request request, String id) async {
    try {
      final courseId = int.tryParse(id);
      if (courseId == null) {
        return errorResponse('Invalid program id', statusCode: 400);
      }
      if (!await checkAccess(request, resource: 'courses', action: 'delete')) {
        return errorResponse('Access denied by rule-based policy.',
            statusCode: 403);
      }
      final ok = await store.deleteCourse(courseId);
      if (!ok) {
        return errorResponse('Program not found', statusCode: 404);
      }
      return jsonResponse({'deleted': true});
    } catch (e) {
      if (_isDeleteRestrictedError(e)) {
        return errorResponse(_errorMessage(e), statusCode: 409);
      }
      return errorResponse('$e');
    }
  });

  router.get('/api/colleges', (Request request) async {
    try {
      final rows = await store.fetchColleges();
      return jsonResponse(rows);
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.post('/api/colleges', (Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final name = '${data['name'] ?? ''}'.trim();
      if (name.isEmpty) {
        return errorResponse('Name is required.', statusCode: 400);
      }
      final row = await store.insertCollege(name: name);
      return jsonResponse(row, statusCode: 201);
    } catch (e) {
      if (_isUniqueConstraintError(e)) {
        return errorResponse('College name already exists.', statusCode: 409);
      }
      return errorResponse('$e');
    }
  });

  router.put('/api/colleges/<id>', (Request request, String id) async {
    try {
      final collegeId = int.tryParse(id);
      if (collegeId == null) {
        return errorResponse('Invalid college id', statusCode: 400);
      }
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final name = '${data['name'] ?? ''}'.trim();
      if (name.isEmpty) {
        return errorResponse('Name is required.', statusCode: 400);
      }
      final row = await store.updateCollege(
        id: collegeId,
        name: name,
      );
      if (row == null) {
        return errorResponse('College not found', statusCode: 404);
      }
      return jsonResponse(row);
    } catch (e) {
      if (_isUniqueConstraintError(e)) {
        return errorResponse('College name already exists.', statusCode: 409);
      }
      return errorResponse('$e');
    }
  });

  router.delete('/api/colleges/<id>', (Request request, String id) async {
    try {
      final collegeId = int.tryParse(id);
      if (collegeId == null) {
        return errorResponse('Invalid college id', statusCode: 400);
      }
      if (!await checkAccess(request, resource: 'colleges', action: 'delete')) {
        return errorResponse('Access denied by rule-based policy.',
            statusCode: 403);
      }
      final ok = await store.deleteCollege(collegeId);
      if (!ok) {
        return errorResponse('College not found', statusCode: 404);
      }
      return jsonResponse({'deleted': true});
    } catch (e) {
      if (_isDeleteRestrictedError(e)) {
        return errorResponse(_errorMessage(e), statusCode: 409);
      }
      return errorResponse('$e');
    }
  });

  router.get('/api/trash/colleges', (Request request) async {
    try {
      return jsonResponse(await store.fetchDeletedColleges());
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.post('/api/trash/colleges/<id>/restore',
      (Request request, String id) async {
    final collegeId = int.tryParse(id);
    if (collegeId == null) {
      return errorResponse('Invalid college id', statusCode: 400);
    }
    if (!await checkAccess(request, resource: 'colleges', action: 'delete')) {
      return errorResponse('Access denied by rule-based policy.',
          statusCode: 403);
    }
    final ok = await store.restoreCollege(collegeId);
    return ok
        ? jsonResponse({'restored': true})
        : errorResponse('College not found in Trash', statusCode: 404);
  });

  router.delete('/api/trash/colleges/<id>', (Request request, String id) async {
    try {
      final collegeId = int.tryParse(id);
      if (collegeId == null) {
        return errorResponse('Invalid college id', statusCode: 400);
      }
      if (!await checkAccess(request, resource: 'colleges', action: 'delete')) {
        return errorResponse('Access denied by rule-based policy.',
            statusCode: 403);
      }
      final ok = await store.purgeCollege(collegeId);
      return ok
          ? jsonResponse({'deleted': true})
          : errorResponse('College not found in Trash', statusCode: 404);
    } catch (e) {
      if (_isDeleteRestrictedError(e)) {
        return errorResponse(_errorMessage(e), statusCode: 409);
      }
      return errorResponse('$e');
    }
  });

  router.get('/api/documents', (Request request) async {
    try {
      final query = request.requestedUri.queryParameters;
      final limit = int.tryParse(query['limit'] ?? '') ?? 100;
      final beforeId = int.tryParse(query['before_id'] ?? '');
      final includeTotal = query['include_total'] != 'false';
      final page = await store.fetchDocumentPage(
        limit: limit,
        beforeId: beforeId,
        includeTotal: includeTotal,
        search: query['search'] ?? '',
        schoolYear: query['school_year'] ?? '',
        college: query['college'] ?? '',
        program: query['program'] ?? '',
        documentType: query['document_type'] ?? '',
      );
      final rows = (page['items'] as List).cast<Map<String, Object?>>();
      final base = publicBaseUrl(request);
      final withUrls = rows.map((row) {
        final path = (row['image_path'] ?? '').toString();
        if (path.startsWith('/uploads/')) {
          return {...row, 'image_path': '$base$path'};
        }
        return row;
      }).toList();
      return jsonResponse({...page, 'items': withUrls});
    } catch (e) {
      return errorResponse('$e');
    }
  });

  // Constant-memory upload path. Metadata is supplied as X-Earchive-* headers;
  // the request body contains the raw file bytes.
  router.post('/api/documents/stream', (Request request) async {
    File? tempFile;
    try {
      if (!await checkAccess(request,
          resource: 'documents', action: 'upload')) {
        return errorResponse('Access denied by rule-based policy.',
            statusCode: 403);
      }
      String metadata(String name, [String fallback = '']) =>
          request.headers['x-earchive-$name']?.trim() ?? fallback;
      final originalName = metadata('file-name', 'upload.bin');
      final safeName = _safeFileName(originalName);
      final studentName = metadata('student');
      final studentNo = metadata('student-no');
      final courseName = metadata('course');
      var program = metadata('program');
      if (program.isEmpty && courseName.isNotEmpty) {
        program = (await store.programCodeForCourse(courseName)) ?? courseName;
      }
      var college = metadata('college');
      if (college.isEmpty && courseName.isNotEmpty) {
        college = (await store.collegeNameForCourse(courseName)) ?? '';
      }
      final schoolYear = metadata('school-year');
      final documentType = metadata('document-type', 'Other');
      final studentCategory = metadata('student-category', 'Graduated');
      final baseRelativePath = DocumentClassifier.buildRelativePath(
        schoolYear: schoolYear.isEmpty ? 'Unknown' : schoolYear,
        college: college.isEmpty ? 'General' : college,
        program: program.isEmpty ? 'General' : program,
        studentCategory: studentCategory,
        studentNo: studentNo,
        studentName: studentName,
        documentType: documentType,
        fileName: safeName,
        isComplete: metadata('is-complete', 'true') == 'true',
      );
      final relativePath =
          await _uniqueUploadRelativePath(uploadsDir, baseRelativePath);
      final destination = _uploadDestination(uploadsDir, relativePath);
      await destination.parent.create(recursive: true);
      tempFile = File('${destination.path}.uploading');
      await request.read().pipe(tempFile.openWrite());
      final sizeBytes = await tempFile.length();
      final contentHash =
          (await sha256.bind(tempFile.openRead()).first).toString();
      final duplicate = await compliance.findDuplicateByHash(contentHash);
      await tempFile.rename(destination.path);
      tempFile = null;

      final imagePath = DocumentClassifier.toUrlPath(relativePath);
      final row = await store.insertDocument(
        title: metadata('title', safeName),
        student: studentName,
        imagePath: imagePath,
        mimeType: request.headers['content-type'] ?? 'application/octet-stream',
        sizeBytes: sizeBytes,
        documentType: documentType,
        schoolYear: schoolYear,
        program: program,
        studentNo: studentNo,
        storagePath: relativePath.replaceAll(Platform.pathSeparator, '/'),
        college: college.isEmpty ? 'General' : college,
        studentCategory: DocumentClassifier.normalizeCategory(studentCategory),
        contentHash: contentHash,
        tags: metadata('tags'),
        uploader: metadata('uploader'),
      );
      await audit(
        request,
        action: 'document_uploaded',
        resourceType: 'document',
        resourceId: '${row['id']}',
        details: row['title']?.toString() ?? '',
      );
      return jsonResponse({
        ...row,
        'image_path': '${publicBaseUrl(request)}$imagePath',
        'duplicate_detected': duplicate != null,
        'duplicate_of': duplicate?['id'],
      }, statusCode: 201);
    } catch (e) {
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
      return errorResponse('$e');
    }
  });

  router.post('/api/documents', (Request request) async {
    try {
      if (!await checkAccess(request,
          resource: 'documents', action: 'upload')) {
        return errorResponse('Access denied by rule-based policy.',
            statusCode: 403);
      }
      final contentLength =
          int.tryParse(request.headers['content-length'] ?? '');
      if (contentLength != null && contentLength > 10 * 1024 * 1024) {
        return errorResponse(
          'Large uploads must use POST /api/documents/stream with a raw body.',
          statusCode: 413,
        );
      }
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final base64 = (data['image_base64'] ?? '').toString();
      if (base64.isEmpty) {
        return errorResponse('image_base64 is required', statusCode: 400);
      }

      final bytes = base64Decode(base64);
      final contentHash = ComplianceService.hashBytes(bytes);
      final duplicate = await compliance.findDuplicateByHash(contentHash);

      final originalName =
          (data['file_name'] ?? 'upload.bin').toString().trim();
      final safeName = _safeFileName(originalName);

      final studentName = '${data['student'] ?? ''}'.trim();
      final studentNo = '${data['student_no'] ?? ''}'.trim();
      final courseName = '${data['course'] ?? ''}'.trim();
      var program = '${data['program'] ?? ''}'.trim();
      if (program.isEmpty && courseName.isNotEmpty) {
        program = (await store.programCodeForCourse(courseName)) ?? courseName;
      }
      final schoolYear = '${data['school_year'] ?? ''}'.trim();
      final documentType = '${data['document_type'] ?? ''}'.trim();
      final isComplete = data['is_complete'] == true ||
          data['is_complete']?.toString() == 'true';

      var college = '${data['college'] ?? ''}'.trim();
      if (college.isEmpty && courseName.isNotEmpty) {
        college = (await store.collegeNameForCourse(courseName)) ?? '';
      }

      var studentCategory = '${data['student_category'] ?? ''}'.trim();
      if (studentCategory.isEmpty) {
        studentCategory = '${data['status'] ?? ''}'.trim();
      }
      if (studentCategory.isEmpty) {
        studentCategory = 'Graduated';
      }

      final baseRelativePath = DocumentClassifier.buildRelativePath(
        schoolYear: schoolYear.isEmpty ? 'Unknown' : schoolYear,
        college: college.isEmpty ? 'General' : college,
        program: program.isEmpty ? 'General' : program,
        studentCategory: studentCategory,
        studentNo: studentNo,
        studentName: studentName,
        documentType: documentType.isEmpty ? 'Other' : documentType,
        fileName: safeName,
        isComplete: isComplete,
      );
      final relativePath =
          await _uniqueUploadRelativePath(uploadsDir, baseRelativePath);

      final file = _uploadDestination(uploadsDir, relativePath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);

      final imagePath = DocumentClassifier.toUrlPath(relativePath);
      final normalizedCategory =
          DocumentClassifier.normalizeCategory(studentCategory);

      final row = await store.insertDocument(
        title: '${data['title'] ?? 'Untitled'}'.trim(),
        student: studentName,
        imagePath: imagePath,
        mimeType: '${data['mime_type'] ?? 'image'}'.trim(),
        sizeBytes: bytes.length,
        documentType: documentType,
        schoolYear: schoolYear,
        program: program,
        studentNo: studentNo,
        storagePath: relativePath.replaceAll(Platform.pathSeparator, '/'),
        college: college.isEmpty ? 'General' : college,
        studentCategory: normalizedCategory,
        contentHash: contentHash,
      );

      await audit(
        request,
        action: 'document_uploaded',
        resourceType: 'document',
        resourceId: '${row['id']}',
        details: row['title']?.toString() ?? '',
      );

      final base = publicBaseUrl(request);
      return jsonResponse({
        ...row,
        'image_path': '$base$imagePath',
        'duplicate_detected': duplicate != null,
        'duplicate_of': duplicate?['id'],
      }, statusCode: 201);
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.delete('/api/documents/<id>', (Request request, String id) async {
    try {
      final docId = int.tryParse(id);
      if (docId == null) {
        return errorResponse('Invalid document id', statusCode: 400);
      }
      if (!await checkAccess(request,
          resource: 'documents', action: 'delete')) {
        return errorResponse('Access denied by rule-based policy.',
            statusCode: 403);
      }
      final ok = await store.deleteDocument(docId);
      if (!ok) {
        return errorResponse('Document not found', statusCode: 404);
      }
      await audit(
        request,
        action: 'document_deleted',
        resourceType: 'document',
        resourceId: id,
      );
      return jsonResponse({'deleted': true});
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.get('/api/compliance/overview', (Request request) async {
    try {
      return jsonResponse(await compliance.fetchOverview());
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.get('/api/compliance/retention', (Request request) async {
    try {
      return jsonResponse(await compliance.fetchRetentionMonitoring());
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.get('/api/compliance/retention/policies', (Request request) async {
    try {
      return jsonResponse(await compliance.fetchRetentionPolicies());
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.get('/api/compliance/access-rules', (Request request) async {
    try {
      return jsonResponse(await compliance.fetchAccessRules());
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.get('/api/compliance/duplicates', (Request request) async {
    try {
      return jsonResponse(await compliance.fetchDuplicates());
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.get('/api/compliance/analytics', (Request request) async {
    try {
      return jsonResponse(await compliance.fetchDecisionAnalytics());
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.post('/api/compliance/backup', (Request request) async {
    try {
      if (!await checkAccess(request,
          resource: 'compliance', action: 'manage')) {
        return errorResponse('Access denied by rule-based policy.',
            statusCode: 403);
      }
      final result = await compliance.createBackup();
      return jsonResponse(result, statusCode: 201);
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.get('/api/compliance/backups', (Request request) async {
    try {
      if (!await checkAccess(request,
          resource: 'compliance', action: 'manage')) {
        return errorResponse('Access denied by rule-based policy.',
            statusCode: 403);
      }
      return jsonResponse(await compliance.fetchBackups());
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.get('/api/compliance/backups/<label>/database', (
    Request request,
    String label,
  ) async {
    try {
      if (!await checkAccess(request,
          resource: 'compliance', action: 'manage')) {
        return errorResponse('Access denied by rule-based policy.',
            statusCode: 403);
      }
      final file = await compliance.backupDatabaseFile(label);
      return Response.ok(
        file.openRead(),
        headers: {
          'content-type': 'application/sql',
          'content-disposition': 'attachment; filename="${label}_database.sql"',
        },
      );
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.post('/api/compliance/restore', (Request request) async {
    try {
      if (!await checkAccess(request, resource: 'backup', action: 'restore')) {
        return errorResponse('Access denied by rule-based policy.',
            statusCode: 403);
      }
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final label = '${data['label'] ?? ''}'.trim();
      if (label.isEmpty) {
        return errorResponse('label is required', statusCode: 400);
      }
      final result = await compliance.restoreBackup(label);
      return jsonResponse(result);
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.get('/api/compliance/privacy', (Request request) async {
    try {
      return jsonResponse(await compliance.fetchPrivacyCompliance());
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.get('/api/compliance/disposal', (Request request) async {
    try {
      return jsonResponse(await compliance.fetchDisposalRecommendations());
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.get('/api/disposable-records', (Request request) async {
    try {
      if (!await checkAccess(request, resource: 'disposal', action: 'manage')) {
        return errorResponse('Access denied by rule-based policy.',
            statusCode: 403);
      }
      return jsonResponse(await compliance.fetchDisposableStudentRecords());
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.get('/api/disposable-records/report', (Request request) async {
    try {
      if (!await checkAccess(request, resource: 'disposal', action: 'manage')) {
        return errorResponse('Access denied by rule-based policy.',
            statusCode: 403);
      }
      return jsonResponse(await compliance.fetchDisposableStudentReport());
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.post('/api/disposable-records/<studentNo>/approve', (
    Request request,
    String studentNo,
  ) async {
    try {
      if (!await checkAccess(request, resource: 'disposal', action: 'manage')) {
        return errorResponse('Access denied by rule-based policy.',
            statusCode: 403);
      }
      final row = await compliance.approveStudentDisposal(
        studentNo,
        actor: userActor(request),
      );
      return jsonResponse(row);
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.post('/api/disposable-records/<studentNo>/dispose', (
    Request request,
    String studentNo,
  ) async {
    try {
      if (!await checkAccess(request, resource: 'disposal', action: 'manage')) {
        return errorResponse('Access denied by rule-based policy.',
            statusCode: 403);
      }
      final row = await compliance.markStudentDisposed(
        studentNo,
        actor: userActor(request),
      );
      return jsonResponse(row);
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.post('/api/compliance/disposal/<id>/approve', (
    Request request,
    String id,
  ) async {
    try {
      if (!await checkAccess(request,
          resource: 'compliance', action: 'manage')) {
        return errorResponse('Access denied by rule-based policy.',
            statusCode: 403);
      }
      final docId = int.tryParse(id);
      if (docId == null) {
        return errorResponse('Invalid document id', statusCode: 400);
      }
      final row = await compliance.approveDisposal(docId);
      return jsonResponse(row);
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.get('/api/compliance/iso', (Request request) async {
    try {
      return jsonResponse(await compliance.fetchIsoCompliance());
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.get('/api/audit-logs', (Request request) async {
    try {
      if (!await checkAccess(request,
          resource: 'compliance', action: 'manage')) {
        return errorResponse('Access denied by rule-based policy.',
            statusCode: 403);
      }
      final limitParam = request.url.queryParameters['limit'];
      final limit = int.tryParse(limitParam ?? '') ?? 100;
      return jsonResponse(await compliance.fetchAuditLogs(limit: limit));
    } catch (e) {
      return errorResponse('$e');
    }
  });

  router.post('/api/audit-logs', (Request request) async {
    try {
      if (!await checkAccess(request,
          resource: 'compliance', action: 'manage')) {
        return errorResponse('Access denied by rule-based policy.',
            statusCode: 403);
      }
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final row = await compliance.logAudit(
        actor: '${data['actor'] ?? userActor(request)}'.trim(),
        action: '${data['action'] ?? ''}'.trim(),
        resourceType: '${data['resource_type'] ?? ''}'.trim(),
        resourceId: '${data['resource_id'] ?? ''}'.trim(),
        details: '${data['details'] ?? ''}'.trim(),
      );
      return jsonResponse(row, statusCode: 201);
    } catch (e) {
      return errorResponse('$e');
    }
  });

  return (Request request) {
    final path = request.requestedUri.path;
    if (path == '/api/health' || path == '/api/auth/login') {
      return router.call(request);
    }

    final role = userRole(request);
    if (role != 'admin' && role != 'staff') {
      return errorResponse('Authentication is required.', statusCode: 401);
    }
    return router.call(request);
  };
}

/// Serves nested files under `/uploads/...` (rule-based folder layout).
Handler createUploadsHandler(Directory uploadsDir) {
  return (Request request) {
    final urlPath = request.requestedUri.path;
    if (!urlPath.startsWith('/uploads/')) {
      return Response.notFound('Not found');
    }

    final relative = urlPath
        .replaceFirst('/uploads/', '')
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(_safeFileName)
        .join(Platform.pathSeparator);

    if (relative.isEmpty || relative.contains('..')) {
      return Response.notFound('File not found');
    }

    final file = File(
      p.join(uploadsDir.absolute.path, relative),
    );
    final uploadsRoot = p.normalize(uploadsDir.absolute.path);
    final filePath = p.normalize(file.absolute.path);
    if (!p.isWithin(uploadsRoot, filePath)) {
      return Response.forbidden('Invalid path');
    }
    if (!file.existsSync()) {
      return Response.notFound('File not found');
    }

    final fileLength = file.lengthSync();
    final commonHeaders = {
      'content-type': _guessContentType(file.path),
      'accept-ranges': 'bytes',
    };
    final range = request.headers['range'];
    final match = range == null
        ? null
        : RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(range.trim());
    if (match != null) {
      final start = int.tryParse(match.group(1) ?? '') ?? 0;
      final requestedEnd = int.tryParse(match.group(2) ?? '');
      if (start >= fileLength) {
        return Response(
          416,
          headers: {'content-range': 'bytes */$fileLength'},
        );
      }
      final end = requestedEnd == null
          ? fileLength - 1
          : requestedEnd.clamp(start, fileLength - 1);
      return Response(
        206,
        body: file.openRead(start, end + 1),
        headers: {
          ...commonHeaders,
          'content-length': '${end - start + 1}',
          'content-range': 'bytes $start-$end/$fileLength',
        },
      );
    }
    return Response.ok(file.openRead(), headers: {
      ...commonHeaders,
      'content-length': '$fileLength',
    });
  };
}

String _safeFileName(String name) {
  final base = name.split(Platform.pathSeparator).last;
  return base.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
}

String _guessContentType(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  return 'application/octet-stream';
}

Future<String> _uniqueUploadRelativePath(
  Directory uploadsDir,
  String relativePath,
) async {
  var candidate = relativePath;
  var file = _uploadDestination(uploadsDir, candidate);
  if (!await file.exists()) return candidate;

  final directory = p.dirname(relativePath);
  final extension = p.extension(relativePath);
  final stem = p.basenameWithoutExtension(relativePath);
  var index = 2;
  do {
    candidate = p.join(directory, '$stem-$index$extension');
    file = _uploadDestination(uploadsDir, candidate);
    index++;
  } while (await file.exists());
  return candidate;
}

File _uploadDestination(Directory uploadsDir, String relativePath) {
  final uploadsRoot = p.normalize(uploadsDir.absolute.path);
  final filePath = p.normalize(p.join(uploadsRoot, relativePath));
  if (!p.isWithin(uploadsRoot, filePath)) {
    throw StateError('The generated upload path is invalid.');
  }
  return File(filePath);
}
