import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

import '../models/db_schema_model.dart';
import '../services/db_service.dart';
import '../services/join_path_finder.dart';
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
    // of just re-rolling blind. Column/table hallucinations are caught
    // deterministically by SqlColumnValidator *before* ever touching the
    // database. When that failure involves two tables that aren't directly
    // related by a foreign key, a literal, ready-to-use FROM/JOIN skeleton
    // is computed and appended. Loops at most _maxAttempts times.
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
        lastError = _withJoinPathHint(columnError, rawSql, schema);
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

    // Deterministic bypass for single-row/single-column results (any
    // COUNT/SUM/AVG/MIN/MAX-style aggregate, or any query that otherwise
    // reduces to exactly one value). This shape was the single biggest
    // source of unreliable output: the exact same SQL and exact same value
    // would sometimes be echoed correctly by the model and sometimes not,
    // across otherwise-identical runs — a prompt-following reliability
    // problem, not a prompt-wording one, so no amount of further prompt
    // tuning was going to fully fix it. Since there is only one value and
    // no real synthesis for an LLM to add here, it's constructed directly
    // in Dart instead — guaranteed correct every time, at the cost of
    // slightly more mechanical phrasing for this one shape. Guarded
    // against ID-like columns, which aren't meaningful answers to state.
    if (cappedRows.length == 1 && cappedRows.first.length == 1) {
      final rawKey = cappedRows.first.keys.first;
      final looksLikeId = rawKey.toLowerCase() == 'id' ||
          rawKey.toLowerCase().endsWith('_id');
      if (!looksLikeId) {
        final value = cappedRows.first.values.first;
        final answer = _deterministicSingleValueAnswer(rawKey, value);
        onToken(answer);
        return QueryResult(
          status: QueryResultStatus.success,
          summary: answer,
          generatedSql: rawSql,
          rawJson: jsonRows,
          selectedTableNames: debugTables,
        );
      }
    }

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

  /// Builds a plain-language sentence directly from a single-value SQL
  /// result — no LLM involved, so it's always numerically correct. Handles
  /// the common aggregate function shapes (COUNT/SUM/AVG/MIN/MAX, with or
  /// without a table-qualified argument, aliased or not) with natural
  /// phrasing, and falls back to a humanized version of the column/alias
  /// name for anything else (e.g. a named alias like "total_sowing").
  static final RegExp _aggregatePattern = RegExp(
    r'^(COUNT|SUM|AVG|MIN|MAX)\s*\(\s*(?:\*|[A-Za-z_][\w.]*)?\s*\)$',
    caseSensitive: false,
  );

  String _deterministicSingleValueAnswer(String rawKey, dynamic value) {
    final match = _aggregatePattern.firstMatch(rawKey.trim());
    if (match != null) {
      switch (match.group(1)!.toUpperCase()) {
        case 'COUNT':
          return 'There are $value matching records.';
        case 'SUM':
          return 'The total is $value.';
        case 'AVG':
          return 'The average is $value.';
        case 'MIN':
          return 'The minimum value is $value.';
        case 'MAX':
          return 'The maximum value is $value.';
      }
    }
    final label = rawKey.replaceAll('_', ' ').trim();
    final capitalized =
        label.isEmpty ? label : label[0].toUpperCase() + label.substring(1);
    return '$capitalized: $value.';
  }

  /// If [sql] references two or more real tables that aren't directly
  /// connected by a foreign key, appends a literal, ready-to-use FROM/JOIN
  /// skeleton (found via BFS over the schema's FK graph) to [baseError] so
  /// the next generation attempt can copy it directly instead of having to
  /// assemble a multi-hop join from separate facts on its own.
  String _withJoinPathHint(
    String baseError,
    String sql,
    DatabaseSchema schema,
  ) {
    final tables = SqlColumnValidator.referencedTables(sql, schema);
    if (tables.length < 2) return baseError;

    final hints = <String>[];
    for (var i = 0; i < tables.length; i++) {
      for (var j = i + 1; j < tables.length; j++) {
        final a = tables[i];
        final b = tables[j];

        final directlyLinked = a.fields
                .any((f) => f.foreignKeyRef?.startsWith('${b.tableName}.') ?? false) ||
            b.fields.any(
                (f) => f.foreignKeyRef?.startsWith('${a.tableName}.') ?? false);
        if (directlyLinked) continue;

        final path = JoinPathFinder.findPath(schema, a.tableName, b.tableName);
        if (path != null && path.isNotEmpty) {
          final skeleton = _buildJoinSkeleton(a.tableName, path);
          hints.add('${a.tableName} and ${b.tableName} are not directly '
              'related — do not join them directly to each other. Use '
              'exactly this join structure instead: $skeleton');
        }
      }
    }

    if (hints.isEmpty) return baseError;
    return '$baseError ${hints.join(" ")}';
  }

  /// Builds a literal `FROM x JOIN y ON ... JOIN z ON ...` skeleton from a
  /// starting table and an ordered list of join conditions (as produced by
  /// [JoinPathFinder.findPath]), so the model can copy it directly instead
  /// of assembling a multi-hop join from separate facts itself.
  String _buildJoinSkeleton(String startTable, List<String> conditions) {
    final included = <String>{startTable};
    final buffer = StringBuffer('FROM $startTable');
    for (final condition in conditions) {
      final parts = condition.split('=').map((s) => s.trim()).toList();
      if (parts.length != 2) continue;
      final leftTable = parts[0].split('.').first;
      final rightTable = parts[1].split('.').first;
      final newTable = included.contains(leftTable) ? rightTable : leftTable;
      included.add(newTable);
      buffer.write(' JOIN $newTable ON $condition');
    }
    return buffer.toString();
  }
}
