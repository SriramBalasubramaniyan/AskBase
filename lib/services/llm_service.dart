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
  /// has no column Y, actual columns are..."), a ready-to-use join skeleton
  /// appended by QueryService when two tables in the query aren't directly
  /// related, or a real SQLite execution error.
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
            'gives you a join structure to use, copy it exactly as given — '
            'do not modify it. If no valid query is possible, output '
            'CANNOT_ANSWER.\n\nSQL:'
        : 'Question: $userQuestion\n\nSQL:';

    await chat.addQueryChunk(Message.text(text: userText, isUser: true));

    final response = await chat.generateChatResponse();
    final sqlText =
        response is TextResponse ? response.token : response.toString();
    return _extractSql(sqlText);
  }

  // ── Summarization ─────────────────────────────────────────────────────────

  /// [rows] — the query results, passed as structured data rather than a
  /// pre-serialized string so this method can inspect their shape.
  ///
  /// NOTE: the single-row/single-column shape (any COUNT/SUM/AVG/MIN/MAX
  /// -style aggregate result) is now intercepted *before* this method is
  /// ever called — see QueryService.ask(). That shape was the single
  /// biggest source of unreliable output: the exact same deterministic SQL
  /// and exact same value would sometimes be echoed correctly and
  /// sometimes not, across otherwise-identical runs. Rather than continue
  /// tuning a prompt the model doesn't reliably follow, QueryService now
  /// constructs that answer directly from the value — guaranteed correct,
  /// at the cost of slightly more mechanical phrasing for that one shape.
  /// This method now only ever runs for genuinely multi-row or
  /// multi-column results, where an LLM's summarization is actually adding
  /// value rather than just being asked to parrot a single number.
  Future<String> summarizeResults({
    required String userQuestion,
    required String sqlQuery,
    required List<Map<String, dynamic>> rows,
    required String schemaName,
    required void Function(String token) onToken,
  }) async {
    _assertLoaded();

    // Deterministic display cap: only ever serialize the first 5 rows into
    // the prompt for multi-row results, with the true total stated as a
    // separate fact. A prose instruction asking the model to "list at most
    // 5" was tried and ignored in practice (an 18-row result was listed in
    // full) — capping what it's actually given can't be ignored the way an
    // instruction can, and it also keeps the prompt short for large result
    // sets, which helps against truncation/repetition risk too.
    const displayCap = 5;
    final totalCount = rows.length;
    final wasTruncated = totalCount > displayCap;
    final displayRows = wasTruncated ? rows.sublist(0, displayCap) : rows;

    final jsonRows = const JsonEncoder.withIndent('  ').convert(displayRows);

    final factLine = wasTruncated
        ? '\n\nThere are $totalCount matching records in total. Only the '
            'first $displayCap are included below — state the total count '
            'once, then list only these $displayCap as bullets. Do not '
            'claim any other total.'
        : '';

    final chat = await _model!.createChat(
      systemInstruction:
          'Explain these $schemaName query results in a clear, '
          'well-formatted answer, based only on the actual values in the '
          'data. Never describe the data\'s structure or position (e.g. '
          '"in the first row", "in the first column", "listed above") — '
          'always state the real values themselves. '
          'If results are empty, say no matching records were found. Never '
          'invent, estimate, or alter any numbers or values. '
          'Never mention ID numbers, primary keys, or reference numbers '
          '(any field named "id" or ending in "_id") unless the user '
          'explicitly asked for one — refer to records by their name or '
          'another descriptive detail in the data instead. If no '
          'descriptive detail is available, refer to the record generically '
          '(e.g. "the top result") rather than by its ID. '
          'If there is only one result, answer in 1-3 plain sentences. '
          'If there are multiple results, format the answer as a markdown '
          'bullet list. Keep each bullet to just the essential value(s) for '
          'that record — do not repeat the question\'s own wording in '
          'every bullet (e.g. if asked "which farmers attended training", '
          'list bare names, not "X attended training" repeated for each '
          'one). No SQL terms.',
    );

    final prompt = 'User asked: $userQuestion\n\n'
        'Results ($totalCount row(s) total'
        '${wasTruncated ? ", showing first $displayCap" : ""}): '
        '$jsonRows$factLine\n\nSummary:';

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
        'output CANNOT_ANSWER instead of guessing. '
        'If a column\'s description lists specific allowed values in '
        'parentheses, any comparison against that column must use one of '
        'those exact values verbatim — never a similar-sounding or '
        'invented value. '
        'For questions using "most", "least", "highest", "lowest", "top", '
        'or "best", ORDER BY (or use MAX()/MIN() on) the column that '
        'actually measures that quantity (an amount, quantity, price, or '
        'count column) — never an ID column. Sorting or taking MAX/MIN of '
        'an ID column does not mean "the most" or "the least" of anything '
        'real. '
        'Only JOIN a table if you need a column from it. If you do JOIN a '
        'table, SELECT its name or other descriptive column — never join a '
        'table and then use nothing from it. '
        'For ANY question — list/show-style or otherwise, with or without '
        'a JOIN — SELECT several of the relevant table\'s substantive '
        'columns (amounts, dates, types, statuses, categories, names, '
        'descriptions), not just an identifier; a result containing only '
        'ID/reference-number columns is never useful. Also SELECT any '
        'column used in ORDER BY or an aggregate function, so the result '
        'actually contains the value being ranked or computed. '
        'For questions asking "which"/"who" about a set of entities (not '
        'asking to count individual events), use SELECT DISTINCT so each '
        'entity appears once even if it has multiple related records. '
        'If the question uses words like "each", "every", "per", or asks '
        'for a breakdown/list across entities (e.g. "how many X does each '
        'Y have"), GROUP BY that entity and return one row per entity — '
        'not a single overall total. '
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
