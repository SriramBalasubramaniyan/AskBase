import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

import '../models/db_schema_model.dart';
import '../services/db_service.dart';
import '../services/llm_service.dart';
import '../services/schema_selector.dart';

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

    // ── Step 2: Generate SQL using only selected tables ─────────────────────
    String rawSql;
    try {
      rawSql = await _llm.generateSql(
        userQuestion: question,
        selectedTables: selectedTables,
        schemaName: schema.databaseName,
      );
    } catch (e) {
      return QueryResult(
        status: QueryResultStatus.llmError,
        summary:
            'The AI model encountered an error while generating a query. '
            'Please try again.',
        errorDetail: e.toString(),
        selectedTableNames: kDebugMode
            ? selectedTables.map((t) => t.tableName).toList()
            : null,
      );
    }

    // ── Step 3: Check special LLM responses ─────────────────────────────────
    final sqlUpper = rawSql.trim().toUpperCase();

    if (sqlUpper.contains('OUT_OF_SCOPE')) {
      return QueryResult(
        status: QueryResultStatus.outOfScope,
        summary: 'I can only answer questions about the data in this database. '
            'Please ask something related to the available records.',
        selectedTableNames: kDebugMode
            ? selectedTables.map((t) => t.tableName).toList()
            : null,
      );
    }

    if (sqlUpper.contains('CANNOT_ANSWER')) {
      return QueryResult(
        status: QueryResultStatus.cannotAnswer,
        summary:
            'The information you asked for is not available in this database.',
        selectedTableNames: kDebugMode
            ? selectedTables.map((t) => t.tableName).toList()
            : null,
      );
    }

    // ── Step 4: Validate SQL ─────────────────────────────────────────────────
    final validationError = _db.validateSql(rawSql);
    if (validationError != null) {
      return QueryResult(
        status: QueryResultStatus.sqlError,
        summary:
            'The generated query was not safe to run. Please rephrase your question.',
        generatedSql: rawSql,
        errorDetail: validationError,
        selectedTableNames: kDebugMode
            ? selectedTables.map((t) => t.tableName).toList()
            : null,
      );
    }

    // ── Step 5: Execute query ────────────────────────────────────────────────
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
        selectedTableNames: kDebugMode
            ? selectedTables.map((t) => t.tableName).toList()
            : null,
      );
    }

    // ── Step 6: Handle empty results ─────────────────────────────────────────
    if (rows.isEmpty) {
      return QueryResult(
        status: QueryResultStatus.emptyResult,
        summary: 'No records were found matching your question.',
        generatedSql: rawSql,
        rawJson: '[]',
        selectedTableNames: kDebugMode
            ? selectedTables.map((t) => t.tableName).toList()
            : null,
      );
    }

    // ── Step 7: Summarize ────────────────────────────────────────────────────
    final cappedRows = rows.length > 50 ? rows.sublist(0, 50) : rows;
    final jsonRows = const JsonEncoder.withIndent('  ').convert(cappedRows);

    String summary = '';
    try {
      summary = await _llm.summarizeResults(
        userQuestion: question,
        sqlQuery: rawSql,
        jsonRows: jsonRows,
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
        selectedTableNames: kDebugMode
            ? selectedTables.map((t) => t.tableName).toList()
            : null,
      );
    }

    return QueryResult(
      status: QueryResultStatus.success,
      summary: summary,
      generatedSql: rawSql,
      rawJson: jsonRows,
      selectedTableNames: kDebugMode
          ? selectedTables.map((t) => t.tableName).toList()
          : null,
    );
  }
}
