import '../models/db_schema_model.dart';

/// Selects the most relevant tables from a large schema based on the
/// user's natural language question. Uses keyword scoring against table
/// names, table descriptions, field names, and field descriptions.
///
/// Keeps the LLM prompt well under the 1280-token limit regardless of
/// how many tables the full schema contains.
class SchemaSelector {
  SchemaSelector._();
  static final SchemaSelector instance = SchemaSelector._();

  static const int _maxDirectTables = 5;
  static const int _minScore = 1;

  /// Returns a filtered list of [TableSchema] relevant to [question].
  /// Always includes FK dependency tables so JOINs remain valid.
  List<TableSchema> select(String question, DatabaseSchema schema) {
    final tokens = _tokenize(question);
    if (tokens.isEmpty) return schema.tables.take(_maxDirectTables).toList();

    final scores = <TableSchema, int>{};
    for (final table in schema.tables) {
      final score = _scoreTable(table, tokens);
      if (score >= _minScore) scores[table] = score;
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final selected = sorted.take(_maxDirectTables).map((e) => e.key).toList();

    if (selected.isEmpty) return schema.tables.take(4).toList();

    return _withFkDependencies(selected, schema);
  }

  // ── Scoring ───────────────────────────────────────────────────────────────

  int _scoreTable(TableSchema table, List<String> tokens) {
    int score = 0;
    for (final token in tokens) {
      if (_containsWord(table.tableName, token)) score += 10;
      if (table.tableDescription.toLowerCase().contains(token)) score += 3;
      for (final field in table.fields) {
        if (_containsWord(field.name, token)) score += 5;
        if (field.description.toLowerCase().contains(token)) score += 2;
      }
    }
    return score;
  }

  // ── FK dependency resolution ──────────────────────────────────────────────

  List<TableSchema> _withFkDependencies(
    List<TableSchema> selected,
    DatabaseSchema schema,
  ) {
    final included = <String, TableSchema>{
      for (final t in selected) t.tableName: t,
    };
    for (final table in List.from(selected)) {
      for (final field in table.fields) {
        if (field.foreignKeyRef == null) continue;
        final refTableName = field.foreignKeyRef!.split('.').first;
        if (included.containsKey(refTableName)) continue;
        final dep = schema.tableByName(refTableName);
        if (dep != null) included[refTableName] = dep;
      }
    }
    return included.values.toList();
  }

  // ── Tokenization ──────────────────────────────────────────────────────────

  List<String> _tokenize(String question) {
    const stopWords = {
      'a','an','the','is','are','was','were','be','been','have','has','had',
      'do','does','did','will','would','can','could','should','may','might',
      'shall','of','in','on','at','to','for','with','by','from','as','into',
      'that','this','it','its','and','or','but','not','no','all','any','each',
      'how','what','when','where','who','which','why','me','my','our','your',
      'their','give','show','list','get','find','tell','many','much','most',
      'total','count','number','per','between','than','more',
    };
    return question
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9\s_]"), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3 && !stopWords.contains(t))
        .toList();
  }

  bool _containsWord(String text, String token) {
    final normalized = text.toLowerCase().replaceAll('_', ' ');
    return normalized == token ||
        normalized.startsWith('$token ') ||
        normalized.endsWith(' $token') ||
        normalized.contains(' $token ') ||
        text.toLowerCase().contains(token);
  }

  // ── Prompt builder ────────────────────────────────────────────────────────

  /// Compact prompt-ready schema string for selected tables only.
  String buildCompactSchemaPrompt(List<TableSchema> tables) {
    final sb = StringBuffer();
    for (final table in tables) {
      final cols = table.fields.map((f) {
        final fk = f.foreignKeyRef != null ? '→${f.foreignKeyRef}' : '';
        return '${f.name}$fk';
      }).join(', ');
      sb.writeln('${table.tableName}($cols)');
    }
    return sb.toString().trim();
  }

  // ── Debug info (call only in debug mode) ──────────────────────────────────

  String debugSelectionInfo(String question, DatabaseSchema schema) {
    final tokens = _tokenize(question);
    final scores = <String, int>{};
    for (final table in schema.tables) {
      final score = _scoreTable(table, tokens);
      if (score >= _minScore) scores[table.tableName] = score;
    }
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final selected = select(question, schema);
    return 'Tokens: $tokens\n'
        'Scores: ${sorted.take(8).map((e) => "${e.key}:${e.value}").join(", ")}\n'
        'Selected: ${selected.map((t) => t.tableName).join(", ")}';
  }
}
