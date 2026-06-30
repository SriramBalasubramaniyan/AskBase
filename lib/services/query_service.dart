import 'dart:convert';

import '../models/db_schema_model.dart';
import '../services/db_service.dart';
import '../services/llm_service.dart';

// ── Result types ──────────────────────────────────────────────────────────────

enum QueryResultStatus {
  success,
  outOfScope,
  cannotAnswer,
  sqlError,
  emptyResult,
  llmError,
}

class QueryResult {
  final QueryResultStatus status;
  final String summary;
  final String? generatedSql;
  final String? rawJson;
  final String? errorDetail;

  const QueryResult({
    required this.status,
    required this.summary,
    this.generatedSql,
    this.rawJson,
    this.errorDetail,
  });

  bool get isSuccess => status == QueryResultStatus.success;
}

// ── Query Service ─────────────────────────────────────────────────────────────

/// Orchestrates the full pipeline:
/// Natural language question → SQL generation → DB execution → summarization
class QueryService {
  QueryService._();
  static final QueryService instance = QueryService._();

  final _db = DbService.instance;
  final _llm = LlmService.instance;

  /// Runs the full pipeline for a user question.
  /// [onToken] streams summary tokens as they arrive.
  Future<QueryResult> ask({
    required String question,
    required DatabaseSchema schema,
    required void Function(String token) onToken,
  }) async {
    // ── Step 1: Generate SQL ────────────────────────────────────────────────
    String rawSql;
    try {
      rawSql = await _llm.generateSql(
        userQuestion: question,
        schema: schema,
      );
    } catch (e) {
      return QueryResult(
        status: QueryResultStatus.llmError,
        summary: 'The AI model encountered an error while generating a query. '
            'Please try again.',
        errorDetail: e.toString(),
      );
    }

    // ── Step 2: Check special LLM responses ────────────────────────────────
    final sqlUpper = rawSql.trim().toUpperCase();

    if (sqlUpper.contains('OUT_OF_SCOPE')) {
      return const QueryResult(
        status: QueryResultStatus.outOfScope,
        summary:
            'I can only answer questions about the agricultural data in this '
            'database. Please ask about farmers, farms, crops, sowing, or '
            'harvests.',
      );
    }

    if (sqlUpper.contains('CANNOT_ANSWER')) {
      return const QueryResult(
        status: QueryResultStatus.cannotAnswer,
        summary:
            'The information you asked for is not available in this database. '
            'The database tracks farmers, farms, crops, sowing events, and '
            'harvests — but does not contain other details.',
      );
    }

    // ── Step 3: Validate SQL ────────────────────────────────────────────────
    final validationError = _db.validateSql(rawSql);
    if (validationError != null) {
      return QueryResult(
        status: QueryResultStatus.sqlError,
        summary: 'The generated query was not safe to run. Please rephrase '
            'your question.',
        generatedSql: rawSql,
        errorDetail: validationError,
      );
    }

    // ── Step 4: Execute query ───────────────────────────────────────────────
    List<Map<String, dynamic>> rows;
    try {
      rows = await _db.runSelect(rawSql);
    } catch (e) {
      return QueryResult(
        status: QueryResultStatus.sqlError,
        summary:
            'There was a problem running the database query. The question may '
            'reference columns or tables that don\'t exist.',
        generatedSql: rawSql,
        errorDetail: e.toString(),
      );
    }

    // ── Step 5: Handle empty results ────────────────────────────────────────
    if (rows.isEmpty) {
      return QueryResult(
        status: QueryResultStatus.emptyResult,
        summary: 'No records were found matching your question.',
        generatedSql: rawSql,
        rawJson: '[]',
      );
    }

    // ── Step 6: Summarize results ───────────────────────────────────────────
    // Cap rows sent to LLM to avoid context overflow
    final cappedRows = rows.length > 50 ? rows.sublist(0, 50) : rows;
    final jsonRows = const JsonEncoder.withIndent('  ').convert(cappedRows);

    String summary = '';
    try {
      summary = await _llm.summarizeResults(
        userQuestion: question,
        sqlQuery: rawSql,
        jsonRows: jsonRows,
        schema: schema,
        onToken: onToken,
      );
    } catch (e) {
      // Fallback: return raw data if summarization fails
      return QueryResult(
        status: QueryResultStatus.success,
        summary: 'Found ${rows.length} result(s). '
            'Summary unavailable — showing raw data.',
        generatedSql: rawSql,
        rawJson: jsonRows,
        errorDetail: e.toString(),
      );
    }

    return QueryResult(
      status: QueryResultStatus.success,
      summary: summary,
      generatedSql: rawSql,
      rawJson: jsonRows,
    );
  }
}
