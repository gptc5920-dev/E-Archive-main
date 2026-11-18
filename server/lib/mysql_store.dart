import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mysql1/mysql1.dart';
import 'package:path/path.dart' as p;

import 'config.dart';

class _IndexColumn {
  const _IndexColumn(this.name, {this.prefixLength});

  final String name;
  final int? prefixLength;

  String get sql => '`$name`${prefixLength == null ? '' : '($prefixLength)'}';
}

class _IndexDefinition {
  const _IndexDefinition(this.table, this.name, this.columns);

  final String table;
  final String name;
  final List<_IndexColumn> columns;
}

class MySqlStore {
  MySqlDatabase? _db;
  late final Directory uploadsDir;
  bool _documentFullTextSearchAvailable = false;

  Future<void> open(Directory uploadsDirectory) async {
    uploadsDir = uploadsDirectory;
    await uploadsDir.create(recursive: true);

    try {
      _db = await _openDatabase();
    } catch (e) {
      if (await _tryStartLocalXamppMysql(e)) {
        _db = await _openDatabase();
      } else {
        rethrow;
      }
    }
    await _ensureSchema(db);
  }

  Future<MySqlDatabase> _openDatabase() {
    return MySqlDatabase.open(
      host: ServerConfig.mysqlHost,
      port: ServerConfig.mysqlPort,
      user: ServerConfig.mysqlUser,
      password: ServerConfig.mysqlPassword,
      database: ServerConfig.mysqlDatabase,
    );
  }

  Future<bool> _tryStartLocalXamppMysql(Object error) async {
    if (!_looksLikeConnectionFailure(error)) return false;
    if (!Platform.isWindows) return false;
    if (ServerConfig.mysqlPort != 3306) return false;

    final host = ServerConfig.mysqlHost.toLowerCase();
    if (host != '127.0.0.1' && host != 'localhost') return false;

    final mysqld = File(r'C:\xampp\mysql\bin\mysqld.exe');
    final config = File(r'C:\xampp\mysql\bin\my.ini');
    if (!mysqld.existsSync() || !config.existsSync()) return false;

    await Process.start(
      mysqld.path,
      ['--defaults-file=${config.path}', '--standalone'],
      workingDirectory: r'C:\xampp',
      mode: ProcessStartMode.detached,
    );

    return _waitForMysqlPort();
  }

  bool _looksLikeConnectionFailure(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('connection refused') ||
        text.contains('connection failed') ||
        text.contains('failed host lookup') ||
        text.contains('no connection could be made') ||
        text.contains('actively refused');
  }

