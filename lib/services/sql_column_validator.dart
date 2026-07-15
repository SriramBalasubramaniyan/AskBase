import '../models/db_schema_model.dart';

/// Deterministic, non-executing check that every table/column referenced
/// in a generated SQL query actually exists in [schema]. This runs before
/// the query ever touches the database — it's free (no I/O), and unlike a
/// raw SQLite error, it can point at exactly what's wrong and what the
/// real options were. That's what lets the self-correction retry loop in
/// QueryService actually fix a hallucinated column instead of re-rolling
/// the same mistake against a vague error string.
///
/// This is intentionally NOT a full SQL parser — it targets the concrete
/// hallucination patterns observed in practice:
///   1. Qualified references: `alias.column` where `alias` resolves to a
///      real table (via FROM/JOIN) but `column` isn't one of its fields
///      (e.g. `insurance.crop_id`, which doesn't exist — the real path is
///      insurance → sowing → crop).
///   2. Unqualified column references — both in the WHERE clause and the
///      SELECT list — for single-table queries (e.g. `SELECT ...,
///      payment_date FROM sale`, which has no `payment_date`, only
///      `sale_date`; or `WHERE status = 'PENDING'` on `sale`, which only
///      has `payment_status`).
/// Anything it can't confidently parse (subqueries, unusual syntax) is
/// left alone — it falls through to the existing execution-time error
/// handling, so this can only catch problems earlier, never introduce
/// new false failures on SQL it doesn't understand.
class SqlColumnValidator {
  SqlColumnValidator._();

  // The negative lookahead before the alias group is load-bearing: without
  // it, "FROM crop JOIN insurance" would have its alias group greedily
  // swallow the keyword "JOIN" as if it were crop's alias, which then
  // consumes the string past that point and causes the second table
  // ("JOIN insurance") to never be matched at all — silently reducing a
  // multi-table query down to a single detected table. Verified against
  // real multi-join queries before shipping.
  static final RegExp _fromJoinPattern = RegExp(
    r'\b(?:FROM|JOIN)\s+([A-Za-z_]\w*)'
    r'(?:\s+(?:AS\s+)?(?!(?:WHERE|ON|GROUP|ORDER|LIMIT|JOIN|LEFT|INNER|RIGHT|FULL|OUTER|AND|OR|UNION|HAVING)\b)([A-Za-z_]\w*))?',
    caseSensitive: false,
  );

  static final RegExp _qualifiedRefPattern =
      RegExp(r'\b([A-Za-z_]\w*)\.([A-Za-z_]\w*)\b');

  static final RegExp _qualifiedRefStripPattern =
      RegExp(r'\b[A-Za-z_]\w*\.[A-Za-z_]\w*\b');

  static final RegExp _whereComparisonPattern = RegExp(
    r'\b([A-Za-z_]\w*)\s*(?:=|!=|<>|<=|>=|<|>|LIKE)\s',
    caseSensitive: false,
  );

  static final RegExp _bareIdentifierPattern = RegExp(r'\b[A-Za-z_]\w*\b');

  static final RegExp _asKeywordPattern =
      RegExp(r'\s+AS\s+', caseSensitive: false);

  /// Words that can legally appear right after a table name in a FROM/JOIN
  /// clause without being an alias — so "FROM farmer WHERE ..." doesn't
  /// get misread as table "farmer" aliased to "where".
  static const _reservedWords = {
    'where', 'on', 'group', 'order', 'limit', 'join', 'left', 'inner',
    'right', 'full', 'outer', 'and', 'or', 'union', 'having', 'as',
  };

  /// SQL syntax words that can appear as bare tokens without being a
  /// column name, so they're never flagged as a missing column.
  static const _sqlKeywords = {
    'and', 'or', 'not', 'select', 'from', 'where', 'group', 'order', 'by',
    'limit', 'having', 'distinct', 'as', 'case', 'when', 'then', 'else',
    'end', 'null', 'is', 'in', 'between', 'exists', 'all', 'count', 'sum',
    'avg', 'min', 'max', 'collate', 'nocase',
  };

  static final RegExp _numericPattern = RegExp(r'^\d+$');

