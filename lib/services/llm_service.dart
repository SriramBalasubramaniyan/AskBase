import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' as dio_pkg;
import 'package:nobodywho/nobodywho.dart' as nw;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/db_schema_model.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _modelFileName = 'Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf';
const _modelDownloadUrl =
    'https://huggingface.co/bartowski/Qwen2.5-Coder-1.5B-Instruct-GGUF'
    '/resolve/main/Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf';
const _prefKeyModelReady = 'model_ready';

// ── LLM Service ───────────────────────────────────────────────────────────────

class LlmService {
  LlmService._();
  static final LlmService instance = LlmService._();

  bool _modelLoaded = false;
  String? _modelPath;

  // ── Model path ────────────────────────────────────────────────────────────

  Future<String> _getModelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'askbase', 'models', _modelFileName);
  }

  Future<bool> isModelDownloaded() async {
    final path = await _getModelPath();
    return File(path).existsSync();
  }

  // ── Download ──────────────────────────────────────────────────────────────

  Future<void> downloadModel({
    required void Function(int received, int total) onProgress,
    required void Function() onDone,
    required void Function(String error) onError,
    dio_pkg.CancelToken? cancelToken,
  }) async {
    final path = await _getModelPath();
    await Directory(p.dirname(path)).create(recursive: true);

    final dio = dio_pkg.Dio();

    try {
      await dio.download(
        _modelDownloadUrl,
        path,
        cancelToken: cancelToken,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress(received, total);
        },
        options: dio_pkg.Options(
          receiveTimeout: const Duration(hours: 2),
          headers: {'User-Agent': 'AskBase/1.0'},
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyModelReady, true);
      onDone();
    } on dio_pkg.DioException catch (e) {
      if (e.type == dio_pkg.DioExceptionType.cancel) return;
      final f = File(path);
      if (f.existsSync()) await f.delete();
      onError('Download failed: ${e.message}');
    } catch (e) {
      onError('Unexpected error: $e');
    }
  }

  // ── Load model ────────────────────────────────────────────────────────────

  /// Verifies the model file exists. nobodywho loads lazily per-chat session.
  Future<void> loadModel() async {
    if (_modelLoaded) return;
    _modelPath = await _getModelPath();
    if (!File(_modelPath!).existsSync()) {
      throw StateError('Model file not found. Download it first.');
    }
    // nobodywho initialises the runtime globally once
    await nw.NobodyWho.init();
    _modelLoaded = true;
  }

  bool get isModelLoaded => _modelLoaded;

  // ── SQL Generation ────────────────────────────────────────────────────────

  /// Generates a SQL SELECT query from a natural language question.
  /// Creates a fresh chat session per call so the model has no prior context
  /// bleeding in from summarization calls.
  Future<String> generateSql({
    required String userQuestion,
    required DatabaseSchema schema,
  }) async {
    _assertLoaded();

    final chat = await nw.Chat.fromPath(
      modelPath: _modelPath!,
      systemPrompt: _buildSqlSystemPrompt(schema),
      sampler: nw.SamplerPresets.temperature(temperature: 0.1),
    );

    final response = await chat
        .ask('Question: $userQuestion\n\nSQL:')
        .completed();
    return _extractSql(response);
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

    final prompt = [
      'User asked: $userQuestion',
      'Query used: $sqlQuery',
      'Results: $jsonRows',
      'Summary:',
    ].join('\n\n');

    final buffer = StringBuffer();

    final chat = await nw.Chat.fromPath(
      modelPath: _modelPath!,
      systemPrompt: _buildSummarySystemPrompt(schema),
      sampler: nw.SamplerPresets.temperature(temperature: 0.3),
    );

    final stream = chat.ask(prompt);

    await for (final token in stream) {
      buffer.write(token);
      onToken(token);
    }
    return buffer.toString().trim();
  }

  // ── Prompt builders ───────────────────────────────────────────────────────

  String _buildSqlSystemPrompt(DatabaseSchema schema) {
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
  }

  String _buildSummarySystemPrompt(DatabaseSchema schema) {
    return '''You are a helpful assistant for ${schema.databaseName}.
Explain database results in clear, simple language.
- Answer only from the data provided. Never add outside information.
- If results are empty, say no matching records were found.
- Keep answers concise: 1 to 4 sentences.
- Format numbers clearly (e.g. "1,250.5 kg").
- Do not mention SQL, queries, rows, or technical terms.''';
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _extractSql(String raw) {
    return raw
        .replaceAll('```sql', '')
        .replaceAll('```', '')
        .trim();
  }

  void _assertLoaded() {
    if (!_modelLoaded || _modelPath == null) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }
  }

  String get modelFileName => _modelFileName;
  String get downloadUrl => _modelDownloadUrl;
}
