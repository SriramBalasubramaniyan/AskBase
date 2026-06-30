/// Core data classes for defining a database schema that the SLM uses
/// to generate SQL queries. This file is domain-agnostic — the actual
/// schema lives in lib/schema/<domain>_schema.dart.

// ── Field definition ─────────────────────────────────────────────────────────

enum FieldType { integer, text, real, blob }

class FieldDef {
  /// The exact column name in the SQLite table.
  final String name;

  /// SQLite column type.
  final FieldType type;

  /// Human-readable explanation injected into the LLM prompt so the model
  /// understands what this field represents (e.g. "Foreign key to farmer.farmer_id").
  final String description;

  /// Whether this field is the primary key.
  final bool isPrimaryKey;

  /// Whether this field is a foreign key and to which table.column it points.
  final String? foreignKeyRef; // e.g. "farmer.farmer_id"

  const FieldDef({
    required this.name,
    required this.type,
    required this.description,
    this.isPrimaryKey = false,
    this.foreignKeyRef,
  });

  String get typeString {
    switch (type) {
      case FieldType.integer:
        return 'INTEGER';
      case FieldType.text:
        return 'TEXT';
      case FieldType.real:
        return 'REAL';
      case FieldType.blob:
        return 'BLOB';
    }
  }

  /// Builds a compact single-line representation for the LLM prompt.
  String toPromptLine() {
    final sb = StringBuffer();
    sb.write('  $name $typeString');
    if (isPrimaryKey) sb.write(' [PK]');
    if (foreignKeyRef != null) sb.write(' [FK → $foreignKeyRef]');
    sb.write(' — $description');
    return sb.toString();
  }
}

// ── Table definition ─────────────────────────────────────────────────────────

class TableSchema {
  /// The exact table name in the SQLite database.
  final String tableName;

  /// One-sentence description of what this table stores.
  final String tableDescription;

  /// Ordered list of field definitions.
  final List<FieldDef> fields;

  const TableSchema({
    required this.tableName,
    required this.tableDescription,
    required this.fields,
  });

  /// Returns all fields that are foreign keys.
  List<FieldDef> get foreignKeys =>
      fields.where((f) => f.foreignKeyRef != null).toList();

  /// Builds the full table block injected into the LLM system prompt.
  String toPromptBlock() {
    final sb = StringBuffer();
    sb.writeln('TABLE: $tableName');
    sb.writeln('  Description: $tableDescription');
    sb.writeln('  Columns:');
    for (final field in fields) {
      sb.writeln(field.toPromptLine());
    }
    return sb.toString();
  }
}

// ── Full database schema ──────────────────────────────────────────────────────

class DatabaseSchema {
  /// Human-readable name for this database (used in UI and prompts).
  final String databaseName;

  /// One paragraph describing the overall domain and purpose of the database.
  final String databaseDescription;

  /// All tables in the database.
  final List<TableSchema> tables;

  /// The asset path of the bundled .db file (relative to assets/).
  final String assetPath;

  /// The filename the DB will be saved as in the app's documents directory.
  final String dbFileName;

  const DatabaseSchema({
    required this.databaseName,
    required this.databaseDescription,
    required this.tables,
    required this.assetPath,
    required this.dbFileName,
  });

  /// Returns a table by name, or null if not found.
  TableSchema? tableByName(String name) {
    try {
      return tables.firstWhere(
        (t) => t.tableName.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns all table names as a comma-separated string.
  String get tableNameList => tables.map((t) => t.tableName).join(', ');

  /// Builds the complete schema prompt block used as the LLM system context.
  /// This is the core of what makes the model schema-aware.
  String toFullPrompt() {
    final sb = StringBuffer();
    sb.writeln('DATABASE: $databaseName');
    sb.writeln('DESCRIPTION: $databaseDescription');
    sb.writeln('');
    sb.writeln('SCHEMA:');
    sb.writeln('');
    for (final table in tables) {
      sb.writeln(table.toPromptBlock());
    }

    // Build relationship summary for JOIN awareness
    sb.writeln('RELATIONSHIPS:');
    for (final table in tables) {
      for (final fk in table.foreignKeys) {
        sb.writeln(
          '  ${table.tableName}.${fk.name} → ${fk.foreignKeyRef}',
        );
      }
    }
    return sb.toString();
  }
}
