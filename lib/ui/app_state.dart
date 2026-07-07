import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/db_schema_model.dart';
import '../services/db_service.dart';
import '../services/llm_service.dart';
import '../services/query_service.dart';

enum AppStatus { initializing, needsDownload, downloading, loading, ready, error }

class AppState extends ChangeNotifier {
  AppState(this._schema);

  final DatabaseSchema _schema;

  AppStatus _status = AppStatus.initializing;
  String _statusMessage = 'Starting…';
  String? _errorMessage;

  // Download progress 0–100
  int _downloadProgress = 0;

  final List<ChatMessage> _messages = [];
  bool _isProcessing = false;

  // ── Getters ───────────────────────────────────────────────────────────────
  AppStatus get status => _status;
  String get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isProcessing => _isProcessing;
  DatabaseSchema get schema => _schema;
  int get downloadProgress => _downloadProgress;

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    _setStatus(AppStatus.initializing, 'Starting up…');
    try {
      _setStatus(AppStatus.initializing, 'Loading database…');
      await DbService.instance.init(_schema);

      final modelReady = await LlmService.instance.isModelDownloaded();
      if (!modelReady) {
        _setStatus(AppStatus.needsDownload, 'Model download required');
        return;
      }

      await _loadModel();
    } catch (e) {
      _setStatus(AppStatus.error, 'Initialization failed');
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> _loadModel() async {
    _setStatus(AppStatus.loading, 'Loading AI model…');
    try {
      await LlmService.instance.loadModel();
      _setStatus(AppStatus.ready, 'Ready');
    } catch (e) {
      _setStatus(AppStatus.error, 'Failed to load model');
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ── Download ──────────────────────────────────────────────────────────────

  Future<void> startDownload() async {
    _downloadProgress = 0;
    _setStatus(AppStatus.downloading, 'Downloading model…');

    await LlmService.instance.downloadModel(
      onProgress: (progress) {
        _downloadProgress = progress;
        notifyListeners();
      },
      onDone: () async {
        await _loadModel();
      },
      onError: (error) {
        _setStatus(AppStatus.needsDownload, 'Download failed');
        _errorMessage = error;
        notifyListeners();
      },
    );
  }

  void cancelDownload() {
    // flutter_gemma handles cancellation internally
    _downloadProgress = 0;
    _setStatus(AppStatus.needsDownload, 'Download cancelled');
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  Future<void> sendMessage(String question) async {
    if (_isProcessing || question.trim().isEmpty) return;
    if (_status != AppStatus.ready) return;

    _isProcessing = true;

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.user,
      content: question.trim(),
      state: MessageState.done,
      timestamp: DateTime.now(),
    );
    _messages.add(userMsg);

    final assistantId = '${DateTime.now().millisecondsSinceEpoch}_a';
    _messages.add(ChatMessage(
      id: assistantId,
      role: MessageRole.assistant,
      content: '',
      state: MessageState.thinking,
      timestamp: DateTime.now(),
    ));
    notifyListeners();

    String streamedContent = '';

    try {
      final result = await QueryService.instance.ask(
        question: question.trim(),
        schema: _schema,
        onToken: (token) {
          streamedContent += token;
          _updateAssistantMessage(
            assistantId,
            content: streamedContent,
            state: MessageState.streaming,
          );
        },
      );

      _updateAssistantMessage(
        assistantId,
        content: result.summary.isNotEmpty ? result.summary : streamedContent,
        state: MessageState.done,
        generatedSql: result.generatedSql,
        rawData: result.rawJson,
        selectedTableNames: result.selectedTableNames,
      );
    } catch (e) {
      _updateAssistantMessage(
        assistantId,
        content: 'Something went wrong. Please try again.',
        state: MessageState.error,
      );
    }

    _isProcessing = false;
    notifyListeners();
  }

  void _updateAssistantMessage(
    String id, {
    required String content,
    required MessageState state,
    String? generatedSql,
    String? rawData,
    List<String>? selectedTableNames,
  }) {
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx == -1) return;
    _messages[idx] = _messages[idx].copyWith(
      content: content,
      state: state,
      generatedSql: generatedSql,
      rawData: rawData,
      selectedTableNames: selectedTableNames,
    );
    notifyListeners();
  }

  void clearChat() {
    _messages.clear();
    notifyListeners();
  }

  void _setStatus(AppStatus status, String message) {
    _status = status;
    _statusMessage = message;
    notifyListeners();
  }
}
