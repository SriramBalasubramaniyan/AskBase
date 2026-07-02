import 'dart:async';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/db_schema_model.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

// Qwen 2.5 0.5B in MediaPipe .task format
const _modelFileName =
    'Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task';
const _modelDownloadUrl =
    'https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct'
    '/resolve/main/Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task';

const _prefKeyModelReady = 'model_ready_fg';

// ── LLM Service ───────────────────────────────────────────────────────────────

class LlmService {
  LlmService._();

  static final LlmService instance = LlmService._();

  bool _modelLoaded = false;
  InferenceModel? _model;

  // ── Model status ──────────────────────────────────────────────────────────

  Future<bool> isModelDownloaded() async {
    final isInstalled = await FlutterGemma.isModelInstalled(_modelFileName);
    return isInstalled;
  }

  // ── Download ──────────────────────────────────────────────────────────────

  /// Downloads the .task model via flutter_gemma's built-in downloader.
  /// [onProgress] receives 0–100 int.
  Future<void> downloadModel({
    required void Function(int progress) onProgress,
    required void Function() onDone,
    required void Function(String error) onError,
  }) async {
    try {
      await FlutterGemma.installModel(
        modelType: ModelType.qwen,
      )
          .fromNetwork(_modelDownloadUrl)
          .withProgress((progress) => onProgress(progress))
          .install();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyModelReady, true);
      onDone();
    } catch (e) {
      onError('Download failed: $e');
    }
  }

  // ── Load model ────────────────────────────────────────────────────────────

  Future<void> loadModel() async {
    if (_modelLoaded) return;

    _model = await FlutterGemma.getActiveModel(
      maxTokens: 1280,
      preferredBackend:
          PreferredBackend.cpu, // CPU for armeabi-v7a compatibility
    );
    _modelLoaded = true;
  }

  bool get isModelLoaded => _modelLoaded;

  // ── SQL Generation ────────────────────────────────────────────────────────

  /// Generates a SQL SELECT query from a natural language question.
  /// Uses a fresh chat session so SQL context doesn't bleed into summarization.
  Future<String> generateSql({
    required String userQuestion,
    required DatabaseSchema schema,
  }) async {
    _assertLoaded();

    final chat = await _model!.createChat(
      systemInstruction: _buildSqlSystemPrompt(schema),
    );

    await chat.addQueryChunk(Message.text(
      text: 'Question: $userQuestion\n\nSQL:',
      isUser: true,
    ));

    final response = await chat.generateChatResponse();
    final sqlText = response is TextResponse
        ? response.token
        : response.toString();
    return _extractSql(sqlText);
  }

  // ── Summarization ─────────────────────────────────────────────────────────

  /// Summarizes DB rows as natural language, streaming tokens via [onToken].
  Future<String> summarizeResults({
    required String userQuestion,
    required String sqlQuery,
    required String jsonRows,
    required DatabaseSchema schema,
    required void Function(String token) onToken,
  }) async {
    _assertLoaded();

    final chat = await _model!.createChat(
      systemInstruction: _buildSummarySystemPrompt(schema),
    );

    final prompt = [
      'User asked: $userQuestion',
      'Query used: $sqlQuery',
      'Results: $jsonRows',
      'Summary:',
    ].join('\n\n');

    await chat.addQueryChunk(Message.text(text: prompt, isUser: true));

    final buffer = StringBuffer();

    // Stream tokens via generateChatResponseAsync
    await for (final response in chat.generateChatResponseAsync()) {
      if (response is TextResponse) {
        buffer.write(response.token);
        onToken(response.token);
      }
    }

    return buffer.toString().trim();
  }

  // ── Prompt builders ───────────────────────────────────────────────────────

  /*String _buildSqlSystemPrompt(DatabaseSchema schema) {
    return '''You are a SQLite expert. Your ONLY job is to write a single valid SQLite SELECT query.

RULES:
1. Output ONLY the SQL query. No explanation, no markdown, no preamble.
2. Use only tables and columns that exist in the schema below. If unavailable, output: CANNOT_ANSWER
3. Always use table aliases in JOINs.
4. Never use INSERT, UPDATE, DELETE, DROP, ALTER, CREATE, or PRAGMA.
5. Add LIMIT 100 if no limit is specified and the query could return many rows.
6. Date columns are TEXT in YYYY-MM-DD format — use strftime() for date operations.
7. If the question is unrelated to this database, output: OUT_OF_SCOPE

${schema.toFullPrompt()}''';
  }*/

  String _buildSqlSystemPrompt(DatabaseSchema schema) {
    final schemaLines = StringBuffer();
    for (final table in schema.tables) {
      final cols = table.fields.map((f) {
        final fk = f.foreignKeyRef != null ? '→${f.foreignKeyRef}' : '';
        return '${f.name}$fk';
      }).join(', ');
      schemaLines.writeln('${table.tableName}($cols)');
    }

    return '''SQLite expert. Output ONLY a valid SELECT query or CANNOT_ANSWER or OUT_OF_SCOPE.
      Rules: SELECT only. Use aliases in JOINs. LIMIT 100 if unspecified. Dates are TEXT YYYY-MM-DD.
      
      SCHEMA:
      ${schemaLines.toString().trim()}''';
  }

  /*String _buildSummarySystemPrompt(DatabaseSchema schema) {
    return '''You are a helpful assistant for ${schema.databaseName}.
      Explain database results in clear, simple language.
      - Answer only from the data provided. Never add outside information.
      - If results are empty, say no matching records were found.
      - Keep answers concise: 1 to 4 sentences.
      - Format numbers clearly (e.g. "1,250.5 kg").
      - Do not mention SQL, queries, rows, or technical terms.''';
  }*/

  String _buildSummarySystemPrompt(DatabaseSchema schema) {
    return '''Explain these ${schema.databaseName} query results in 1-3 plain sentences. 
    Results are empty, say no matching records were found.
    Only use the data given. No SQL terms.''';
  }
  // ── Helpers ───────────────────────────────────────────────────────────────

  String _extractSql(String raw) {
    return raw.replaceAll('```sql', '').replaceAll('```', '').trim();
  }

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
