import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/db_schema_model.dart';

class DbService {
  DbService._();
  static final DbService instance = DbService._();

  Database? _db;
  bool _initialized = false;

  // ── Initialisation ──────────────────────────────────────────────────────────

  /// Copies the bundled .db from assets into the app's documents directory
  /// (only on first run or if the file doesn't exist) and opens it read-only.
  Future<void> init(DatabaseSchema schema) async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'askbase', schema.dbFileName);

    // Ensure directory exists
    await Directory(p.dirname(dbPath)).create(recursive: true);

    // Copy from assets if not already present
    if (!File(dbPath).existsSync()) {
      final bytes = await rootBundle.load(schema.assetPath);
      await File(dbPath).writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
    }

    _db = await openDatabase(
      dbPath,
      version: 1,
    );

    _initialized = true;
  }

  void _assertReady() {
    if (_db == null || !_initialized) {
      throw StateError('DbService not initialized. Call init() first.');
    }
  }

  // ── Query execution ─────────────────────────────────────────────────────────

  /// Executes a raw SELECT query and returns rows as a list of maps.
  /// Throws [DbQueryException] on SQL errors.
  Future<List<Map<String, dynamic>>> runSelect(String sql) async {
    _assertReady();
    try {
      final cleaned = _sanitize(sql);
      return await _db!.rawQuery(cleaned);
    } on DatabaseException catch (e) {
      throw DbQueryException(e.toString(), sql);
    }
  }

  /// Validates that the SQL is safe (SELECT only) before running.
  /// Returns an error string if unsafe, null if safe.
  String? validateSql(String sql) {
    final q = sql.trim().toLowerCase();

    if (!q.startsWith('select')) {
      return 'Only SELECT queries are allowed.';
    }

    const blocked = [
      'drop', 'delete', 'update', 'insert',
      'alter', 'create', 'replace', 'truncate',
      'attach', 'detach', 'pragma',
    ];

    for (final kw in blocked) {
      // Use word boundary check to avoid false positives (e.g. "selected")
      final pattern = RegExp(r'\b' + kw + r'\b');
      if (pattern.hasMatch(q)) {
        return 'Query contains disallowed keyword: $kw';
      }
    }

    return null; // safe
  }

  /// Returns table names present in the opened database.
  Future<List<String>> getTableNames() async {
    _assertReady();
    final rows = await _db!.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );
    return rows.map((r) => r['name'] as String).toList();
  }

  // ── Internals ───────────────────────────────────────────────────────────────

  /// Strips markdown code fences and trims the SQL string.
  String _sanitize(String sql) {
    return sql
        .replaceAll('```sql', '')
        .replaceAll('```', '')
        .trim();
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
    _initialized = false;
  }
}

// ── Exceptions ────────────────────────────────────────────────────────────────

class DbQueryException implements Exception {
  final String message;
  final String sql;

  const DbQueryException(this.message, this.sql);

  @override
  String toString() => 'DbQueryException: $message\nSQL: $sql';
}