  /// Returns a specific, actionable correction message if [sql] references
  /// a table or column that doesn't exist in [schema], or null if this
  /// check didn't find a problem (which does not guarantee the SQL is
  /// otherwise valid — only that this particular check passed).
  static String? check(String sql, DatabaseSchema schema) {
    final aliasMap = _extractTableAliases(sql, schema);
    if (aliasMap.isEmpty) return null; // couldn't parse FROM/JOIN confidently

    // Unknown tables referenced in FROM/JOIN.
    for (final entry in aliasMap.entries) {
      if (entry.value == null) {
        final available = schema.tables.map((t) => t.tableName).join(', ');
        return 'Table "${entry.key}" does not exist. Available tables: '
            '$available.';
      }
    }

    // Qualified alias.column references — checked across the whole query
    // (SELECT list, JOIN...ON, WHERE, ORDER BY, etc).
    for (final m in _qualifiedRefPattern.allMatches(sql)) {
      final alias = m.group(1)!;
      final col = m.group(2)!;
      if (!aliasMap.containsKey(alias)) continue; // not a known alias, skip
      final table = aliasMap[alias];
      if (table == null) continue; // already reported above
      final err = _checkIdentifiers([col], table);
      if (err != null) return err;
    }

    // Unqualified references — only for single-table queries (no JOIN).
    // With a JOIN present, an unqualified column is ambiguous between
    // tables, so it's left to execution-time error handling instead of
    // risking a false positive here.
    final involvedTables = aliasMap.values.whereType<TableSchema>().toList();
    final distinctTableNames =
        involvedTables.map((t) => t.tableName).toSet();

    if (distinctTableNames.length == 1) {
      final table = involvedTables.first;
      final upperSql = sql.toUpperCase();

      // SELECT-list check.
      final selectStart = upperSql.indexOf('SELECT');
      final fromStart = upperSql.indexOf('FROM');
      if (selectStart != -1 && fromStart != -1 && fromStart > selectStart) {
        var selectClause =
            sql.substring(selectStart + 'SELECT'.length, fromStart).trim();
        if (selectClause.toUpperCase().startsWith('DISTINCT')) {
          selectClause = selectClause.substring('DISTINCT'.length).trim();
        }
        final candidates = _extractBareIdentifiers(selectClause);
        final err = _checkIdentifiers(candidates, table);
        if (err != null) return err;
      }

      // WHERE-clause check.
      final whereStart = upperSql.indexOf('WHERE');
      if (whereStart != -1) {
        final whereClause = sql.substring(whereStart);
        final candidates = _whereComparisonPattern
            .allMatches(whereClause)
            .map((m) => m.group(1)!)
            .where((c) => !c.contains('.'));
        final err = _checkIdentifiers(candidates, table);
        if (err != null) return err;
      }
    }

    return null;
  }

  /// Returns the distinct real tables referenced via FROM/JOIN in [sql]
  /// (tables that don't resolve to anything real are omitted). Exposed so
  /// other components — e.g. join-path hinting on a validation failure —
  /// can reuse this parsing without duplicating it.
  static List<TableSchema> referencedTables(String sql, DatabaseSchema schema) {
    final aliasMap = _extractTableAliases(sql, schema);
    final seen = <String>{};
    final result = <TableSchema>[];
    for (final table in aliasMap.values) {
      if (table == null) continue;
      if (seen.add(table.tableName)) result.add(table);
    }
    return result;
  }

  // ── Internals ────────────────────────────────────────────────────────────

  static String? _checkIdentifiers(
    Iterable<String> candidates,
    TableSchema table,
  ) {
    final fieldNames = table.fields.map((f) => f.name).toSet();
    for (final candidate in candidates) {
      final lower = candidate.toLowerCase();
      if (_sqlKeywords.contains(lower)) continue;
      if (_numericPattern.hasMatch(candidate)) continue;
      if (!fieldNames.contains(candidate)) {
        return 'Table "${table.tableName}" has no column "$candidate". Its '
            'actual columns are: ${fieldNames.join(", ")}.';
      }
    }
    return null;
  }

  /// Extracts candidate bare (unqualified) identifier names from a
  /// comma-separated clause fragment (typically a SELECT list), skipping:
  ///  - the alias half of "expr AS alias" items,
  ///  - `*` and `table.*`,
  ///  - anything that's part of an `alias.column` qualified reference
  ///    (those are checked separately, so stripped here first to avoid
  ///    double-checking or misreading the alias itself as a column).
  static List<String> _extractBareIdentifiers(String clause) {
    final out = <String>[];
    for (final item in _splitTopLevel(clause, ',')) {
      var expr = item.trim();
      final asMatch = _asKeywordPattern.firstMatch(expr);
      if (asMatch != null) {
        expr = expr.substring(0, asMatch.start);
      }
      if (expr == '*' || expr.endsWith('.*')) continue;
      final withoutQualified = expr.replaceAll(_qualifiedRefStripPattern, '');
      for (final m in _bareIdentifierPattern.allMatches(withoutQualified)) {
        out.add(m.group(0)!);
      }
    }
    return out;
  }

  /// Splits [s] on top-level occurrences of [sep], respecting parenthesis
  /// nesting (so `COUNT(a, b)` isn't split into two items).
  static List<String> _splitTopLevel(String s, String sep) {
    final parts = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '(') {
        depth++;
      } else if (c == ')') {
        depth--;
      } else if (c == sep && depth == 0) {
        parts.add(s.substring(start, i));
        start = i + 1;
      }
    }
    parts.add(s.substring(start));
    return parts;
  }

  /// Maps every alias (and each table's own bare name) used in FROM/JOIN
  /// clauses to its resolved [TableSchema], or to null if it doesn't
  /// match any real table in [schema].
  static Map<String, TableSchema?> _extractTableAliases(
    String sql,
    DatabaseSchema schema,
  ) {
    final map = <String, TableSchema?>{};
    for (final m in _fromJoinPattern.allMatches(sql)) {
      final tableName = m.group(1)!;
      final rawAlias = m.group(2);
      final table = schema.tableByName(tableName);

      map[tableName] = table;

      if (rawAlias != null &&
          !_reservedWords.contains(rawAlias.toLowerCase())) {
        map[rawAlias] = table;
      }
    }
    return map;
  }
}
