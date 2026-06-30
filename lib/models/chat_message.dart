import 'package:flutter/foundation.dart';

enum MessageRole { user, assistant }

enum MessageState { idle, thinking, streaming, done, error }

@immutable
class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final MessageState state;
  final DateTime timestamp;

  /// The raw SQL generated for this response (shown in debug / expandable).
  final String? generatedSql;

  /// The raw rows returned from the DB before summarization.
  final String? rawData;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.state = MessageState.idle,
    required this.timestamp,
    this.generatedSql,
    this.rawData,
  });

  ChatMessage copyWith({
    String? content,
    MessageState? state,
    String? generatedSql,
    String? rawData,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      state: state ?? this.state,
      timestamp: timestamp,
      generatedSql: generatedSql ?? this.generatedSql,
      rawData: rawData ?? this.rawData,
    );
  }

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;
  bool get isLoading =>
      state == MessageState.thinking || state == MessageState.streaming;
}
