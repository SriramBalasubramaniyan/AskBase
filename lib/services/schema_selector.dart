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

  /// A table must clear this score to be selected. Raised from 1 → 4 so a
  /// single weak "word appears somewhere in this table's description" hit
  /// (worth 2-3 points) is no longer enough on its own to pull in an
  /// unrelated table — it now needs either a real name match, or more than
  /// one corroborating signal.
  static const int _minScore = 4;

  /// If a token matches this fraction of the whole schema's tables, it's
  /// treated as too generic to be a strong table-selection signal (e.g.
  /// "name", "date", "id" — present in most tables) and its match weight
  /// is dampened. This is schema-agnostic (no hardcoded word list), so it
  /// keeps working if you swap in a completely different domain schema.
  static const double _genericTokenThreshold = 0.3;

  // Base weights, used when a token is NOT generic for this schema.
  static const int _wTableName = 10;
  static const int _wFieldName = 5;
  static const int _wTableDesc = 3;
  static const int _wFieldDesc = 2;

  // Dampened weights, used when a token matches >30% of tables.
  static const int _wTableNameGeneric = 3;
  static const int _wFieldNameGeneric = 1;
  static const int _wTableDescGeneric = 1;
  static const int _wFieldDescGeneric = 0;

  /// Returns a filtered list of [TableSchema] relevant to [question].
  /// Always includes FK dependency tables so JOINs remain valid.
  List<TableSchema> select(String question, DatabaseSchema schema) {
    final tokens = _tokenize(question);
    if (tokens.isEmpty) return schema.tables.take(_maxDirectTables).toList();

    final scores = _scoreAllTables(tokens, schema);

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final selected = sorted.take(_maxDirectTables).map((e) => e.key).toList();

    if (selected.isEmpty) return schema.tables.take(4).toList();

    return _withFkDependencies(selected, schema);
  }

  // ── Scoring ───────────────────────────────────────────────────────────────

  Map<TableSchema, int> _scoreAllTables(
      List<String> tokens, DatabaseSchema schema) {
    final tableCount = schema.tables.length;

    // Document frequency: how many tables each token matches at all,
    // computed fresh per-question so this adapts to whatever schema is
    // loaded (no hardcoded stopword list to maintain).
    final tokenDocFreq = <String, int>{};
    for (final token in tokens) {
      tokenDocFreq[token] =
          schema.tables.where((t) => _matchesAnywhere(t, token)).length;
    }

    final scores = <TableSchema, int>{};
    for (final table in schema.tables) {
      final score = _scoreTable(table, tokens, tokenDocFreq, tableCount);
      if (score >= _minScore) scores[table] = score;
    }
    return scores;
  }

  int _scoreTable(
    TableSchema table,
    List<String> tokens,
    Map<String, int> tokenDocFreq,
    int tableCount,
  ) {
    int score = 0;
    for (final token in tokens) {
      final freq = tokenDocFreq[token] ?? 0;
      final isGeneric = tableCount > 0 && freq > tableCount * _genericTokenThreshold;

      final wTableName = isGeneric ? _wTableNameGeneric : _wTableName;
      final wFieldName = isGeneric ? _wFieldNameGeneric : _wFieldName;
      final wTableDesc = isGeneric ? _wTableDescGeneric : _wTableDesc;
      final wFieldDesc = isGeneric ? _wFieldDescGeneric : _wFieldDesc;

      if (_matches(table.tableName, token)) score += wTableName;
      if (_matches(table.tableDescription, token)) score += wTableDesc;
      for (final field in table.fields) {
        if (_matches(field.name, token)) score += wFieldName;
        if (_matches(field.description, token)) score += wFieldDesc;
      }
    }
    return score;
  }

  /// Whether [token] matches this table at all (name, description, or any
  /// field name/description) — used only to compute document frequency,
  /// not scored directly.
  bool _matchesAnywhere(TableSchema table, String token) {
    if (_matches(table.tableName, token)) return true;
    if (_matches(table.tableDescription, token)) return true;
    for (final field in table.fields) {
      if (_matches(field.name, token)) return true;
      if (_matches(field.description, token)) return true;
    }
    return false;
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

  // ── Matching ─────────────────────────────────────────────────────────────

  /// Whole-word match of [token] (or its basic singular/plural variant)
  /// against [text], with underscores treated as word separators
  /// (e.g. "sanctioned_amount" → "sanctioned amount").
  ///
  /// This replaces the old implementation's raw `.contains(token)` fallback,
  /// which matched a token anywhere inside a larger word or sentence (e.g.
  /// the question word "farmers" matching the *substring* "farmers" buried
  /// in an unrelated table's description) — the main source of the noisy,
  /// oversized table selections seen in practice.
  bool _matches(String text, String token) {
    final normalized = text.toLowerCase().replaceAll('_', ' ');
    for (final form in _wordForms(token)) {
      final pattern = RegExp(r'\b' + RegExp.escape(form) + r'\b');
      if (pattern.hasMatch(normalized)) return true;
    }
    return false;
  }

  /// Very small singular/plural stemmer so "farmers" still matches a
  /// "farmer" table/field, "loans" still matches "loan", etc., without
  /// falling back to substring matching.
  Set<String> _wordForms(String token) {
    final forms = <String>{token};
    if (token.endsWith('ies') && token.length > 4) {
      forms.add('${token.substring(0, token.length - 3)}y');
    } else if (token.endsWith('es') && token.length > 3) {
      forms.add(token.substring(0, token.length - 2));
    } else if (token.endsWith('s') &&
        !token.endsWith('ss') &&
        token.length > 3) {
      forms.add(token.substring(0, token.length - 1));
    }
    return forms;
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
    final scores = _scoreAllTables(tokens, schema);
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final selected = select(question, schema);
    return 'Tokens: $tokens\n'
        'Scores: ${sorted.take(8).map((e) => "${e.key.tableName}:${e.value}").join(", ")}\n'
        'Selected: ${selected.map((t) => t.tableName).join(", ")}';
  }
}
