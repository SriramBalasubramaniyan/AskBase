import '../models/db_schema_model.dart';

/// Finds a chain of FK-based join conditions connecting two tables through
/// the schema's foreign keys, treated as undirected edges (you can join in
/// either direction). This exists because handing the model just an error
/// string ("insurance has no column crop_id") wasn't enough correction
/// signal for it to work out multi-hop join reasoning on its own — verified
/// in practice: across 3 self-correction attempts, the model kept trying
/// direct crop↔insurance joins even after being told crop_id doesn't exist
/// on insurance, despite the correct path (crop → sowing → insurance)
/// being fully present in its own schema context. Computing the path
/// deterministically and handing it over directly closes that gap.
class JoinPathFinder {
  JoinPathFinder._();

  /// Returns an ordered list of join conditions connecting [fromTable] to
  /// [toTable] (e.g. `["sowing.crop_id = crop.crop_id",
  /// "insurance.sowing_id = sowing.sowing_id"]`), or null if no path
  /// exists within [maxHops] hops. Returns an empty list if the two
  /// tables are the same.
  static List<String>? findPath(
    DatabaseSchema schema,
    String fromTable,
    String toTable, {
    int maxHops = 3,
  }) {
    if (fromTable == toTable) return [];

    final adjacency = _buildAdjacency(schema);

    var frontier = <_PathState>[_PathState(fromTable, const [])];
    final visited = <String>{fromTable};

    for (var hop = 0; hop < maxHops; hop++) {
      final nextFrontier = <_PathState>[];
      for (final state in frontier) {
        for (final edge in adjacency[state.node] ?? const <_Edge>[]) {
          if (edge.neighbor == toTable) {
            return [...state.conditions, edge.condition];
          }
          if (!visited.add(edge.neighbor)) continue;
          nextFrontier.add(
            _PathState(edge.neighbor, [...state.conditions, edge.condition]),
          );
        }
      }
      frontier = nextFrontier;
      if (frontier.isEmpty) break;
    }
    return null;
  }

  static Map<String, List<_Edge>> _buildAdjacency(DatabaseSchema schema) {
    final adjacency = <String, List<_Edge>>{};
    for (final table in schema.tables) {
      for (final field in table.fields) {
        if (field.foreignKeyRef == null) continue;
        final parts = field.foreignKeyRef!.split('.');
        if (parts.length != 2) continue;
        final refTable = parts[0];
        final refColumn = parts[1];
        final condition =
            '${table.tableName}.${field.name} = $refTable.$refColumn';
        adjacency
            .putIfAbsent(table.tableName, () => [])
            .add(_Edge(refTable, condition));
        adjacency
            .putIfAbsent(refTable, () => [])
            .add(_Edge(table.tableName, condition));
      }
    }
    return adjacency;
  }
}

class _Edge {
  final String neighbor;
  final String condition;
  const _Edge(this.neighbor, this.condition);
}

class _PathState {
  final String node;
  final List<String> conditions;
  const _PathState(this.node, this.conditions);
}