  Future<bool> _waitForMysqlPort() async {
    for (var attempt = 0; attempt < 20; attempt += 1) {
      try {
        final socket = await Socket.connect(
          ServerConfig.mysqlHost,
          ServerConfig.mysqlPort,
          timeout: const Duration(seconds: 1),
        );
        await socket.close();
        return true;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    return false;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  MySqlDatabase get db {
    final d = _db;
    if (d == null) {
      throw StateError('MySQL database is not open');
    }
    return d;
  }

  Future<void> _ensureSchema(MySqlDatabase d) async {
    await d.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_no TEXT NOT NULL UNIQUE,
        username TEXT NOT NULL DEFAULT '',
        full_name TEXT NOT NULL,
        email TEXT NOT NULL DEFAULT '',
        role TEXT NOT NULL,
        account_type TEXT NOT NULL DEFAULT 'staff',
        status TEXT NOT NULL DEFAULT 'active',
        position TEXT NOT NULL DEFAULT '',
        password_hash TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        last_login_at TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await _dropIndexIfExists(d, 'users', 'email');
    await _addColumnIfNotExists(
      d,
      'users',
      'username',
      "VARCHAR(255) NOT NULL DEFAULT ''",
    );
    await _addColumnIfNotExists(
      d,
      'users',
      'account_type',
      "VARCHAR(64) NOT NULL DEFAULT 'staff'",
    );
    await _addColumnIfNotExists(
      d,
      'users',
      'status',
      "VARCHAR(32) NOT NULL DEFAULT 'active'",
    );
    await _addColumnIfNotExists(
      d,
      'users',
      'position',
      "VARCHAR(255) NOT NULL DEFAULT ''",
    );
    await _addColumnIfNotExists(d, 'users', 'last_login_at', 'DATETIME');
    await d.rawUpdate(
      '''
      UPDATE users
      SET username = CASE
            WHEN username IS NULL OR username = '' THEN
              CASE
                WHEN email IS NOT NULL AND email != '' THEN email
                ELSE user_no
              END
            ELSE username
          END,
          account_type = CASE
            WHEN account_type IS NULL OR account_type = '' THEN role
            ELSE account_type
          END,
          status = CASE
            WHEN status IS NULL OR status = '' THEN
              CASE WHEN is_active = 1 THEN 'active' ELSE 'inactive' END
            ELSE status
          END
      ''',
    );
    await d.rawUpdate(
      '''
      UPDATE users
      SET username = 'admin'
      WHERE user_no = 'ADM-0001' OR LOWER(email) = 'admin@gmail.com'
      ''',
    );
    await d.rawUpdate(
      '''
      UPDATE users
      SET username = 'staff'
      WHERE user_no = 'STF-0001' OR LOWER(email) = 'staff@gmail.com'
      ''',
    );

    await d.execute('''
      CREATE TABLE IF NOT EXISTS students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_no TEXT NOT NULL,
        full_name TEXT NOT NULL,
        course TEXT NOT NULL,
        year INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'graduated',
        email TEXT NOT NULL DEFAULT '',
        school_year TEXT NOT NULL DEFAULT '',
        sex TEXT NOT NULL DEFAULT '',
        birth_date TEXT NOT NULL DEFAULT '',
        phone_number TEXT NOT NULL DEFAULT '',
        notes VARCHAR(4096) NOT NULL DEFAULT '',
        graduation_date TEXT NOT NULL DEFAULT '',
        last_enrollment_date TEXT NOT NULL DEFAULT '',
        retention_basis TEXT NOT NULL DEFAULT 'graduation_date',
        disposal_status TEXT NOT NULL DEFAULT 'pending',
        disposal_approved_at TEXT NOT NULL DEFAULT '',
        disposal_approved_by TEXT NOT NULL DEFAULT '',
        disposed_at TEXT NOT NULL DEFAULT '',
        disposal_notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    await _dropIndexIfExists(d, 'students', 'student_no');

    await _addColumnIfNotExists(
      d,
      'students',
      'school_year',
      "VARCHAR(32) NOT NULL DEFAULT ''",
    );
    await _addColumnIfNotExists(
      d,
      'students',
      'sex',
      "VARCHAR(32) NOT NULL DEFAULT ''",
    );
    await _addColumnIfNotExists(
      d,
      'students',
      'birth_date',
      "VARCHAR(32) NOT NULL DEFAULT ''",
    );
    await _addColumnIfNotExists(
      d,
      'students',
      'phone_number',
      "VARCHAR(64) NOT NULL DEFAULT ''",
    );
    await _addColumnIfNotExists(
      d,
      'students',
      'notes',
      "VARCHAR(4096) NOT NULL DEFAULT ''",
    );
    await _addColumnIfNotExists(
      d,
      'students',
      'graduation_date',
      "VARCHAR(32) NOT NULL DEFAULT ''",
    );
    await _addColumnIfNotExists(
      d,
      'students',
      'last_enrollment_date',
      "VARCHAR(32) NOT NULL DEFAULT ''",
    );
    await _addColumnIfNotExists(
      d,
      'students',
      'retention_basis',
      "VARCHAR(64) NOT NULL DEFAULT 'graduation_date'",
    );
    await _addColumnIfNotExists(
      d,
      'students',
      'disposal_status',
      "VARCHAR(32) NOT NULL DEFAULT 'pending'",
    );
    await _addColumnIfNotExists(
      d,
      'students',
      'disposal_approved_at',
      "VARCHAR(32) NOT NULL DEFAULT ''",
    );
    await _addColumnIfNotExists(
      d,
      'students',
      'disposal_approved_by',
      "VARCHAR(255) NOT NULL DEFAULT ''",
    );
    await _addColumnIfNotExists(
      d,
      'students',
      'disposed_at',
      "VARCHAR(32) NOT NULL DEFAULT ''",
    );
    await _addColumnIfNotExists(
      d,
      'students',
      'disposal_notes',
      "VARCHAR(1024) NOT NULL DEFAULT ''",
    );
    await _addColumnIfNotExists(
      d,
      'students',
      'deleted_at',
      "VARCHAR(32) NOT NULL DEFAULT ''",
    );
    await _addColumnIfNotExists(
      d,
      'students',
      'deleted_by',
      "VARCHAR(255) NOT NULL DEFAULT ''",
    );

    await d.execute('''
      CREATE TABLE IF NOT EXISTS documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        student TEXT NOT NULL DEFAULT '',
        image_path TEXT NOT NULL,
        mime_type TEXT NOT NULL DEFAULT 'image',
        size_bytes INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await d.execute('''
      CREATE TABLE IF NOT EXISTS courses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        college_id INTEGER,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (college_id) REFERENCES colleges(id)
      )
    ''');

    await _addColumnIfNotExists(d, 'courses', 'college_id', 'INTEGER');
    await _addColumnIfNotExists(d, 'courses', 'code', 'TEXT');

    await _addColumnIfNotExists(d, 'documents', 'document_type', 'TEXT');
    await _addColumnIfNotExists(d, 'documents', 'school_year', 'TEXT');
    await _addColumnIfNotExists(d, 'documents', 'program', 'TEXT');
    await _addColumnIfNotExists(d, 'documents', 'student_no', 'TEXT');
    await _addColumnIfNotExists(d, 'documents', 'storage_path', 'TEXT');
    await _addColumnIfNotExists(d, 'documents', 'college', 'TEXT');
    await _addColumnIfNotExists(d, 'documents', 'student_category', 'TEXT');
    await _addColumnIfNotExists(d, 'documents', 'tags', 'TEXT');
    await _addColumnIfNotExists(d, 'documents', 'uploader', 'TEXT');
    await _addColumnIfNotExists(
      d,
      'documents',
      'deleted_at',
      "VARCHAR(32) NOT NULL DEFAULT ''",
    );
    await _addColumnIfNotExists(
      d,
      'documents',
      'deleted_by',
      "VARCHAR(255) NOT NULL DEFAULT ''",
    );

    await d.execute('''
      CREATE TABLE IF NOT EXISTS colleges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await _dropColumnIfExists(d, 'colleges', 'code');
    await _addColumnIfNotExists(
      d,
      'colleges',
      'deleted_at',
      "VARCHAR(32) NOT NULL DEFAULT ''",
    );
    await _addColumnIfNotExists(
      d,
      'colleges',
      'deleted_by',
      "VARCHAR(255) NOT NULL DEFAULT ''",
    );

    await _seedDefaultColleges(d);
    await _seedDefaultCourses(d);

    await _addColumnIfNotExists(d, 'documents', 'content_hash', 'TEXT');
    await _addColumnIfNotExists(
      d,
      'documents',
      'deleted_at',
      "VARCHAR(32) NOT NULL DEFAULT ''",
    );
    await _addColumnIfNotExists(
      d,
      'documents',
      'deleted_by',
      "VARCHAR(255) NOT NULL DEFAULT ''",
    );

    await d.execute('''
      CREATE TABLE IF NOT EXISTS retention_policies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_type TEXT NOT NULL UNIQUE,
        retention_years INTEGER NOT NULL DEFAULT 7,
        legal_basis TEXT NOT NULL DEFAULT '',
        iso_reference TEXT NOT NULL DEFAULT 'ISO 15489-1:2016',
        description TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await d.execute('''
      CREATE TABLE IF NOT EXISTS access_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT NOT NULL,
        resource TEXT NOT NULL,
        action TEXT NOT NULL,
        allowed INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        UNIQUE(role, resource, action)
      )
    ''');

    await d.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        actor TEXT NOT NULL,
        action TEXT NOT NULL,
        resource_type TEXT NOT NULL DEFAULT '',
        resource_id TEXT NOT NULL DEFAULT '',
        details TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await d.execute('''
      CREATE TABLE IF NOT EXISTS backup_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT NOT NULL UNIQUE,
        backup_path TEXT NOT NULL,
        size_bytes INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'completed',
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await d.execute('''
      CREATE TABLE IF NOT EXISTS disposal_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL UNIQUE,
        status TEXT NOT NULL DEFAULT 'pending',
        reason TEXT NOT NULL DEFAULT '',
        recommended_date TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (document_id) REFERENCES documents(id)
      )
    ''');

    await _seedComplianceDefaults(d);
    await _seedDefaultUsers(d);
    await _seedComplianceDemoData(d);
    await _seedDisposableDemoData(d);

    await _dropColumnIfExists(d, 'documents', 'extracted_text');
    await _normalizeSoftDeleteValues(d);
    await _ensurePerformanceIndexes(d);
  }

  Future<void> _normalizeSoftDeleteValues(MySqlDatabase d) async {
    for (final table in const ['documents', 'students', 'colleges']) {
      await d.rawUpdate(
        "UPDATE `$table` SET deleted_at = '' WHERE deleted_at IS NULL",
      );
    }
  }

  Future<void> _ensurePerformanceIndexes(MySqlDatabase d) async {
    const indexes = [
      _IndexDefinition('documents', 'idx_documents_active_created', [
        _IndexColumn('deleted_at'),
        _IndexColumn('created_at'),
        _IndexColumn('id'),
      ]),
      _IndexDefinition('documents', 'idx_documents_active_id', [
        _IndexColumn('deleted_at'),
        _IndexColumn('id'),
      ]),
      _IndexDefinition('documents', 'idx_documents_content_hash', [
        _IndexColumn('deleted_at'),
        _IndexColumn('content_hash', prefixLength: 64),
      ]),
      _IndexDefinition('documents', 'idx_documents_student_no', [
        _IndexColumn('student_no', prefixLength: 64),
        _IndexColumn('deleted_at'),
        _IndexColumn('id'),
      ]),
      _IndexDefinition('documents', 'idx_documents_student', [
        _IndexColumn('student', prefixLength: 191),
        _IndexColumn('deleted_at'),
        _IndexColumn('id'),
      ]),
      _IndexDefinition('documents', 'idx_documents_college', [
        _IndexColumn('college', prefixLength: 191),
        _IndexColumn('deleted_at'),
        _IndexColumn('id'),
      ]),
      _IndexDefinition('documents', 'idx_documents_program', [
        _IndexColumn('program', prefixLength: 191),
        _IndexColumn('deleted_at'),
        _IndexColumn('id'),
      ]),
      _IndexDefinition('documents', 'idx_documents_type', [
        _IndexColumn('document_type', prefixLength: 128),
        _IndexColumn('deleted_at'),
        _IndexColumn('id'),
      ]),
      _IndexDefinition('documents', 'idx_documents_school_year', [
        _IndexColumn('school_year', prefixLength: 32),
        _IndexColumn('deleted_at'),
        _IndexColumn('id'),
      ]),
      _IndexDefinition('students', 'idx_students_active_created', [
        _IndexColumn('deleted_at'),
        _IndexColumn('created_at'),
        _IndexColumn('id'),
      ]),
      _IndexDefinition('students', 'idx_students_student_no', [
        _IndexColumn('student_no', prefixLength: 64),
        _IndexColumn('deleted_at'),
        _IndexColumn('id'),
      ]),
      _IndexDefinition('students', 'idx_students_course_active_created', [
        _IndexColumn('course', prefixLength: 191),
        _IndexColumn('deleted_at'),
        _IndexColumn('created_at'),
        _IndexColumn('id'),
      ]),
      _IndexDefinition('users', 'idx_users_password_active', [
        _IndexColumn('password_hash', prefixLength: 64),
        _IndexColumn('is_active'),
        _IndexColumn('status', prefixLength: 32),
      ]),
      _IndexDefinition('users', 'idx_users_created', [
        _IndexColumn('created_at'),
        _IndexColumn('id'),
      ]),
      _IndexDefinition('colleges', 'idx_colleges_deleted_name', [
        _IndexColumn('deleted_at'),
        _IndexColumn('name'),
      ]),
      _IndexDefinition('courses', 'idx_courses_college_name', [
        _IndexColumn('college_id'),
        _IndexColumn('name'),
      ]),
      _IndexDefinition('audit_logs', 'idx_audit_created', [
        _IndexColumn('created_at'),
        _IndexColumn('id'),
      ]),
      _IndexDefinition('backup_records', 'idx_backups_created', [
        _IndexColumn('created_at'),
        _IndexColumn('id'),
      ]),
      _IndexDefinition('disposal_queue', 'idx_disposal_created', [
        _IndexColumn('created_at'),
        _IndexColumn('id'),
      ]),
    ];
    for (final index in indexes) {
      await _ensureIndex(d, index);
    }
    final fullText = await d.rawQuery('''
      SELECT 1 FROM information_schema.statistics
      WHERE table_schema = DATABASE()
        AND table_name = 'documents'
        AND index_name = 'idx_documents_fulltext'
      LIMIT 1
    ''');
    if (fullText.isNotEmpty) {
      _documentFullTextSearchAvailable = true;
    } else {
      try {
        await d.execute('''
          CREATE FULLTEXT INDEX idx_documents_fulltext ON documents
            (title, student, student_no, document_type, school_year,
             college, program, tags)
        ''');
        _documentFullTextSearchAvailable = true;
      } catch (_) {
        // Older MySQL/MariaDB builds may not support this index configuration.
        // Search remains functional through the LIKE fallback below.
      }
    }
  }

  Future<void> _ensureIndex(
    MySqlDatabase d,
    _IndexDefinition definition,
  ) async {
    final existing = await d.rawQuery(
      '''
      SELECT column_name, sub_part
      FROM information_schema.statistics
      WHERE table_schema = DATABASE()
        AND table_name = ?
        AND index_name = ?
      ORDER BY seq_in_index ASC
      ''',
      [definition.table, definition.name],
    );
    final matches = existing.length == definition.columns.length &&
        List.generate(existing.length, (index) {
          final row = existing[index];
          final expected = definition.columns[index];
          final actualPrefix = row['sub_part'];
          return row['column_name'] == expected.name &&
              (actualPrefix is num ? actualPrefix.toInt() : null) ==
                  expected.prefixLength;
        }).every((matches) => matches);
    if (matches) return;

    if (existing.isNotEmpty) {
      await d.execute(
        'ALTER TABLE `${definition.table}` '
        'DROP INDEX `${definition.name}`',
      );
    }
    final columns = definition.columns.map((column) => column.sql).join(', ');
    await d.execute(
      'CREATE INDEX `${definition.name}` '
      'ON `${definition.table}` ($columns)',
    );
  }

  Future<void> _migrateToV9(MySqlDatabase d) async {
    await _seedComplianceDemoData(d);
  }

  /// Sample records for compliance modules (retention, duplicates, disposal, etc.).
  Future<void> _seedComplianceDemoData(MySqlDatabase d) async {
    if (!_demoDataEnabled) {
      await _removeDemoData(d);
      return;
    }

    final demoCheck = await d.rawQuery(
      "SELECT COUNT(*) AS cnt FROM students WHERE student_no LIKE 'DEMO-%'",
    );
    final demoCount = demoCheck.first['cnt'];
    if (demoCount is num && demoCount > 0) return;

    var courseName = 'Secondary Education';
    final courseRows = await d.rawQuery(
      'SELECT name FROM courses ORDER BY id ASC LIMIT 1',
    );
    if (courseRows.isNotEmpty) {
      courseName = (courseRows.first['name'] ?? courseName).toString();
    }

    final collegeRows = await d.rawQuery(
      'SELECT name FROM colleges ORDER BY id ASC LIMIT 1',
    );
    final collegeName = collegeRows.isEmpty
        ? 'EDUC - College of Education (COEd)'
        : (collegeRows.first['name'] ?? '').toString();

    await d.rawInsert(
      '''
      INSERT INTO students (student_no, full_name, course, year, status, email, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        'DEMO-2024-001',
        'Maria Clara Santos',
        courseName,
        4,
        'graduated',
        'maria.santos@jrmsu.edu.ph',
        '2024-03-15 08:00:00',
      ],
    );

    await d.rawInsert(
      '''
      INSERT INTO students (student_no, full_name, course, year, status, email, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        'DEMO-2023-014',
        'Juan Miguel Reyes',
        courseName,
        4,
        'graduated',
        'juan.reyes@jrmsu.edu.ph',
        '2023-05-20 09:30:00',
      ],
    );

    const duplicateHash =
        'a3f5c8d9e2b147608915263748596a0b1c2d3e4f5678901234567890abcd';

    Future<int> insertDemoDoc({
      required String title,
      required String student,
      required String studentNo,
      required String documentType,
      required String createdAt,
      required String contentHash,
      int sizeBytes = 245760,
    }) async {
      return d.rawInsert(
        '''
        INSERT INTO documents
          (title, student, image_path, mime_type, size_bytes,
           document_type, school_year, program, student_no, storage_path,
           college, student_category, content_hash, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          title,
          student,
          '/uploads/demo/$studentNo/${documentType.replaceAll(' ', '_')}.pdf',
          'application/pdf',
          sizeBytes,
          documentType,
          '2023-2024',
          'BSED',
          studentNo,
          'demo/$studentNo/${documentType.replaceAll(' ', '_')}.pdf',
          collegeName,
          'Graduated',
          contentHash,
          createdAt,
        ],
      );
    }

    final expiredTranscript = await insertDemoDoc(
      title: 'Transcript of Records — Maria Santos',
      student: 'Maria Clara Santos',
      studentNo: 'DEMO-2024-001',
      documentType: 'Transcript of Records',
      createdAt: '2014-06-10 10:00:00',
      contentHash: 'hash_transcript_maria_001',
    );
    await insertDemoDoc(
      title: 'Form 137 — Juan Reyes',
      student: 'Juan Miguel Reyes',
      studentNo: 'DEMO-2023-014',
      documentType: 'Form 137',
      createdAt: '2013-01-20 11:00:00',
      contentHash: 'hash_form137_juan_001',
    );
    await insertDemoDoc(
      title: 'Certificate — Maria Santos',
      student: 'Maria Clara Santos',
      studentNo: 'DEMO-2024-001',
      documentType: 'Certificate',
      createdAt: '2019-07-01 14:00:00',
      contentHash: 'hash_cert_maria_001',
    );
    await insertDemoDoc(
      title: 'Misc Registrar Form — Juan Reyes',
      student: 'Juan Miguel Reyes',
      studentNo: 'DEMO-2023-014',
      documentType: 'Other',
      createdAt: '2019-08-15 09:00:00',
      contentHash: 'hash_other_juan_001',
    );
    await insertDemoDoc(
      title: 'Diploma — Maria Santos',
      student: 'Maria Clara Santos',
      studentNo: 'DEMO-2024-001',
      documentType: 'Diploma',
      createdAt: '2024-04-01 16:00:00',
      contentHash: 'hash_diploma_maria_001',
    );
    await insertDemoDoc(
      title: 'Transcript Copy A — Maria Santos',
      student: 'Maria Clara Santos',
      studentNo: 'DEMO-2024-001',
      documentType: 'Transcript of Records',
      createdAt: '2022-03-10 10:00:00',
      contentHash: duplicateHash,
    );
    await insertDemoDoc(
      title: 'Transcript Copy B — Maria Santos (duplicate upload)',
      student: 'Maria Clara Santos',
      studentNo: 'DEMO-2024-001',
      documentType: 'Transcript of Records',
      createdAt: '2023-06-18 10:00:00',
      contentHash: duplicateHash,
    );

    const auditEntries = [
      [
        'admin@gmail.com',
        'document_uploaded',
        'document',
        'demo',
        'Uploaded demo transcript'
      ],
      [
        'staff@gmail.com',
        'student_created',
        'student',
        'DEMO-2024-001',
        'Registered Maria Santos'
      ],
      [
        'admin@gmail.com',
        'backup_created',
        'backup',
        'demo_backup_20250601',
        'Scheduled weekly backup'
      ],
      [
        'admin@gmail.com',
        'disposal_approved',
        'document',
        'demo',
        'Approved expired transcript disposal'
      ],
      [
        'staff@gmail.com',
        'document_uploaded',
        'document',
        'demo',
        'Uploaded Form 137 scan'
      ],
    ];
    for (final entry in auditEntries) {
      await d.rawInsert(
        '''
        INSERT INTO audit_logs (actor, action, resource_type, resource_id, details, created_at)
        VALUES (?, ?, ?, ?, ?, DATE_SUB(NOW(), INTERVAL ? DAY))
        ''',
        [...entry, auditEntries.indexOf(entry)],
      );
    }

    await d.rawInsert(
      '''
      INSERT INTO backup_records (label, backup_path, size_bytes, status, created_at)
      VALUES (?, ?, ?, ?, ?)
      ''',
      [
        'demo_backup_20250601',
        'backups/demo_backup_20250601',
        15728640,
        'completed',
        '2025-06-01 02:00:00',
      ],
    );
    await d.rawInsert(
      '''
      INSERT INTO backup_records (label, backup_path, size_bytes, status, created_at)
      VALUES (?, ?, ?, ?, ?)
      ''',
      [
        'demo_backup_20250515',
        'backups/demo_backup_20250515',
        14680064,
        'completed',
        '2025-05-15 02:00:00',
      ],
    );

    await d.rawInsert(
      '''
      INSERT INTO disposal_queue (document_id, status, reason, recommended_date, created_at)
      VALUES (?, ?, ?, ?, ?)
      ''',
      [
        expiredTranscript,
        'pending',
        'Retention period exceeded (10 years)',
        '2024-06-10',
        '2025-06-01 08:00:00',
      ],
    );
  }

  Future<void> _seedDisposableDemoData(MySqlDatabase d) async {
    if (!_demoDataEnabled) {
      await _removeDemoData(d);
      return;
    }

    final rows = await d.rawQuery(
      "SELECT COUNT(*) AS cnt FROM students WHERE student_no = 'DEMO-2001-020'",
    );
    final total = rows.first['cnt'];
    if (total is num && total > 0) return;

    var courseName = 'Secondary Education';
    final courseRows = await d.rawQuery(
      'SELECT name FROM courses ORDER BY id ASC LIMIT 1',
    );
    if (courseRows.isNotEmpty) {
      courseName = (courseRows.first['name'] ?? courseName).toString();
    }

    await d.rawInsert(
      '''
      INSERT INTO students
        (student_no, full_name, course, year, status, email, graduation_date,
         last_enrollment_date, retention_basis, disposal_status, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        'DEMO-2001-020',
        'Elena Cruz Navarro',
        courseName,
        4,
        'graduated',
        '',
        '2001-04-02',
        '2001-03-15',
        'graduation_date',
        'pending',
        '2001-04-02 08:00:00',
      ],
    );
  }

  bool get _demoDataEnabled =>
      Platform.environment['E_ARCHIVE_ENABLE_DEMO_DATA']
          ?.trim()
          .toLowerCase() ==
      'true';

  Future<void> _removeDemoData(MySqlDatabase d) async {
    await d.rawDelete(
      '''
      DELETE FROM disposal_queue
      WHERE document_id IN (
        SELECT id FROM documents
        WHERE student_no LIKE 'DEMO-%'
           OR storage_path LIKE 'demo/%'
           OR image_path LIKE '/uploads/demo/%'
      )
      ''',
    );
    await d.rawDelete(
      '''
      DELETE FROM documents
      WHERE student_no LIKE 'DEMO-%'
         OR storage_path LIKE 'demo/%'
         OR image_path LIKE '/uploads/demo/%'
      ''',
    );
    await d.rawDelete(
      "DELETE FROM students WHERE student_no LIKE 'DEMO-%'",
    );
    await d.rawDelete(
      '''
      DELETE FROM audit_logs
      WHERE resource_id = 'demo'
         OR resource_id LIKE 'DEMO-%'
         OR resource_id LIKE 'demo_backup_%'
         OR LOWER(details) LIKE '%demo%'
      ''',
    );
    await d.rawDelete(
      "DELETE FROM backup_records WHERE label LIKE 'demo_backup_%'",
    );

    final demoUploads = Directory(p.join(uploadsDir.path, 'demo'));
    if (demoUploads.existsSync()) {
      demoUploads.deleteSync(recursive: true);
    }
    final backupRoot = Directory(p.join(uploadsDir.parent.path, 'backups'));
    if (backupRoot.existsSync()) {
      for (final entity in backupRoot.listSync()) {
        if (entity is Directory &&
            p.basename(entity.path).startsWith('demo_backup_')) {
          entity.deleteSync(recursive: true);
        }
      }
    }
  }

  Future<void> _migrateToV8(MySqlDatabase d) async {
    await _addColumnIfNotExists(d, 'documents', 'content_hash', 'TEXT');

    await d.execute('''
      CREATE TABLE IF NOT EXISTS retention_policies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_type TEXT NOT NULL UNIQUE,
        retention_years INTEGER NOT NULL DEFAULT 7,
        legal_basis TEXT NOT NULL DEFAULT '',
        iso_reference TEXT NOT NULL DEFAULT 'ISO 15489-1:2016',
        description TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await d.execute('''
      CREATE TABLE IF NOT EXISTS access_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT NOT NULL,
        resource TEXT NOT NULL,
        action TEXT NOT NULL,
        allowed INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        UNIQUE(role, resource, action)
      )
    ''');

    await d.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        actor TEXT NOT NULL,
        action TEXT NOT NULL,
        resource_type TEXT NOT NULL DEFAULT '',
        resource_id TEXT NOT NULL DEFAULT '',
        details TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await d.execute('''
      CREATE TABLE IF NOT EXISTS backup_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT NOT NULL UNIQUE,
        backup_path TEXT NOT NULL,
        size_bytes INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'completed',
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await d.execute('''
      CREATE TABLE IF NOT EXISTS disposal_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL UNIQUE,
        status TEXT NOT NULL DEFAULT 'pending',
        reason TEXT NOT NULL DEFAULT '',
        recommended_date TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (document_id) REFERENCES documents(id)
      )
    ''');

    await _seedComplianceDefaults(d);
  }

  Future<void> _seedComplianceDefaults(MySqlDatabase d) async {
    final policyCount =
        await d.rawQuery('SELECT COUNT(*) AS cnt FROM retention_policies');
    final policyTotal = policyCount.first['cnt'];
    if (policyTotal is num && policyTotal == 0) {
      const policies = [
        [
          'Form 137',
          10,
          'DepEd Order + RA 9470',
          'ISO 15489-1:2016',
          'Permanent academic record'
        ],
        [
          'Transcript of Records',
          10,
          'CHED + RA 9470',
          'ISO 15489-1:2016',
          'Official academic transcript'
        ],
        ['Diploma', 10, 'RA 9470', 'ISO 15489-1:2016', 'Graduation credential'],
        [
          'Certificate',
          7,
          'RA 9470',
          'ISO 15489-1:2016',
          'Supplementary certificate'
        ],
        [
          'Other',
          7,
          'RA 9470 + RA 10173',
          'ISO 15489-1:2016',
          'General registrar document'
        ],
      ];
      for (final row in policies) {
        await d.rawInsert(
          '''
          INSERT IGNORE INTO retention_policies
            (document_type, retention_years, legal_basis, iso_reference, description)
          VALUES (?, ?, ?, ?, ?)
          ''',
          row,
        );
      }
    }

    const rules = [
      ['admin', 'documents', 'delete', 1],
      ['admin', 'documents', 'upload', 1],
      ['admin', 'students', 'delete', 1],
      ['admin', 'courses', 'delete', 1],
      ['admin', 'colleges', 'delete', 1],
      ['admin', 'users', 'manage', 1],
      ['admin', 'compliance', 'manage', 1],
      ['admin', 'backup', 'restore', 1],
      ['admin', 'disposal', 'manage', 1],
      ['staff', 'documents', 'upload', 1],
      ['staff', 'documents', 'delete', 0],
      ['staff', 'students', 'delete', 0],
      ['staff', 'courses', 'delete', 0],
      ['staff', 'colleges', 'delete', 0],
      ['staff', 'users', 'manage', 0],
      ['staff', 'compliance', 'manage', 0],
      ['staff', 'backup', 'restore', 0],
      ['staff', 'disposal', 'manage', 0],
    ];
    for (final row in rules) {
      await d.rawInsert(
        '''
        INSERT IGNORE INTO access_rules (role, resource, action, allowed)
        VALUES (?, ?, ?, ?)
        ''',
        row,
      );
    }
  }

  Future<void> _migrateToV4(MySqlDatabase d) async {
    const renames = <String, String>{
      'CCS': 'CCS - College of Computer Studies',
      'EDUC': 'EDUC - College of Education (COEd)',
      'CRIM': 'CRIM - College of Criminal Justice Education (CCJE)',
      'CAF': 'CAF - College of Agriculture and Forestry',
      'Engineering': 'Engineering - College of Engineering',
      'BSBA':
          'BSBA - College of Business Administration and Hospitality Management',
    };
    for (final entry in renames.entries) {
      await d.rawUpdate(
        'UPDATE colleges SET name = ? WHERE name = ?',
        [entry.value, entry.key],
      );
    }
  }

  Future<void> _migrateToV6(MySqlDatabase d) async {
    await _addColumnIfNotExists(d, 'documents', 'college', 'TEXT');
    await _addColumnIfNotExists(d, 'documents', 'student_category', 'TEXT');
  }

  /// Removes legacy placeholder program names from the courses table.
  Future<void> _migrateToV7(MySqlDatabase d) async {
    await d.rawDelete(
      "DELETE FROM courses WHERE name IN ('Information Technology', 'Business Administration')",
    );
  }

  Future<void> _migrateToV5(MySqlDatabase d) async {
    const cafName = 'CAF - College of Agriculture and Forestry';
    const forestryNames = ['Forestry', 'Forestry - College of Forestry'];

    int? cafId;
    final cafRows = await d.rawQuery(
      "SELECT id FROM colleges WHERE name = ? OR name = 'CAF' LIMIT 1",
      [cafName],
    );
    if (cafRows.isNotEmpty) {
      cafId = cafRows.first['id'] as int?;
    }

    for (final forestryName in forestryNames) {
      final forestryRows = await d.rawQuery(
        'SELECT id FROM colleges WHERE name = ? LIMIT 1',
        [forestryName],
      );
      if (forestryRows.isEmpty) continue;
      final forestryId = forestryRows.first['id'] as int?;
      if (forestryId == null) continue;

      if (cafId == null) {
        await d.rawUpdate(
          'UPDATE colleges SET name = ? WHERE id = ?',
          [cafName, forestryId],
        );
        cafId = forestryId;
        continue;
      }

      if (forestryId != cafId) {
        await d.rawUpdate(
          'UPDATE courses SET college_id = ? WHERE college_id = ?',
          [cafId, forestryId],
        );
        await d.rawDelete('DELETE FROM colleges WHERE id = ?', [forestryId]);
      }
    }
  }

  Future<void> _migrateToV3(MySqlDatabase d) async {
    await _addColumnIfNotExists(d, 'courses', 'code', 'TEXT');
    await _addColumnIfNotExists(d, 'documents', 'document_type', 'TEXT');
    await _addColumnIfNotExists(d, 'documents', 'school_year', 'TEXT');
    await _addColumnIfNotExists(d, 'documents', 'program', 'TEXT');
    await _addColumnIfNotExists(d, 'documents', 'student_no', 'TEXT');
    await _addColumnIfNotExists(d, 'documents', 'storage_path', 'TEXT');
    await _addColumnIfNotExists(d, 'documents', 'tags', 'TEXT');
    await _addColumnIfNotExists(d, 'documents', 'uploader', 'TEXT');

    await d.rawUpdate(
      "UPDATE courses SET code = 'BSED' WHERE name = 'Secondary Education' AND (code IS NULL OR code = '')",
    );
  }

  Future<void> _migrateToV2(MySqlDatabase d) async {
    await _addColumnIfNotExists(d, 'courses', 'college_id', 'INTEGER');

    final colleges = await d.rawQuery(
      'SELECT id FROM colleges ORDER BY id ASC LIMIT 1',
    );
    if (colleges.isEmpty) return;
    final firstCollegeId = colleges.first['id'];
    await d.rawUpdate(
      'UPDATE courses SET college_id = ? WHERE college_id IS NULL',
      [firstCollegeId],
    );
  }

  Future<void> _addColumnIfNotExists(
    MySqlDatabase d,
    String table,
    String column,
    String type,
  ) async {
    if (await d.columnExists(table, column)) return;
    await d.execute('ALTER TABLE $table ADD COLUMN $column $type');
  }

  Future<void> _dropIndexIfExists(
    MySqlDatabase d,
    String table,
    String indexName,
  ) async {
    final rows = await d.rawQuery(
      '''
      SELECT DISTINCT index_name
      FROM information_schema.statistics
      WHERE table_schema = DATABASE()
        AND table_name = ?
        AND (
          index_name = ?
          OR (column_name = ? AND non_unique = 0)
        )
        AND index_name <> 'PRIMARY'
      ''',
      [table, indexName, indexName],
    );
    for (final row in rows) {
      final name = (row['index_name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      try {
        await d.execute('ALTER TABLE $table DROP INDEX $name');
      } catch (_) {
        // Keep startup resilient if a legacy database uses a different index name.
      }
    }
  }

  Future<void> _seedDefaultCourses(MySqlDatabase d) async {
    final count = await d.rawQuery('SELECT COUNT(*) AS cnt FROM courses');
    if (count.isEmpty) return;
    final total = count.first['cnt'];
    if (total is num && total > 0) return;

    final colleges = await d.rawQuery(
      'SELECT id, name FROM colleges ORDER BY id ASC',
    );
    if (colleges.isEmpty) return;

    int? collegeIdFor(String abbrev) {
      final key = abbrev.toUpperCase();
      for (final row in colleges) {
        final name = (row['name'] ?? '').toString();
        final upper = name.toUpperCase();
        if (upper == key || upper.startsWith('$key -')) {
          return row['id'] as int?;
        }
      }
      return colleges.first['id'] as int?;
    }

    final defaults = <(String name, String code, String collegeAbbrev)>[
      ('Secondary Education', 'BSED', 'EDUC'),
    ];
    for (final entry in defaults) {
      final collegeId = collegeIdFor(entry.$3);
      await d.rawInsert(
        'INSERT INTO courses (name, code, college_id) VALUES (?, ?, ?)',
        [entry.$1, entry.$2, collegeId],
      );
    }
  }

  Future<void> _seedDefaultColleges(MySqlDatabase d) async {
    final count = await d.rawQuery('SELECT COUNT(*) AS cnt FROM colleges');
    if (count.isEmpty) return;
    final total = count.first['cnt'];
    if (total is num && total > 0) return;

    const defaults = [
      ['CCS - College of Computer Studies', 1],
      ['EDUC - College of Education (COEd)', 1],
      ['CRIM - College of Criminal Justice Education (CCJE)', 1],
      ['CAF - College of Agriculture and Forestry', 1],
      ['Engineering - College of Engineering', 1],
      [
        'BSBA - College of Business Administration and Hospitality Management',
        1,
      ],
    ];
    for (final row in defaults) {
      await d.rawInsert(
        'INSERT INTO colleges (name, is_active) VALUES (?, ?)',
        row,
      );
    }
  }

  Future<void> _seedDefaultUsers(MySqlDatabase d) async {
    final count = await d.rawQuery('SELECT COUNT(*) AS cnt FROM users');
    final total = count.first['cnt'];
    if (total is num && total > 0) return;

    final defaults = [
      [
        'ADM-0001',
        'admin',
        'System Administrator',
        'admin@gmail.com',
        'admin',
        'admin',
        'active',
        'Administrator',
        _hashPassword('admin123'),
        1,
      ],
      [
        'STF-0001',
        'staff',
        'Registrar Staff',
        'staff@gmail.com',
        'staff',
        'staff',
        'active',
        'Registrar Staff',
        _hashPassword('staff123'),
        1,
      ],
    ];

    for (final row in defaults) {
      await d.rawInsert(
        '''
        INSERT INTO users
          (user_no, username, full_name, email, role, account_type, status,
           position, password_hash, is_active)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        row,
      );
    }
  }

  Future<void> _dropColumnIfExists(
    MySqlDatabase d,
    String table,
    String column,
  ) async {
    if (!await d.columnExists(table, column)) return;
    try {
      await d.execute('ALTER TABLE $table DROP COLUMN $column');
    } catch (_) {
      // Ignore missing-column or unsupported drop failures.
    }
  }

  Future<List<Map<String, Object?>>> fetchCourses({int? collegeId}) async {
    final results = collegeId != null
        ? await db.rawQuery(
            '''
            SELECT * FROM courses
            WHERE college_id = ?
              AND EXISTS (
                SELECT 1 FROM colleges
                WHERE colleges.id = courses.college_id
                  AND colleges.deleted_at = ''
              )
            ORDER BY name ASC
            ''',
            [collegeId],
          )
        : await db.rawQuery(
            '''
            SELECT * FROM courses
            WHERE college_id IS NULL OR EXISTS (
              SELECT 1 FROM colleges
              WHERE colleges.id = courses.college_id
                AND colleges.deleted_at = ''
            )
            ORDER BY name ASC
            ''',
          );
    return results.map(_rowToMap).toList();
  }

  Future<Map<String, Object?>> insertCourse({
    required String name,
    int? collegeId,
    String? code,
  }) async {
    final id = await db.rawInsert(
      '''
      INSERT INTO courses (name, college_id, code)
      VALUES (?, ?, ?)
      ''',
      [name, collegeId, code?.trim()],
    );

    return (await _courseById(id))!;
  }

  Future<Map<String, Object?>?> updateCourse({
    required int id,
    required String name,
    int? collegeId,
    String? code,
  }) async {
    final current = await _courseById(id);
    if (current == null) return null;
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw StateError('Program name is required.');
    }
    final previousName = '${current['name']}'.trim();
    final previousCode = '${current['code'] ?? ''}'.trim();
    final nextCode = code == null ? previousCode : code.trim();

    if (collegeId != null) {
      await db.rawUpdate(
        '''
        UPDATE courses
        SET name = ?, college_id = ?, code = COALESCE(?, code)
        WHERE id = ?
        ''',
        [normalizedName, collegeId, code?.trim(), id],
      );
    } else {
      await db.rawUpdate(
        '''
        UPDATE courses
        SET name = ?, code = COALESCE(?, code)
        WHERE id = ?
        ''',
        [normalizedName, code?.trim(), id],
      );
    }

    if (previousName != normalizedName) {
      await db.rawUpdate(
        'UPDATE students SET course = ? WHERE course = ?',
        [normalizedName, previousName],
      );
    }
    final previousProgram = previousCode.isEmpty ? previousName : previousCode;
    final nextProgram = nextCode.isEmpty ? normalizedName : nextCode;
    if (previousProgram != nextProgram) {
      await db.rawUpdate(
        'UPDATE documents SET program = ? WHERE program = ?',
        [nextProgram, previousProgram],
      );
    }
    return _courseById(id);
  }

  Future<bool> deleteCourse(int id) async {
    final course = await _courseById(id);
    if (course == null) return false;
    final name = '${course['name']}'.trim();
    final code = '${course['code'] ?? ''}'.trim();
    final studentCount = _countValue(await db.rawQuery(
      'SELECT COUNT(*) AS count FROM students WHERE course = ?',
      [name],
    ));
    final documentCount = _countValue(await db.rawQuery(
      code.isEmpty
          ? 'SELECT COUNT(*) AS count FROM documents '
              "WHERE program = ? AND deleted_at = ''"
          : 'SELECT COUNT(*) AS count FROM documents '
              "WHERE program IN (?, ?) AND deleted_at = ''",
      code.isEmpty ? [name] : [name, code],
    ));
    if (studentCount > 0 || documentCount > 0) {
      throw StateError(
        'Cannot delete this program while it has related data. '
        'Reassign $studentCount student(s) and $documentCount document(s) first.',
      );
    }
    final n = await db.rawDelete(
      'DELETE FROM courses WHERE id = ?',
      [id],
    );
    return n > 0;
  }

  Future<List<Map<String, Object?>>> fetchColleges() async {
    final results = await db.rawQuery(
      '''
      SELECT * FROM colleges
      WHERE deleted_at = ''
      ORDER BY name ASC
      ''',
    );
    return results.map(_rowToMap).toList();
  }

  Future<List<Map<String, Object?>>> fetchDeletedColleges() async {
    final results = await db.rawQuery(
      '''
      SELECT * FROM colleges
      WHERE deleted_at != ''
      ORDER BY deleted_at DESC, name ASC
      ''',
    );
    return results.map(_rowToMap).toList();
  }

  Future<bool> validateUserLogin({
    required String username,
    required String password,
    required String role,
  }) async {
    final account = await authenticateUser(
      username: username,
      password: password,
    );
    return account != null &&
        '${account['role']}'.trim().toLowerCase() == role.trim().toLowerCase();
  }

  Future<Map<String, Object?>?> authenticateUser({
    required String username,
    required String password,
  }) async {
    final normalizedUser = username.trim().toLowerCase();
    if (normalizedUser.isEmpty || password.isEmpty) return null;

    final rows = await db.rawQuery(
      '''
      SELECT id, user_no, username, full_name, email, role FROM users
      WHERE is_active = 1
        AND LOWER(status) = 'active'
        AND password_hash = ?
        AND (
          LOWER(username) = ?
          OR LOWER(email) = ?
          OR LOWER(user_no) = ?
        )
      LIMIT 1
      ''',
      [
        _hashPassword(password),
        normalizedUser,
        normalizedUser,
        normalizedUser,
      ],
    );
    if (rows.isEmpty) return null;
    final id = rows.first['id'];
    if (id is int) {
      await db.rawUpdate(
        'UPDATE users SET last_login_at = CURRENT_TIMESTAMP WHERE id = ?',
        [id],
      );
    }
    return Map<String, Object?>.from(rows.first);
  }

  Future<List<Map<String, Object?>>> fetchUsers() async {
    final results = await db.rawQuery(
      '''
      SELECT id, user_no, username, full_name, email, role, account_type,
             status, position, is_active, last_login_at, created_at
      FROM users
      ORDER BY created_at DESC
      ''',
    );
    return results.map(_rowToMap).toList();
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
    final normalizedRole = _validatedUserRole(role);
    final normalizedStatus = _validatedUserStatus(status);
    _validateUserPassword(password);
    final resolvedUsername = username.trim().isNotEmpty
        ? username.trim()
        : (email.trim().isNotEmpty ? email.trim() : userNo.trim());
    final id = await db.rawInsert(
      '''
      INSERT INTO users
        (user_no, username, full_name, email, role, account_type, status,
         position, password_hash, is_active)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        userNo.trim(),
        resolvedUsername,
        fullName.trim(),
        email.trim(),
        normalizedRole,
        normalizedRole,
        normalizedStatus,
        position.trim(),
        _hashPassword(password),
        normalizedStatus == 'active' ? 1 : 0,
      ],
    );
    return (await _userById(id))!;
  }

  Future<Map<String, Object?>?> updateUserAccount({
    required String userNo,
    required String fullName,
    String username = '',
    String email = '',
    required String role,
    String password = '',
    String status = 'active',
    String position = '',
  }) async {
    final normalizedRole = _validatedUserRole(role);
    final normalizedStatus = _validatedUserStatus(status);
    await _protectLastActiveAdmin(
      userNo,
      nextRole: normalizedRole,
      nextStatus: normalizedStatus,
    );
    final resolvedUsername = username.trim().isNotEmpty
        ? username.trim()
        : (email.trim().isNotEmpty ? email.trim() : userNo.trim());
    final passwordValue = password.trim();
    if (passwordValue.isNotEmpty) {
      _validateUserPassword(passwordValue);
    }
    if (passwordValue.isEmpty) {
      await db.rawUpdate(
        '''
        UPDATE users
        SET username = ?, full_name = ?, email = ?, role = ?, account_type = ?,
            status = ?, position = ?, is_active = ?
        WHERE user_no = ?
        ''',
        [
          resolvedUsername,
          fullName.trim(),
          email.trim(),
          normalizedRole,
          normalizedRole,
          normalizedStatus,
          position.trim(),
          normalizedStatus == 'active' ? 1 : 0,
          userNo.trim(),
        ],
      );
    } else {
      await db.rawUpdate(
        '''
        UPDATE users
        SET username = ?, full_name = ?, email = ?, role = ?, account_type = ?,
            status = ?, position = ?, password_hash = ?, is_active = ?
        WHERE user_no = ?
        ''',
        [
          resolvedUsername,
          fullName.trim(),
          email.trim(),
          normalizedRole,
          normalizedRole,
          normalizedStatus,
          position.trim(),
          _hashPassword(passwordValue),
          normalizedStatus == 'active' ? 1 : 0,
          userNo.trim(),
        ],
      );
    }
    return _userByUserNo(userNo);
  }

  Future<Map<String, Object?>?> updateUserRole({
    required String userNo,
    required String role,
  }) async {
    final normalizedRole = _validatedUserRole(role);
    await _protectLastActiveAdmin(userNo, nextRole: normalizedRole);
    await db.rawUpdate(
      '''
      UPDATE users
      SET role = ?, account_type = ?
      WHERE user_no = ?
      ''',
      [normalizedRole, normalizedRole, userNo.trim()],
    );
    return _userByUserNo(userNo);
  }

  Future<Map<String, Object?>?> updateUserStatus({
    required String userNo,
    required String status,
  }) async {
    final normalizedStatus = _validatedUserStatus(status);
    await _protectLastActiveAdmin(userNo, nextStatus: normalizedStatus);
    await db.rawUpdate(
      '''
      UPDATE users
      SET status = ?, is_active = ?
      WHERE user_no = ?
      ''',
      [normalizedStatus, normalizedStatus == 'active' ? 1 : 0, userNo.trim()],
    );
    return _userByUserNo(userNo);
  }

  Future<bool> deleteUser(String userNo) async {
    await _protectLastActiveAdmin(userNo, deleting: true);
    final n = await db.rawDelete(
      'DELETE FROM users WHERE user_no = ?',
      [userNo.trim()],
    );
    return n > 0;
  }

  Future<Map<String, Object?>> insertCollege({
    required String name,
    bool isActive = true,
  }) async {
    final id = await db.rawInsert(
      '''
      INSERT INTO colleges (name, is_active)
      VALUES (?, ?)
      ''',
      [name, isActive ? 1 : 0],
    );

    return (await _collegeById(id))!;
  }

  Future<Map<String, Object?>?> updateCollege({
    required int id,
    required String name,
    bool isActive = true,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw StateError('College name is required.');
    }

    final current = await _collegeById(id);
    if (current == null) return null;

    final duplicates = await db.rawQuery(
      'SELECT id FROM colleges WHERE name = ? AND id <> ? LIMIT 1',
      [normalizedName, id],
    );
    if (duplicates.isNotEmpty) {
      throw StateError('A college with this name already exists.');
    }

    final previousName = (current['name'] ?? '').toString();
    await db.rawUpdate(
      '''
      UPDATE colleges
      SET name = ?, is_active = ?
      WHERE id = ?
      ''',
      [normalizedName, isActive ? 1 : 0, id],
    );

    if (previousName.isNotEmpty && previousName != normalizedName) {
      await db.rawUpdate(
        'UPDATE documents SET college = ? WHERE college = ?',
        [normalizedName, previousName],
      );
    }
    return _collegeById(id);
  }

  Future<bool> deleteCollege(int id, {String deletedBy = ''}) async {
    final college = await _collegeById(id);
    if (college == null) return false;
    final collegeName = (college['name'] ?? '').toString().trim();
    final courseRows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM courses WHERE college_id = ?',
      [id],
    );
    final documentRows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count FROM documents
       WHERE college = ?
         AND deleted_at = ''
      ''',
      [collegeName],
    );
    final courseCount = _countValue(courseRows);
    final documentCount = _countValue(documentRows);
    if (courseCount > 0 || documentCount > 0) {
      throw StateError(
        'Cannot move this college to Trash while it has related data. '
        'Reassign or delete $courseCount program(s) and $documentCount document(s) first.',
      );
    }
    final n = await db.rawUpdate(
      '''
      UPDATE colleges
      SET deleted_at = CURRENT_TIMESTAMP, deleted_by = ?
      WHERE id = ? AND deleted_at = ''
      ''',
      [deletedBy.trim(), id],
    );
    return n > 0;
  }

  Future<bool> restoreCollege(int id) async {
    final n = await db.rawUpdate(
      '''
      UPDATE colleges
      SET deleted_at = '', deleted_by = ''
      WHERE id = ? AND deleted_at != ''
      ''',
      [id],
    );
    return n > 0;
  }

  Future<bool> purgeCollege(int id) async {
    final college = await _collegeById(id);
    if (college == null) return false;
    final collegeName = (college['name'] ?? '').toString().trim();
    final courseCount = _countValue(await db.rawQuery(
      'SELECT COUNT(*) AS count FROM courses WHERE college_id = ?',
      [id],
    ));
    final documentCount = _countValue(await db.rawQuery(
      'SELECT COUNT(*) AS count FROM documents WHERE college = ?',
      [collegeName],
    ));
    if (courseCount > 0 || documentCount > 0) {
      throw StateError(
        'Cannot permanently remove this college while related data exists. '
        'Reassign or permanently remove $courseCount program(s) and $documentCount document(s) first.',
      );
    }
    final n = await db.rawDelete(
      '''
      DELETE FROM colleges
      WHERE id = ? AND deleted_at != ''
      ''',
      [id],
    );
    return n > 0;
  }

  Future<List<Map<String, Object?>>> fetchStudents({
    int? courseId,
    String? courseName,
  }) async {
    String? filterCourse = courseName?.trim();
    if ((filterCourse == null || filterCourse.isEmpty) && courseId != null) {
      final course = await _courseById(courseId);
      filterCourse = (course?['name'] ?? '').toString().trim();
    }

    final results = filterCourse != null && filterCourse.isNotEmpty
        ? await db.rawQuery(
            '''
            SELECT * FROM students
            WHERE course = ?
              AND deleted_at = ''
            ORDER BY created_at DESC
            ''',
            [filterCourse],
          )
        : await db.rawQuery(
            '''
            SELECT * FROM students
            WHERE deleted_at = ''
            ORDER BY created_at DESC
            ''',
          );
    return results.map(_rowToMap).toList();
  }

  Future<List<Map<String, Object?>>> fetchDeletedStudents() async {
    final results = await db.rawQuery(
      '''
      SELECT * FROM students
      WHERE deleted_at != ''
      ORDER BY deleted_at DESC, full_name ASC
      ''',
    );
    return results.map(_rowToMap).toList();
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
    await _ensureStudentProfileColumns(db);
    final normalizedNotes = notes.trim();
    if (normalizedNotes.length > 4000) {
      throw StateError('Student notes cannot exceed 4000 characters.');
    }
    final normalizedStudentNo = studentNo.trim().toUpperCase();
    if (normalizedStudentNo.isNotEmpty) {
      final existing = await db.rawQuery(
        '''
        SELECT id FROM students
        WHERE student_no = ?
        LIMIT 1
        ''',
        [normalizedStudentNo],
      );
      if (existing.isNotEmpty) {
        throw StateError('Student ID already exists.');
      }
    }

    final id = await db.rawInsert(
      '''
      INSERT INTO students
        (student_no, full_name, course, year, status, email, school_year,
         sex, birth_date,
         phone_number, notes,
         graduation_date, last_enrollment_date, retention_basis)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        normalizedStudentNo,
        fullName,
        course,
        year,
        status,
        email,
        schoolYear.trim(),
        sex.trim(),
        birthDate.trim(),
        phoneNumber.trim(),
        normalizedNotes,
        graduationDate.trim(),
        lastEnrollmentDate.trim(),
        retentionBasis.trim().isEmpty ? 'graduation_date' : retentionBasis,
      ],
    );

    return (await _studentById(id))!;
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
    await _ensureStudentProfileColumns(db);
    final normalizedNotes = notes.trim();
    if (normalizedNotes.length > 4000) {
      throw StateError('Student notes cannot exceed 4000 characters.');
    }
    final existingStudent = await _studentById(id);
    if (existingStudent == null) return null;

    final normalizedStudentNo = studentNo.trim().toUpperCase();
    if (normalizedStudentNo.isNotEmpty) {
      final duplicate = await db.rawQuery(
        '''
        SELECT id FROM students
        WHERE student_no = ?
          AND id <> ?
        LIMIT 1
        ''',
        [normalizedStudentNo, id],
      );
      if (duplicate.isNotEmpty) {
        throw StateError('Student ID already exists.');
      }
    }

    final oldStudentNo = (existingStudent['student_no'] ?? '').toString();
    final oldFullName = (existingStudent['full_name'] ?? '').toString();
    await db.rawUpdate(
      '''
      UPDATE students
      SET student_no = ?, full_name = ?, course = ?, year = ?, status = ?,
          email = ?, school_year = ?, sex = ?, birth_date = ?,
          phone_number = ?, notes = ?, graduation_date = ?,
          last_enrollment_date = ?,
          retention_basis = ?
      WHERE id = ?
      ''',
      [
        normalizedStudentNo,
        fullName.trim(),
        course.trim(),
        year,
        status.trim().isEmpty ? 'graduated' : status.trim(),
        email.trim(),
        schoolYear.trim(),
        sex.trim(),
        birthDate.trim(),
        phoneNumber.trim(),
        normalizedNotes,
        graduationDate.trim(),
        lastEnrollmentDate.trim(),
        retentionBasis.trim().isEmpty ? 'graduation_date' : retentionBasis,
        id,
      ],
    );

    final trimmedOldStudentNo = oldStudentNo.trim();
    if (trimmedOldStudentNo.isNotEmpty) {
      await db.rawUpdate(
        '''
        UPDATE documents
        SET student = ?, student_no = ?, school_year = ?
        WHERE student_no = ?
           OR (
             (student_no IS NULL OR TRIM(student_no) = '')
             AND LOWER(TRIM(student)) = LOWER(?)
           )
        ''',
        [
          fullName.trim(),
          normalizedStudentNo,
          schoolYear.trim(),
          trimmedOldStudentNo,
          oldFullName.trim(),
        ],
      );
    } else {
      await db.rawUpdate(
        '''
        UPDATE documents
        SET student = ?, student_no = ?, school_year = ?
        WHERE (student_no IS NULL OR TRIM(student_no) = '')
          AND LOWER(TRIM(student)) = LOWER(?)
        ''',
        [
          fullName.trim(),
          normalizedStudentNo,
          schoolYear.trim(),
          oldFullName.trim(),
        ],
      );
    }

    return _studentById(id);
  }

  Future<void> _ensureStudentProfileColumns(MySqlDatabase d) async {
    await _addColumnIfNotExists(
      d,
      'students',
      'school_year',
      "VARCHAR(32) NOT NULL DEFAULT ''",
    );
    await _addColumnIfNotExists(
      d,
      'students',
      'sex',
      "VARCHAR(32) NOT NULL DEFAULT ''",
    );
    await _addColumnIfNotExists(
      d,
      'students',
      'birth_date',
      "VARCHAR(32) NOT NULL DEFAULT ''",
    );
    await _addColumnIfNotExists(
      d,
      'students',
      'phone_number',
      "VARCHAR(64) NOT NULL DEFAULT ''",
    );
    await _addColumnIfNotExists(
      d,
      'students',
      'notes',
      "VARCHAR(4096) NOT NULL DEFAULT ''",
    );
  }

  Future<List<Map<String, Object?>>> fetchDisposableStudentRecords({
    int retentionYears = 20,
  }) async {
    final results = await db.rawQuery(
      '''
      SELECT *,
        DATE(COALESCE(
          NULLIF(graduation_date, ''),
          NULLIF(last_enrollment_date, ''),
          created_at
        )) AS retention_date
      FROM students
      WHERE DATE(COALESCE(
          NULLIF(graduation_date, ''),
          NULLIF(last_enrollment_date, ''),
          created_at
        )) <= DATE_SUB(CURDATE(), INTERVAL ? YEAR)
      ORDER BY retention_date ASC, full_name ASC
      ''',
      [retentionYears],
    );
    return results.map(_rowToMap).toList();
  }

  Future<Map<String, Object?>?> updateStudentDisposalStatus({
    required String studentNo,
    required String status,
    required String actor,
    String notes = '',
  }) async {
    final normalizedStudentNo = studentNo.trim();
    if (normalizedStudentNo.isEmpty) {
      throw StateError('Student ID is required for disposal actions.');
    }
    final normalizedStatus = status.trim().toLowerCase();
    if (normalizedStatus == 'approved') {
      await db.rawUpdate(
        '''
        UPDATE students
        SET disposal_status = 'approved',
            disposal_approved_at = CURRENT_TIMESTAMP,
            disposal_approved_by = ?,
            disposal_notes = ?
        WHERE student_no = ?
        ''',
        [actor.trim(), notes.trim(), normalizedStudentNo],
      );
    } else if (normalizedStatus == 'disposed') {
      await db.rawUpdate(
        '''
        UPDATE students
        SET disposal_status = 'disposed',
            disposed_at = CURRENT_TIMESTAMP,
            disposal_notes = ?
        WHERE student_no = ?
        ''',
        [notes.trim(), normalizedStudentNo],
      );
    } else {
      await db.rawUpdate(
        '''
        UPDATE students
        SET disposal_status = ?, disposal_notes = ?
        WHERE student_no = ?
        ''',
        [normalizedStatus, notes.trim(), normalizedStudentNo],
      );
    }
    return _studentByStudentNo(normalizedStudentNo);
  }

  Future<bool> deleteStudent(int id, {String deletedBy = ''}) async {
    final student = await _studentById(id);
    if (student == null) return false;

    final studentNo = (student['student_no'] ?? '').toString().trim();
    final fullName = (student['full_name'] ?? '').toString().trim();

    final docRows = studentNo.isNotEmpty
        ? await db.rawQuery(
            '''
            SELECT id FROM documents
            WHERE (
                student_no = ?
                OR (
                  (student_no IS NULL OR TRIM(student_no) = '')
                  AND LOWER(TRIM(student)) = LOWER(?)
                )
              )
              AND deleted_at = ''
            ''',
            [studentNo, fullName],
          )
        : await db.rawQuery(
            '''
            SELECT id FROM documents
            WHERE (student_no IS NULL OR TRIM(student_no) = '')
              AND LOWER(TRIM(student)) = LOWER(?)
              AND deleted_at = ''
            ''',
            [fullName],
          );

    if (docRows.isNotEmpty) {
      throw StateError(
        'Cannot move this student to Trash while ${docRows.length} related document(s) are active. '
        'Move or reassign the documents first.',
      );
    }

    final n = await db.rawUpdate(
      '''
      UPDATE students
      SET deleted_at = CURRENT_TIMESTAMP, deleted_by = ?
      WHERE id = ? AND deleted_at = ''
      ''',
      [deletedBy.trim(), id],
    );
    return n > 0;
  }

  Future<bool> restoreStudent(int id) async {
    final student = await _studentById(id);
    if (student == null) return false;
    final n = await db.rawUpdate(
      '''
      UPDATE students
      SET deleted_at = '', deleted_by = ''
      WHERE id = ? AND deleted_at != ''
      ''',
      [id],
    );
    return n > 0;
  }

  Future<bool> purgeStudent(int id) async {
    final student = await _studentById(id);
    if (student == null) return false;
    final deletedAt = (student['deleted_at'] ?? '').toString().trim();
    if (deletedAt.isEmpty) return false;
    final studentNo = (student['student_no'] ?? '').toString().trim();
    final fullName = (student['full_name'] ?? '').toString().trim();
    final docs = studentNo.isNotEmpty
        ? await db.rawQuery(
            '''
            SELECT id FROM documents
            WHERE student_no = ?
               OR (
                 (student_no IS NULL OR TRIM(student_no) = '')
                 AND LOWER(TRIM(student)) = LOWER(?)
               )
            ''',
            [studentNo, fullName],
          )
        : await db.rawQuery(
            '''
            SELECT id FROM documents
            WHERE (student_no IS NULL OR TRIM(student_no) = '')
              AND LOWER(TRIM(student)) = LOWER(?)
            ''',
            [fullName],
          );
    if (docs.isNotEmpty) {
      throw StateError(
        'Cannot permanently remove this student while ${docs.length} related document(s) exist. '
        'Reassign or permanently remove the documents first.',
      );
    }
    final n = await db.rawDelete(
      '''
      DELETE FROM students
      WHERE id = ? AND deleted_at != ''
      ''',
      [id],
    );
    return n > 0;
  }

  Future<List<Map<String, Object?>>> fetchDocuments() async {
    final results = await db.rawQuery(
      '''
      SELECT * FROM documents
      WHERE deleted_at = ''
      ORDER BY created_at DESC
      ''',
    );
    return results.map(_rowToMap).toList();
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
    final safeLimit = limit.clamp(1, 500);
    final where = <String>["deleted_at = ''"];
    final params = <Object?>[];
    final query = search.trim();
    if (query.isNotEmpty) {
      if (_documentFullTextSearchAvailable) {
        final booleanQuery = query
            .split(RegExp(r'\s+'))
            .where((term) => term.isNotEmpty)
            .map((term) => '${term.replaceAll(RegExp(r'[^\w-]'), '')}*')
            .where((term) => term.length > 1)
            .join(' ');
        where.add('''MATCH(
          title, student, student_no, document_type, school_year,
          college, program, tags
        ) AGAINST (? IN BOOLEAN MODE)''');
        params.add(booleanQuery);
      } else {
        final like = '%$query%';
        where.add('''(
          title LIKE ? OR student LIKE ? OR student_no LIKE ? OR
          document_type LIKE ? OR school_year LIKE ? OR college LIKE ? OR
          program LIKE ? OR tags LIKE ?
        )''');
        params.addAll(List<Object?>.filled(8, like));
      }
    }
    void exact(String column, String value) {
      if (value.trim().isEmpty) return;
      where.add('$column = ?');
      params.add(value.trim());
    }

    exact('school_year', schoolYear);
    exact('college', college);
    exact('program', program);
    exact('document_type', documentType);

    final countWhere = List<String>.from(where);
    final countParams = List<Object?>.from(params);
    if (beforeId != null) {
      where.add('id < ?');
      params.add(beforeId);
    }

    params.add(safeLimit + 1);
    final pageFuture = db.rawQuery('''
      SELECT id, title, student, image_path, mime_type, size_bytes,
             created_at, document_type, school_year, program, student_no,
             storage_path, college, student_category, tags, uploader,
             deleted_at, deleted_by
      FROM documents
      WHERE ${where.join(' AND ')}
      ORDER BY id DESC
      LIMIT ?
      ''', params);
    final countFuture = includeTotal
        ? db.rawQuery(
            'SELECT COUNT(*) AS total FROM documents '
            'WHERE ${countWhere.join(' AND ')}',
            countParams,
          )
        : Future<List<Map<String, Object?>>>.value(const []);
    final responses = await Future.wait([pageFuture, countFuture]);
    final results = responses[0];
    final totalValue =
        responses[1].isEmpty ? null : responses[1].first['total'];
    final hasMore = results.length > safeLimit;
    final pageRows = hasMore ? results.take(safeLimit).toList() : results;
    final rows = pageRows.map(_rowToMap).toList();
    return {
      'items': rows,
      'total': (totalValue as num?)?.toInt(),
      'has_more': hasMore,
      'next_before_id': rows.isEmpty ? null : rows.last['id'],
    };
  }

  Future<Map<String, Object?>> fetchDocumentSummary() async {
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS document_count,
             COALESCE(SUM(size_bytes), 0) AS total_size_bytes,
             COUNT(DISTINCT student_no) AS students_with_documents,
             (SELECT COUNT(*) FROM students s
               WHERE s.deleted_at = ''
                AND NOT EXISTS (
                  SELECT 1 FROM documents d2
                   WHERE d2.deleted_at = ''
                    AND d2.student_no = s.student_no
                )) AS students_without_documents
      FROM documents
       WHERE deleted_at = ''
    ''');
    return rows.isEmpty ? <String, Object?>{} : _rowToMap(rows.first);
  }

  Future<Map<String, Object?>> fetchDocumentAnalytics() async {
    const active = "deleted_at = ''";
    final results = await Future.wait([
      db.rawQuery('''
        SELECT COUNT(*) AS document_count,
               COALESCE(SUM(size_bytes), 0) AS total_size_bytes
        FROM documents WHERE $active
      '''),
      db.rawQuery('''
        SELECT COUNT(*) AS student_count FROM students
        WHERE deleted_at = ''
      '''),
      db.rawQuery('''
        SELECT COALESCE(NULLIF(document_type, ''), 'Other') AS label,
               COUNT(*) AS count
        FROM documents WHERE $active GROUP BY label
      '''),
      db.rawQuery('''
        SELECT COALESCE(NULLIF(college, ''), 'General') AS label,
               COUNT(*) AS count
        FROM documents WHERE $active GROUP BY label
      '''),
      db.rawQuery('''
        SELECT COALESCE(NULLIF(school_year, ''), 'Unknown') AS label,
               COUNT(*) AS count
        FROM documents WHERE $active GROUP BY label
      '''),
      db.rawQuery('''
        SELECT COUNT(*) AS duplicate_groups,
               COALESCE(SUM(copies - 1), 0) AS duplicate_documents
        FROM (
          SELECT COUNT(*) AS copies FROM documents
          WHERE $active AND content_hash IS NOT NULL AND content_hash != ''
          GROUP BY content_hash HAVING COUNT(*) > 1
        ) duplicate_counts
      '''),
    ]);
    Map<String, int> counts(List<Map<String, Object?>> rows) => {
          for (final row in rows)
            (row['label'] ?? '').toString():
                (row['count'] as num?)?.toInt() ?? 0,
        };
    final totals = results[0].first;
    final duplicate = results[5].first;
    return {
      'student_count':
          (results[1].first['student_count'] as num?)?.toInt() ?? 0,
      'document_count': (totals['document_count'] as num?)?.toInt() ?? 0,
      'total_size_bytes': (totals['total_size_bytes'] as num?)?.toInt() ?? 0,
      'by_type': counts(results[2]),
      'by_college': counts(results[3]),
      'by_year': counts(results[4]),
      'duplicate_groups': (duplicate['duplicate_groups'] as num?)?.toInt() ?? 0,
      'duplicate_documents':
          (duplicate['duplicate_documents'] as num?)?.toInt() ?? 0,
    };
  }

  Future<List<Map<String, Object?>>> fetchDeletedDocuments() async {
    final results = await db.rawQuery(
      '''
      SELECT * FROM documents
      WHERE deleted_at != ''
      ORDER BY deleted_at DESC, created_at DESC
      ''',
    );
    return results.map(_rowToMap).toList();
  }

  Future<Map<String, Object?>> insertDocument({
    required String title,
    required String student,
    required String imagePath,
    required String mimeType,
    required int sizeBytes,
    String documentType = '',
    String schoolYear = '',
    String program = '',
    String studentNo = '',
    String storagePath = '',
    String college = '',
    String studentCategory = '',
    String contentHash = '',
    String tags = '',
    String uploader = '',
  }) async {
    final id = await db.rawInsert(
      '''
      INSERT INTO documents
        (title, student, image_path, mime_type, size_bytes,
         document_type, school_year, program, student_no, storage_path,
         college, student_category, content_hash, tags, uploader)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        title,
        student,
        imagePath,
        mimeType,
        sizeBytes,
        documentType,
        schoolYear,
        program,
        studentNo,
        storagePath,
        college,
        studentCategory,
        contentHash,
        tags,
        uploader,
      ],
    );

    return (await _documentById(id))!;
  }

  Future<Map<String, Object?>?> updateDocumentMetadata({
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
    final count = await db.rawUpdate(
      '''
      UPDATE documents
      SET title = ?, document_type = ?, school_year = ?, program = ?,
          student_no = ?, storage_path = ?, college = ?, tags = ?
      WHERE id = ?
      ''',
      [
        title,
        documentType,
        schoolYear,
        program,
        studentNo,
        storagePath,
        college,
        tags,
        id,
      ],
    );
    if (count == 0) return null;
    return _documentById(id);
  }

  Future<Map<String, Object?>?> findDocumentByHash(String hash) async {
    final results = await db.rawQuery(
      '''
      SELECT * FROM documents
      WHERE content_hash = ?
        AND deleted_at = ''
      LIMIT 1
      ''',
      [hash],
    );
    if (results.isEmpty) return null;
    return _rowToMap(results.first);
  }

  Future<List<Map<String, Object?>>> fetchRetentionPolicies() async {
    final results = await db.rawQuery(
      'SELECT * FROM retention_policies ORDER BY document_type ASC',
    );
    return results.map(_rowToMap).toList();
  }

  Future<List<Map<String, Object?>>> fetchAccessRules() async {
    final results = await db.rawQuery(
      'SELECT * FROM access_rules ORDER BY role ASC, resource ASC',
    );
    return results.map(_rowToMap).toList();
  }

  Future<List<Map<String, Object?>>> fetchAuditLogs({int limit = 100}) async {
    final results = await db.rawQuery(
      'SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT ?',
      [limit],
    );
    return results.map(_rowToMap).toList();
  }

  Future<Map<String, Object?>> insertAuditLog({
    required String actor,
    required String action,
    String resourceType = '',
    String resourceId = '',
    String details = '',
  }) async {
    final id = await db.rawInsert(
      '''
      INSERT INTO audit_logs (actor, action, resource_type, resource_id, details)
      VALUES (?, ?, ?, ?, ?)
      ''',
      [actor, action, resourceType, resourceId, details],
    );
    final results = await db.rawQuery(
      'SELECT * FROM audit_logs WHERE id = ? LIMIT 1',
      [id],
    );
    return _rowToMap(results.first);
  }

  Future<List<Map<String, Object?>>> fetchBackupRecords() async {
    final results = await db.rawQuery(
      'SELECT * FROM backup_records ORDER BY created_at DESC',
    );
    return results.map(_rowToMap).toList();
  }

  Future<Map<String, Object?>> insertBackupRecord({
    required String label,
    required String backupPath,
    required int sizeBytes,
    String status = 'completed',
  }) async {
    final id = await db.rawInsert(
      '''
      INSERT INTO backup_records (label, backup_path, size_bytes, status)
      VALUES (?, ?, ?, ?)
      ''',
      [label, backupPath, sizeBytes, status],
    );
    final results = await db.rawQuery(
      'SELECT * FROM backup_records WHERE id = ? LIMIT 1',
      [id],
    );
    return _rowToMap(results.first);
  }

  Future<List<Map<String, Object?>>> fetchDisposalQueue() async {
    final results = await db.rawQuery(
      'SELECT * FROM disposal_queue ORDER BY created_at DESC',
    );
    return results.map(_rowToMap).toList();
  }

  Future<Map<String, Object?>> upsertDisposalQueue({
    required int documentId,
    required String status,
    required String reason,
    String recommendedDate = '',
  }) async {
    await db.rawInsert(
      '''
      INSERT INTO disposal_queue (document_id, status, reason, recommended_date)
      VALUES (?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        status = VALUES(status),
        reason = VALUES(reason),
        recommended_date = VALUES(recommended_date)
      ''',
      [documentId, status, reason, recommendedDate],
    );
    final results = await db.rawQuery(
      'SELECT * FROM disposal_queue WHERE document_id = ? LIMIT 1',
      [documentId],
    );
    return _rowToMap(results.first);
  }

  Future<bool> deleteDocument(int id, {String deletedBy = ''}) async {
    final rows = await db.rawQuery(
      'SELECT id FROM documents WHERE id = ? LIMIT 1',
      [id],
    );
    if (rows.isEmpty) return false;

    final n = await db.rawUpdate(
      '''
      UPDATE documents
      SET deleted_at = CURRENT_TIMESTAMP,
          deleted_by = ?
      WHERE id = ?
        AND deleted_at = ''
      ''',
      [deletedBy.trim(), id],
    );
    return n > 0;
  }

  Future<bool> restoreDocument(int id) async {
    final n = await db.rawUpdate(
      '''
      UPDATE documents
      SET deleted_at = '',
          deleted_by = ''
      WHERE id = ?
        AND deleted_at != ''
      ''',
      [id],
    );
    return n > 0;
  }

  Future<bool> purgeDocument(int id) async {
    final rows = await db.rawQuery(
      'SELECT image_path FROM documents WHERE id = ? LIMIT 1',
      [id],
    );
    if (rows.isEmpty) return false;

    final imagePath = (rows.first['image_path'] as String?)?.trim() ?? '';
    _deleteUploadIfLocal(imagePath);

    await db.rawDelete(
      'DELETE FROM disposal_queue WHERE document_id = ?',
      [id],
    );

    final n = await db.rawDelete(
      'DELETE FROM documents WHERE id = ?',
      [id],
    );
    return n > 0;
  }

  void _deleteUploadIfLocal(String imagePath) {
    if (!imagePath.startsWith('/uploads/')) return;
    final relative = imagePath
        .replaceFirst('/uploads/', '')
        .replaceAll('/', Platform.pathSeparator);
    final file = File(
      '${uploadsDir.path}${Platform.pathSeparator}$relative',
    );
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  Future<String?> programCodeForCourse(String courseName) async {
    final name = courseName.trim();
    if (name.isEmpty) return null;
    final rows = await db.rawQuery(
      'SELECT code FROM courses WHERE name = ? LIMIT 1',
      [name],
    );
    if (rows.isEmpty) return null;
    final code = (rows.first['code'] ?? '').toString().trim();
    return code.isEmpty ? null : code;
  }

  Future<String?> collegeNameForCourse(String courseName) async {
    final name = courseName.trim();
    if (name.isEmpty) return null;
    final rows = await db.rawQuery(
      '''
      SELECT c.name AS college_name
      FROM courses co
      INNER JOIN colleges c ON c.id = co.college_id
      WHERE co.name = ?
      LIMIT 1
      ''',
      [name],
    );
    if (rows.isEmpty) return null;
    final college = (rows.first['college_name'] ?? '').toString().trim();
    return college.isEmpty ? null : college;
  }

  Future<Map<String, Object?>?> _courseById(int id) async {
    final results = await db.rawQuery(
      'SELECT * FROM courses WHERE id = ? LIMIT 1',
      [id],
    );
    if (results.isEmpty) return null;
    return _rowToMap(results.first);
  }

  Future<Map<String, Object?>?> _collegeById(int id) async {
    final results = await db.rawQuery(
      'SELECT * FROM colleges WHERE id = ? LIMIT 1',
      [id],
    );
    if (results.isEmpty) return null;
    return _rowToMap(results.first);
  }

  Future<Map<String, Object?>?> _userById(int id) async {
    final results = await db.rawQuery(
      '''
      SELECT id, user_no, username, full_name, email, role, account_type,
             status, position, is_active, last_login_at, created_at
      FROM users
      WHERE id = ?
      LIMIT 1
      ''',
      [id],
    );
    if (results.isEmpty) return null;
    return _rowToMap(results.first);
  }

  Future<Map<String, Object?>?> _userByUserNo(String userNo) async {
    final results = await db.rawQuery(
      '''
      SELECT id, user_no, username, full_name, email, role, account_type,
             status, position, is_active, last_login_at, created_at
      FROM users
      WHERE user_no = ?
      LIMIT 1
      ''',
      [userNo.trim()],
    );
    if (results.isEmpty) return null;
    return _rowToMap(results.first);
  }

  Future<Map<String, Object?>?> _studentByStudentNo(String studentNo) async {
    final results = await db.rawQuery(
      'SELECT * FROM students WHERE student_no = ? LIMIT 1',
      [studentNo.trim()],
    );
    if (results.isEmpty) return null;
    return _rowToMap(results.first);
  }

  Future<Map<String, Object?>?> _studentById(int id) async {
    final results = await db.rawQuery(
      'SELECT * FROM students WHERE id = ? LIMIT 1',
      [id],
    );
    if (results.isEmpty) return null;
    return _rowToMap(results.first);
  }

  Future<Map<String, Object?>?> _documentById(int id) async {
    final results = await db.rawQuery(
      'SELECT * FROM documents WHERE id = ? LIMIT 1',
      [id],
    );
    if (results.isEmpty) return null;
    return _rowToMap(results.first);
  }

  int _countValue(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) return 0;
    final value = rows.first['count'];
    return value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  }

  Map<String, Object?> _rowToMap(Map<String, Object?> row) {
    final map = <String, Object?>{};
    for (final entry in row.entries) {
      final name = entry.key;
      final value = entry.value;
      if (value is DateTime) {
        map[name] = value.toUtc().toIso8601String();
      } else if (name == 'created_at' && value is String) {
        final parsed = DateTime.tryParse(value.replaceFirst(' ', 'T'));
        map[name] = parsed != null ? parsed.toUtc().toIso8601String() : value;
      } else {
        map[name] = value;
      }
    }
    return map;
  }

  String _validatedUserRole(String role) {
    final normalized = role.trim().toLowerCase();
    if (normalized != 'admin' && normalized != 'staff') {
      throw StateError('User role must be admin or staff.');
    }
    return normalized;
  }

  String _validatedUserStatus(String status) {
    final normalized =
        status.trim().isEmpty ? 'active' : status.trim().toLowerCase();
    if (normalized != 'active' && normalized != 'inactive') {
      throw StateError('User status must be active or inactive.');
    }
    return normalized;
  }

  void _validateUserPassword(String password) {
    if (password.trim().length < 8) {
      throw StateError('Password must be at least 8 characters.');
    }
  }

  Future<void> _protectLastActiveAdmin(
    String userNo, {
    String? nextRole,
    String? nextStatus,
    bool deleting = false,
  }) async {
    final user = await _userByUserNo(userNo);
    if (user == null) return;

    final isActiveAdmin = '${user['role']}'.toLowerCase() == 'admin' &&
        '${user['status']}'.toLowerCase() == 'active' &&
        user['is_active'] == 1;
    final removesAdminAccess = deleting ||
        (nextRole != null && nextRole != 'admin') ||
        (nextStatus != null && nextStatus != 'active');
    if (!isActiveAdmin || !removesAdminAccess) return;

    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count FROM users
      WHERE LOWER(role) = 'admin'
        AND LOWER(status) = 'active'
        AND is_active = 1
      ''',
    );
    if (_countValue(rows) <= 1) {
      throw StateError(
        'At least one active administrator account is required.',
      );
    }
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }
}

class MySqlDatabase {
  MySqlDatabase._(this._connections)
      : _available = List<MySqlConnection>.from(_connections);

  final List<MySqlConnection> _connections;
  final List<MySqlConnection> _available;
  final List<Completer<MySqlConnection>> _waiters = [];

  static Future<MySqlDatabase> open({
    required String host,
    required int port,
    required String user,
    required String? password,
    required String database,
  }) async {
    final bootstrap = await MySqlConnection.connect(
      ConnectionSettings(
        host: host,
        port: port,
        user: user,
        password: password,
      ),
    );
    await bootstrap.query(
      'CREATE DATABASE IF NOT EXISTS `$database` '
      'CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci',
    );
    await bootstrap.close();

    final settings = ConnectionSettings(
      host: host,
      port: port,
      user: user,
      password: password,
      db: database,
      characterSet: CharacterSet.UTF8MB4,
    );
    final connections = <MySqlConnection>[];
    try {
      for (var i = 0; i < 4; i++) {
        connections.add(await MySqlConnection.connect(settings));
      }
    } catch (_) {
      for (final connection in connections) {
        await connection.close();
      }
      rethrow;
    }
    return MySqlDatabase._(connections);
  }

  Future<MySqlConnection> _acquire() {
    if (_available.isNotEmpty) {
      return Future.value(_available.removeLast());
    }
    final waiter = Completer<MySqlConnection>();
    _waiters.add(waiter);
    return waiter.future;
  }

  void _release(MySqlConnection connection) {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete(connection);
    } else {
      _available.add(connection);
    }
  }

  Future<T> _withConnection<T>(
    Future<T> Function(MySqlConnection connection) operation,
  ) async {
    final connection = await _acquire();
    try {
      return await operation(connection);
    } finally {
      _release(connection);
    }
  }

  Future<void> close() async {
    for (final connection in _connections) {
      await connection.close();
    }
  }

  Future<void> execute(String sql) async {
    await _withConnection(
      (connection) => connection.query(_normalizeSql(sql)),
    );
  }

  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?> params = const [],
  ]) async {
    final results = await _withConnection(
      (connection) => connection.query(_normalizeSql(sql), params),
    );
    return results.map((row) => _normalizeRow(row.fields)).toList();
  }

  Future<int> rawInsert(
    String sql, [
    List<Object?> params = const [],
  ]) async {
    final results = await _withConnection(
      (connection) => connection.query(_normalizeSql(sql), params),
    );
    return results.insertId ?? 0;
  }

  Future<int> rawUpdate(
    String sql, [
    List<Object?> params = const [],
  ]) async {
    final results = await _withConnection(
      (connection) => connection.query(_normalizeSql(sql), params),
    );
    return results.affectedRows ?? 0;
  }

  Future<int> rawDelete(
    String sql, [
    List<Object?> params = const [],
  ]) async {
    final results = await _withConnection(
      (connection) => connection.query(_normalizeSql(sql), params),
    );
    return results.affectedRows ?? 0;
  }

  Future<bool> columnExists(String table, String column) async {
    final rows = await rawQuery(
      '''
      SELECT COUNT(*) AS cnt
      FROM information_schema.columns
      WHERE table_schema = DATABASE()
        AND table_name = ?
        AND column_name = ?
      ''',
      [table, column],
    );
    final count = rows.first['cnt'];
    return count is num && count > 0;
  }

  String _normalizeSql(String sql) {
    var normalized = sql.trim();
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    normalized = normalized.replaceAll(
      'INTEGER PRIMARY KEY AUTOINCREMENT',
      'INT NOT NULL AUTO_INCREMENT PRIMARY KEY',
    );
    normalized = normalized.replaceAll(
      "TEXT NOT NULL DEFAULT ''",
      "VARCHAR(1024) NOT NULL DEFAULT ''",
    );
    normalized = normalized.replaceAll(
      'TEXT NOT NULL UNIQUE',
      'VARCHAR(255) NOT NULL UNIQUE',
    );
    normalized = normalized.replaceAll(
      'TEXT NOT NULL',
      'VARCHAR(1024) NOT NULL',
    );
    normalized = normalized.replaceAll('TEXT', 'VARCHAR(1024)');
    normalized = normalized.replaceAll('INTEGER', 'INT');
    normalized = normalized.replaceAll(
      "DEFAULT (datetime('now'))",
      'DEFAULT CURRENT_TIMESTAMP',
    );
    normalized = normalized.replaceAll(
      "datetime('now')",
      'CURRENT_TIMESTAMP',
    );
    normalized = normalized.replaceAll(
      'created_at VARCHAR(1024) NOT NULL DEFAULT CURRENT_TIMESTAMP',
      'created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP',
    );
    normalized = normalized.replaceAll(
      ', FOREIGN KEY (college_id) REFERENCES colleges(id)',
      '',
    );
    normalized = normalized.replaceAll(
      ', FOREIGN KEY (document_id) REFERENCES documents(id)',
      '',
    );
    return normalized;
  }

  Map<String, Object?> _normalizeRow(Map<String, dynamic> fields) {
    return fields.map((key, value) {
      Object? normalized = value;
      if (value is BigInt) {
        normalized = value.toInt();
      } else if (value is Blob) {
        normalized = utf8.decode(value.toBytes(), allowMalformed: true);
      }
      return MapEntry(key, normalized);
    });
  }
}
