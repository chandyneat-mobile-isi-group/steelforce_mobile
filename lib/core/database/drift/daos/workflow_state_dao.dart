import 'package:drift/drift.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/tables/workflow_state_table.dart';
import 'package:steelforce/core/utils/typedefs.dart';

part 'workflow_state_dao.g.dart';

/// The single active-workflow pointer (**T1.5b**), ported off the plaintext
/// `routes.db`.
///
/// Returns raw [DataMap] rows because `ActiveWorkflowModel.fromRow`/`toRow`
/// already own the mapping in both directions, and this port must not change
/// them — see the note on the [WorkflowState] table about why this is a move,
/// not ADR-007's generalization.
@DriftAccessor(tables: [WorkflowState])
class WorkflowStateDao extends DatabaseAccessor<AppDatabase>
    with _$WorkflowStateDaoMixin {
  WorkflowStateDao(super.db);

  /// The one row's primary key. Mirrors the `'active'` literal that
  /// `ActiveWorkflowModel.toRow()` writes.
  static const activeId = 'active';

  static const columns = <String>[
    'id',
    'route_id',
    'current_stop_id',
    'day_started',
    'updated_at',
    'depot_id',
    'shop_name',
    'check_in_at',
    'current_workflow',
    'current_screen',
    'navigation_arguments',
    'workflow_updated_at',
  ];

  Future<DataMap?> getActive() async {
    final rows = await customSelect(
      'SELECT * FROM workflow_state WHERE id = ? LIMIT 1',
      variables: [Variable(activeId)],
      readsFrom: {workflowState},
    ).get();
    return rows.isEmpty ? null : rows.first.data;
  }

  /// `INSERT OR REPLACE`, matching the sqflite original's
  /// `ConflictAlgorithm.replace` — a resume pointer is always written whole, so
  /// replacing rather than patching is the correct semantic here.
  Future<void> saveActive(DataMap row) async {
    final placeholders = List.filled(columns.length, '?').join(', ');
    await customInsert(
      'INSERT OR REPLACE INTO workflow_state (${columns.join(', ')}) '
      'VALUES ($placeholders)',
      variables: [for (final c in columns) Variable(row[c])],
      updates: {workflowState},
    );
  }

  Future<void> clearActive() =>
      (delete(workflowState)..where((t) => t.id.equals(activeId))).go();

  /// Clears the resume pointer only when it points at [stopId] — for a visit
  /// whose check-in was discarded, so "continue visit" no longer offers a
  /// visit that is gone. Returns the number of rows removed (0 or 1).
  Future<int> clearActiveIfAtStop(String stopId) => (delete(workflowState)
        ..where((t) => t.id.equals(activeId) & t.currentStopId.equals(stopId)))
      .go();
}
