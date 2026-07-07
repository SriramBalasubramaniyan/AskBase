import 'dart:async';
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
  Future<String> generateSql({
    required String userQuestion,
    required List<TableSchema> selectedTables,
    required String schemaName,
  }) async {
    _assertLoaded();

    final chat = await _model!.createChat(
      systemInstruction: _buildSqlSystemPrompt(selectedTables, schemaName),
    );

    await chat.addQueryChunk(Message.text(
      text: 'Question: $userQuestion\n\nSQL:',
      isUser: true,
    ));

    final response = await chat.generateChatResponse();
    final sqlText =
        response is TextResponse ? response.token : response.toString();
    return _extractSql(sqlText);
  }

  // ── Summarization ─────────────────────────────────────────────────────────

  Future<String> summarizeResults({
    required String userQuestion,
    required String sqlQuery,
    required String jsonRows,
    required String schemaName,
    required void Function(String token) onToken,
  }) async {
    _assertLoaded();

    final chat = await _model!.createChat(
      systemInstruction:
          'Explain these $schemaName query results in 1-3 plain sentences. '
          'If results are empty, say no matching records were found. '
          'Only use the data given. No SQL terms.',
    );

    final prompt = 'User asked: $userQuestion\n\nResults: $jsonRows\n\nSummary:';

    await chat.addQueryChunk(Message.text(text: prompt, isUser: true));

    final buffer = StringBuffer();
    String lastCumulative = '';

    await for (final response in chat.generateChatResponseAsync()) {
      final fullText =
          response is TextResponse ? response.token : response.toString();
      if (fullText.length > lastCumulative.length) {
        final delta = fullText.substring(lastCumulative.length);
        buffer.write(delta);
        onToken(delta);
        lastCumulative = fullText;
      } else if (lastCumulative.isEmpty && fullText.isNotEmpty) {
        buffer.write(fullText);
        onToken(fullText);
        lastCumulative = fullText;
      }
    }

    return buffer.toString().trim();
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
        'Rules: SELECT only. Use aliases in JOINs. '
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
