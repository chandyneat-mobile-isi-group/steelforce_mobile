import 'dart:convert';

import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_workflow.dart';

class ActiveWorkflowModel extends ActiveWorkflow {
  const ActiveWorkflowModel({
    required super.routeId,
    super.currentStopId,
    required super.dayStarted,
    required super.updatedAt,
    super.depotId,
    super.shopName,
    super.checkInAt,
    super.currentWorkflow,
    super.currentScreen,
    super.navigationArguments,
    super.workflowUpdatedAt,
  });

  factory ActiveWorkflowModel.fromRow(DataMap row) => ActiveWorkflowModel(
        routeId: row['route_id'] as String,
        currentStopId: row['current_stop_id'] as String?,
        dayStarted: (row['day_started'] as int) == 1,
        updatedAt: DateTime.parse(row['updated_at'] as String),
        depotId: row['depot_id'] as String?,
        shopName: row['shop_name'] as String?,
        checkInAt: _parseDate(row['check_in_at']),
        currentWorkflow:
            VisitWorkflow.fromKey(row['current_workflow'] as String?),
        currentScreen: row['current_screen'] as String?,
        navigationArguments: _parseArgs(row['navigation_arguments']),
        workflowUpdatedAt: _parseDate(row['workflow_updated_at']),
      );

  DataMap toRow() => {
        'id': 'active',
        'route_id': routeId,
        'current_stop_id': currentStopId,
        'day_started': dayStarted ? 1 : 0,
        'updated_at': updatedAt.toIso8601String(),
        'depot_id': depotId,
        'shop_name': shopName,
        'check_in_at': checkInAt?.toIso8601String(),
        'current_workflow': currentWorkflow?.storageKey,
        'current_screen': currentScreen,
        'navigation_arguments': navigationArguments == null
            ? null
            : jsonEncode(navigationArguments),
        'workflow_updated_at': workflowUpdatedAt?.toIso8601String(),
      };

  factory ActiveWorkflowModel.fromEntity(ActiveWorkflow e) =>
      ActiveWorkflowModel(
        routeId: e.routeId,
        currentStopId: e.currentStopId,
        dayStarted: e.dayStarted,
        updatedAt: e.updatedAt,
        depotId: e.depotId,
        shopName: e.shopName,
        checkInAt: e.checkInAt,
        currentWorkflow: e.currentWorkflow,
        currentScreen: e.currentScreen,
        navigationArguments: e.navigationArguments,
        workflowUpdatedAt: e.workflowUpdatedAt,
      );

  static DateTime? _parseDate(Object? raw) =>
      raw == null ? null : DateTime.parse(raw as String);

  /// Decodes the persisted JSON args, tolerating null/legacy/corrupt values by
  /// returning null (the dispatcher then falls back to the guided route resume).
  static Map<String, dynamic>? _parseArgs(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
