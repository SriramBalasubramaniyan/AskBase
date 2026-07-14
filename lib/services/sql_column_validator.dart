import '../models/db_schema_model.dart';

/// Deterministic, non-executing check that every table/column referenced
/// in a generated SQL query actually exists in [schema]. This runs before
/// the query ever touches the database — it's free (no I/O), and unlike a
/// raw SQLite error, it can point at exactly what's wrong and what the
/// real options were. That's what lets the self-correction retry loop in
/// QueryService actually fix a hallucinated column instead of re-rolling
/// the same mistake against a vague error string.
///
/// This is intentionally NOT a full SQL parser — it targets the two
/// concrete hallucination patterns observed in practice:
///   1. Qualified references: `alias.column` where `alias` resolves to a
///      real table (via FROM/JOIN) but `column` isn't one of its fields
///      (e.g. `insurance.crop_id`, which doesn't exist — the real path is
///      insurance → sowing → crop).
///   2. Unqualified WHERE-clause comparisons in single-table queries (no
///      JOIN), where the compared column isn't a field of that table
///      (e.g. `WHERE status = 'PENDING'` on `sale`, which only has
///      `payment_status`, not `status`).
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

  static final RegExp _whereComparisonPattern = RegExp(
    r'\b([A-Za-z_]\w*)\s*(?:=|!=|<>|<=|>=|<|>|LIKE)\s',
    caseSensitive: false,
  );

  /// Words that can legally appear right after a table name in a FROM/JOIN
  /// clause without being an alias — so "FROM farmer WHERE ..." doesn't
  /// get misread as table "farmer" aliased to "where".
  static const _reservedWords = {
    'where', 'on', 'group', 'order', 'limit', 'join', 'left', 'inner',
    'right', 'full', 'outer', 'and', 'or', 'union', 'having', 'as',
  };

  /// SQL syntax words that can precede a comparison operator without being
  /// a column name, so they're never flagged as a missing column.
  static const _sqlKeywords = {
    'and', 'or', 'not', 'select', 'from', 'where', 'group', 'order', 'by',
    'limit', 'having', 'distinct', 'as', 'case', 'when', 'then', 'else',
    'end', 'null', 'is', 'in', 'between', 'exists', 'all', 'count', 'sum',
    'avg', 'min', 'max', 'collate', 'nocase',
  };

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
      final fieldNames = table.fields.map((f) => f.name).toSet();
      if (!fieldNames.contains(col)) {
        return 'Table "${table.tableName}" has no column "$col". Its '
            'actual columns are: ${fieldNames.join(", ")}.';
      }
    }

    // Unqualified WHERE-clause comparisons — only for single-table queries
    // (no JOIN). With a JOIN present, an unqualified column is ambiguous
    // between tables, so it's left to execution-time error handling
    // instead of risking a false positive here.
    final involvedTables =
        aliasMap.values.whereType<TableSchema>().toList();
    final distinctTableNames =
        involvedTables.map((t) => t.tableName).toSet();

    if (distinctTableNames.length == 1) {
      final table = involvedTables.first;
      final fieldNames = table.fields.map((f) => f.name).toSet();
      final upperSql = sql.toUpperCase();
      final whereStart = upperSql.indexOf('WHERE');

      if (whereStart != -1) {
        final whereClause = sql.substring(whereStart);
        for (final m in _whereComparisonPattern.allMatches(whereClause)) {
          final candidate = m.group(1)!;
          final lower = candidate.toLowerCase();
          if (_sqlKeywords.contains(lower)) continue;
          if (RegExp(r'^\d+$').hasMatch(candidate)) continue;
          if (!fieldNames.contains(candidate)) {
            return 'Table "${table.tableName}" has no column "$candidate". '
                'Its actual columns are: ${fieldNames.join(", ")}.';
          }
        }
      }
    }

    return null;
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
