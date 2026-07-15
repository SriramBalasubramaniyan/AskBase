import 'dart:async';
import 'dart:convert';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/db_schema_model.dart';

const _modelFileName =
    'Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task';
const _modelDownloadUrl =
    'https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct'
    '/resolve/main/Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task';
const _prefKeyModelReady = 'model_ready_fg';

class LlmService {
  LlmService._();
  static final LlmService instance = LlmService._();

  bool _modelLoaded = false;
  InferenceModel? _model;

  Future<bool> isModelDownloaded() async =>
      FlutterGemma.isModelInstalled(_modelFileName);

  Future<void> downloadModel({
    required void Function(int progress) onProgress,
    required void Function() onDone,
    required void Function(String error) onError,
  }) async {
    try {
      await FlutterGemma.installModel(modelType: ModelType.qwen)
          .fromNetwork(_modelDownloadUrl)
          .withProgress((p) => onProgress(p))
          .install();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyModelReady, true);
      onDone();
    } catch (e) {
      onError('Download failed: $e');
    }
  }

  Future<void> loadModel() async {
    if (_modelLoaded) return;
    _model = await FlutterGemma.getActiveModel(
      maxTokens: 1280,
      preferredBackend: PreferredBackend.cpu,
    );
    _modelLoaded = true;
  }

  bool get isModelLoaded => _modelLoaded;

  // ── SQL Generation ────────────────────────────────────────────────────────

  /// [selectedTables] — pre-filtered by SchemaSelector, not the full schema.
  /// [schemaName] — used only in the system prompt header.
  ///
  /// [previousAttemptSql] / [previousError] — when set (on a retry after a
  /// failed attempt), the prompt switches from "write a query" to "fix this
  /// specific query, here's exactly why it failed". [previousError] may
  /// come from the deterministic column/table validator (specific: "table X
  /// has no column Y, actual columns are..."), a join-path hint appended by
  /// QueryService when two tables in the query aren't directly related, or
  /// a real SQLite execution error.
  Future<String> generateSql({
    required String userQuestion,
    required List<TableSchema> selectedTables,
    required String schemaName,
    String? previousAttemptSql,
    String? previousError,
  }) async {
    _assertLoaded();

    final chat = await _model!.createChat(
      systemInstruction: _buildSqlSystemPrompt(selectedTables, schemaName),
    );

    final isRetry = previousAttemptSql != null &&
        previousAttemptSql.isNotEmpty &&
        previousError != null &&
        previousError.isNotEmpty;

    final userText = isRetry
        ? 'Question: $userQuestion\n\n'
            'Your previous SQL failed to run:\n$previousAttemptSql\n\n'
            'Error: $previousError\n\n'
            'Fix the query using the exact information in the error above. '
            'Use ONLY the exact table and column names listed in SCHEMA — '
            'do not invent or guess a name that isn\'t there. If the error '
            'gives you a join path, use it exactly as given. If no valid '
            'query is possible, output CANNOT_ANSWER.\n\nSQL:'
        : 'Question: $userQuestion\n\nSQL:';

    await chat.addQueryChunk(Message.text(text: userText, isUser: true));

    final response = await chat.generateChatResponse();
    final sqlText =
        response is TextResponse ? response.token : response.toString();
    return _extractSql(sqlText);
  }

  // ── Summarization ─────────────────────────────────────────────────────────

  /// [rows] — the (already row-capped) query results, passed as structured
  /// data rather than a pre-serialized string so this method can inspect
  /// their shape.
  Future<String> summarizeResults({
    required String userQuestion,
    required String sqlQuery,
    required List<Map<String, dynamic>> rows,
    required String schemaName,
    required void Function(String token) onToken,
  }) async {
    _assertLoaded();

    final jsonRows = const JsonEncoder.withIndent('  ').convert(rows);

    // Anchor fact: when the result is a single row with a single column —
    // the shape of any COUNT/SUM/AVG/MIN/MAX-style aggregate query,
    // regardless of what the underlying schema calls anything — extract
    // that literal value here in Dart (deterministic, no model parsing
    // involved) and hand it to the model as a fact to restate rather than
    // derive. This is schema-agnostic: it's purely a structural check on
    // row/column shape, not a hardcoded per-table template.
    //
    // Guarded against ID-like columns: if that single value came from a
    // column named "id" or ending in "_id", it's a reference number, not
    // an answer to restate — anchoring it would directly conflict with the
    // "never state bare IDs" rule below by forcing the model to prominently
    // repeat it. In that case there's no anchor; the SQL-generation prompt
    // change below (prefer descriptive columns) is the real fix for why an
    // ID-only result shape happens in the first place.
    String? anchoredFact;
    if (rows.length == 1 && rows.first.length == 1) {
      final singleKey = rows.first.keys.first.toLowerCase();
      final looksLikeId = singleKey == 'id' || singleKey.endsWith('_id');
      if (!looksLikeId) {
        final value = rows.first.values.first;
        anchoredFact = 'The exact answer value is: $value. State this '
            'number or value exactly as given — do not change, estimate, '
            'round, or recalculate it.';
      }
    }
    final factLine = anchoredFact != null ? '\n\n$anchoredFact' : '';

    final chat = await _model!.createChat(
      systemInstruction:
          'Explain these $schemaName query results in 1-3 plain sentences. '
          'If results are empty, say no matching records were found. '
          'Only use the data given — never invent, estimate, or alter any '
          'numbers or values. '
          'Never mention ID numbers, primary keys, or reference numbers '
          '(any field named "id" or ending in "_id") unless the user '
          'explicitly asked for one — refer to records by their name or '
          'another descriptive detail in the data instead. If no '
          'descriptive detail is available, refer to the record generically '
          '(e.g. "the top result") rather than by its ID. '
          'If there are many rows, summarize with a total count and a few '
          'representative examples instead of listing every single one. '
          'No SQL terms.',
    );

    final prompt = 'User asked: $userQuestion\n\n'
        'Results (${rows.length} row(s)): $jsonRows$factLine\n\nSummary:';

    await chat.addQueryChunk(Message.text(text: prompt, isUser: true));

    final buffer = StringBuffer();

    // Guards against a known small-model failure mode: instead of finding
    // a natural stopping point, it can start repeating a short pattern
    // indefinitely (observed in practice: a flood of literal "\n" text).
    // This checks the growing buffer's tail after every token and cuts
    // the stream the moment a short chunk (1-8 chars) has repeated 6+
    // times in a row, before that garbage ever reaches the UI.
    final repetitionGuard = RegExp(r'(.{1,8})\1{5,}$', dotAll: true);
    var stoppedEarly = false;

    // Per flutter_gemma's documented streaming contract, TextResponse.token
    // from generateChatResponseAsync() is already the incremental chunk for
    // that event — append it directly, don't re-slice a delta out of it.
    await for (final response in chat.generateChatResponseAsync()) {
      if (response is TextResponse) {
        final token = response.token;
        if (token.isEmpty) continue;
        buffer.write(token);
        onToken(token);

        if (repetitionGuard.hasMatch(buffer.toString())) {
          stoppedEarly = true;
          break;
        }
      }
      // Other response types (FunctionCallResponse, ThinkingResponse) are
      // not used for this plain-text summarization prompt and are ignored.
    }

    var result = buffer.toString();
    if (stoppedEarly) {
      // Trim the repeated tail so the returned answer ends cleanly rather
      // than mid-repetition.
      final match = repetitionGuard.firstMatch(result);
      if (match != null) {
        result = result.substring(0, match.start).trimRight();
      }
    }
    return result.trim();
  }

  // ── Prompt builders ───────────────────────────────────────────────────────

  String _buildSqlSystemPrompt(
      List<TableSchema> tables, String schemaName) {
    final schemaLines = tables.map((table) {
      final cols = table.fields.map((f) {
        final fk = f.foreignKeyRef != null ? '→${f.foreignKeyRef}' : '';
        return '${f.name}$fk';
      }).join(', ');
      return '${table.tableName}($cols)';
    }).join('\n');

    return 'SQLite expert for $schemaName. Output ONLY a valid SELECT query '
        'or CANNOT_ANSWER or OUT_OF_SCOPE.\n'
        'Rules: SELECT only. Use ONLY the exact table and column names '
        'listed below — never invent, guess, or assume a column exists just '
        'because it seems plausible. If a needed column truly isn\'t listed, '
        'output CANNOT_ANSWER instead of guessing. Use aliases in JOINs. '
        'When the question is about a specific record (e.g. finding a '
        'top/most/least/best result, or a named entity), also SELECT that '
        'table\'s name or other descriptive column if one exists — not '
        'only its ID column. Also SELECT any column used in ORDER BY or an '
        'aggregate function, so the result actually contains the value '
        'being ranked or computed, not just an identifier. '
        'LIMIT 100 if unspecified. Dates are TEXT YYYY-MM-DD.\n\n'
        'SCHEMA:\n$schemaLines';
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _extractSql(String raw) =>
      raw.replaceAll('```sql', '').replaceAll('```', '').trim();

  void _assertLoaded() {
    if (!_modelLoaded || _model == null) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }
  }

  Future<void> dispose() async {
    await _model?.close();
    _model = null;
    _modelLoaded = false;
  }

  String get modelFileName => _modelFileName;
  String get downloadUrl => _modelDownloadUrl;
}
