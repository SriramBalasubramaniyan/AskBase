import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

import '../models/db_schema_model.dart';
import '../services/db_service.dart';
import '../services/llm_service.dart';
import '../services/schema_selector.dart';
import '../services/sql_column_validator.dart';

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

  /// Tables that were selected by the schema selector.
  /// Populated in debug builds only.
  final List<String>? selectedTableNames;

  const QueryResult({
    required this.status,
    required this.summary,
    this.generatedSql,
    this.rawJson,
    this.errorDetail,
    this.selectedTableNames,
  });

  bool get isSuccess => status == QueryResultStatus.success;
}

class QueryService {
  QueryService._();
  static final QueryService instance = QueryService._();

  final _db = DbService.instance;
  final _llm = LlmService.instance;
  final _selector = SchemaSelector.instance;

  /// Total SQL-generation attempts per question: 1 initial try + this many
  /// self-correction retries. Kept small on purpose — each attempt is a
  /// full on-device generation call, not free on a 0.5B model on a phone,
  /// and a question that's genuinely unanswerable from the schema won't be
  /// fixed by trying harder.
  static const int _maxRetries = 2;
  static const int _maxAttempts = _maxRetries + 1;

  Future<QueryResult> ask({
    required String question,
    required DatabaseSchema schema,
    required void Function(String token) onToken,
  }) async {
    // ── Step 1: Select relevant tables semantically ─────────────────────────
    final selectedTables = _selector.select(question, schema);

    // Debug only — log which tables were selected
    if (kDebugMode) {
      final debugInfo = _selector.debugSelectionInfo(question, schema);
      developer.log(debugInfo, name: 'SchemaSelector');
    }

    final debugTables =
        kDebugMode ? selectedTables.map((t) => t.tableName).toList() : null;

    // ── Steps 2-5: generate → check → validate → execute, with
    // self-correction ─────────────────────────────────────────────────────
    // On failure at any stage, the specific error is fed back into the next
    // generation attempt so the model can actually fix its mistake instead
    // of just re-rolling blind. Column/table hallucinations are now caught
    // deterministically by SqlColumnValidator *before* ever touching the
    // database — cheaper than a DB round-trip, and it produces a specific,
    // actionable message ("table X has no column Y, actual columns are...")
    // instead of a generic SQLite error string. Loops at most _maxAttempts
    // times total.
    String? rawSql;
    String? lastError;
    List<Map<String, dynamic>>? rows;

    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      final isRetry = attempt > 1;

      String candidateSql;
      try {
        candidateSql = await _llm.generateSql(
          userQuestion: question,
          selectedTables: selectedTables,
          schemaName: schema.databaseName,
          previousAttemptSql: isRetry ? rawSql : null,
          previousError: isRetry ? lastError : null,
        );
      } catch (e) {
        lastError = e.toString();
        if (kDebugMode) {
          developer.log('Attempt $attempt: generation threw — $lastError',
              name: 'QueryService');
        }
        if (attempt == _maxAttempts) {
          return QueryResult(
            status: QueryResultStatus.llmError,
            summary:
                'The AI model encountered an error while generating a '
                'query. Please try again.',
            errorDetail: lastError,
            selectedTableNames: debugTables,
          );
        }
        continue;
      }

      rawSql = candidateSql;
      final sqlUpper = rawSql.trim().toUpperCase();

      // These are the model correctly declining, not a bug to retry against.
      if (sqlUpper.contains('OUT_OF_SCOPE')) {
        return QueryResult(
          status: QueryResultStatus.outOfScope,
          summary:
              'I can only answer questions about the data in this database. '
              'Please ask something related to the available records.',
          selectedTableNames: debugTables,
        );
      }

      if (sqlUpper.contains('CANNOT_ANSWER')) {
        return QueryResult(
          status: QueryResultStatus.cannotAnswer,
          summary:
              'The information you asked for is not available in this database.',
          selectedTableNames: debugTables,
        );
      }

      // Deterministic pre-flight check: does every table/column referenced
      // actually exist? Checked against the full schema (not just the
      // tables the model was shown) so a hallucinated table/column is
      // caught even if it happens to collide with something real elsewhere.
      final columnError = SqlColumnValidator.check(rawSql, schema);
      if (columnError != null) {
        lastError = columnError;
        if (kDebugMode) {
          developer.log('Attempt $attempt: column check failed — $lastError',
              name: 'QueryService');
        }
        if (attempt == _maxAttempts) break;
        continue;
      }

      final validationError = _db.validateSql(rawSql);
      if (validationError != null) {
        lastError = validationError;
        if (kDebugMode) {
          developer.log('Attempt $attempt: validation failed — $lastError',
              name: 'QueryService');
        }
        if (attempt == _maxAttempts) break;
        continue;
      }

      try {
        rows = await _db.runSelect(rawSql);
        lastError = null;
        if (kDebugMode) {
          developer.log('Attempt $attempt: succeeded', name: 'QueryService');
        }
        break; // got a runnable query — stop retrying
      } catch (e) {
        lastError = e.toString();
        if (kDebugMode) {
          developer.log('Attempt $attempt: execution failed — $lastError',
              name: 'QueryService');
        }
        if (attempt == _maxAttempts) break;
        continue;
      }
    }

    // Exhausted every attempt without landing a runnable query.
    if (rows == null) {
      return QueryResult(
        status: QueryResultStatus.sqlError,
        summary: 'I couldn\'t come up with a working query for "$question" '
            'right now. Try rephrasing your question, or ask about '
            'something else in the data.',
        generatedSql: rawSql,
        errorDetail: lastError,
        selectedTableNames: debugTables,
      );
    }

    // ── Step 6: Handle empty results ─────────────────────────────────────────
    if (rows.isEmpty) {
      return QueryResult(
        status: QueryResultStatus.emptyResult,
        summary: 'No records were found matching your question.',
        generatedSql: rawSql,
        rawJson: '[]',
        selectedTableNames: debugTables,
      );
    }

    // ── Step 7: Summarize ────────────────────────────────────────────────────
    final cappedRows = rows.length > 50 ? rows.sublist(0, 50) : rows;
    final jsonRows = const JsonEncoder.withIndent('  ').convert(cappedRows);

    String summary = '';
    try {
      summary = await _llm.summarizeResults(
        userQuestion: question,
        sqlQuery: rawSql!,
        rows: cappedRows,
        schemaName: schema.databaseName,
        onToken: onToken,
      );
    } catch (e) {
      return QueryResult(
        status: QueryResultStatus.success,
        summary: 'Found ${rows.length} result(s). Summary unavailable.',
        generatedSql: rawSql,
        rawJson: jsonRows,
        errorDetail: e.toString(),
        selectedTableNames: debugTables,
      );
    }

    return QueryResult(
      status: QueryResultStatus.success,
      summary: summary,
      generatedSql: rawSql,
      rawJson: jsonRows,
      selectedTableNames: debugTables,
    );
  }
}
