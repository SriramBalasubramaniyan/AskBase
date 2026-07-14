import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/db_schema_model.dart';

class DbService {
  DbService._();
  static final DbService instance = DbService._();

  Database? _db;
  bool _initialized = false;

  // ── Initialisation ──────────────────────────────────────────────────────────

  /// Copies the bundled .db from assets into the app's documents directory
  /// and opens it. The copy is refreshed — not just made once ever — when:
  ///   - no copy exists yet (first run),
  ///   - the bundled asset's byte size differs from what was last copied
  ///     (a cheap, dependency-free way to detect "the seed data changed"),
  ///   - or this is a debug build, so active development against a
  ///     changing agri.db never silently keeps serving stale data on a
  ///     device that had the app installed before the latest asset was
  ///     bundled.
  ///
  /// Why this matters: the previous "only copy if the file doesn't already
  /// exist" logic meant any device that had the app installed before a
  /// seed-data update would run against the old copy forever — the exact
  /// same query could return different results from the live app vs. a
  /// fresh read of the current asset, with no error or indication why.
  Future<void> init(DatabaseSchema schema) async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'askbase', schema.dbFileName);

    // Ensure directory exists
    await Directory(p.dirname(dbPath)).create(recursive: true);

    final assetData = await rootBundle.load(schema.assetPath);
    final assetSize = assetData.lengthInBytes;

    final prefs = await SharedPreferences.getInstance();
    final sizeKey = 'askbase_db_copied_size_${schema.dbFileName}';
    final previouslyCopiedSize = prefs.getInt(sizeKey);

    final dbFile = File(dbPath);
    final needsCopy = kDebugMode ||
        !dbFile.existsSync() ||
        previouslyCopiedSize != assetSize;

    if (needsCopy) {
      await dbFile.writeAsBytes(
        assetData.buffer
            .asUint8List(assetData.offsetInBytes, assetData.lengthInBytes),
        flush: true,
      );
      await prefs.setInt(sizeKey, assetSize);
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
      final caseInsensitive = _makeTextComparisonsCaseInsensitive(cleaned);
      return await _db!.rawQuery(caseInsensitive);
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

  /// Rewrites `column = 'literal'`, `column != 'literal'` and
  /// `column <> 'literal'` comparisons to add `COLLATE NOCASE`.
  ///
  /// Why: the SLM generates plausible-looking values for status/enum-style
  /// text columns (e.g. `status = 'active'`) but has no way to know the
  /// exact casing actually stored in the database (e.g. `'Active'`).
  /// SQLite string comparison is case-sensitive by default, so a
  /// perfectly valid, semantically-correct query silently returns zero
  /// rows on a casing mismatch. Rather than relying on the model to guess
  /// casing correctly (prompt-engineering-only fixes are unreliable for a
  /// 0.5B model), this deterministically neutralizes the casing sensitivity
  /// at the SQL layer for every generated query.
  ///
  /// Only touches comparisons against single-quoted string literals —
  /// numeric/boolean comparisons and columns compared to other columns are
  /// left untouched. Comparisons that already specify a COLLATE clause are
  /// skipped so this is idempotent and won't double up.
  ///
  /// Verified directly against SQLite: 'active' COLLATE NOCASE correctly
  /// matches a stored 'Active' value where a plain '=' does not.
  ///
  /// Known limitation: does not currently rewrite `IN ('a', 'b')` lists or
  /// `LIKE` patterns — SQLite's `LIKE` is already case-insensitive for
  /// ASCII by default, and `IN` lists were not part of the observed bug.
  String _makeTextComparisonsCaseInsensitive(String sql) {
    // Matches: <column> (= | != | <>) '<sqlite-escaped string literal>'
    // A SQLite string literal escapes an embedded quote by doubling it
    // (e.g. 'John''s Farm'), which is what (?:[^']|'')* captures.
    final pattern = RegExp(
      r"([A-Za-z_][\w.]*)\s*(=|!=|<>)\s*('(?:[^']|'')*')(?!\s*COLLATE)",
      caseSensitive: false,
    );
    return sql.replaceAllMapped(pattern, (m) {
      return '${m.group(1)} ${m.group(2)} ${m.group(3)} COLLATE NOCASE';
    });
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
