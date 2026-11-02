import 'dart:convert';

import 'package:steelforce/core/database/drift/daos/visit_plan_dao.dart';
import 'package:steelforce/features/my_visits/data/models/plan_check_in_model.dart';
import 'package:steelforce/features/my_visits/data/models/visit_plans_model.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_check_in.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plans_overview.dart';

/// The device's copy of the plans endpoints' last answers.
abstract interface class VisitPlanLocalDataSource {
  /// Replaces the copy for [key] with [overview], answered at [fetchedAt].
  Future<void> save(
      String key, VisitPlansOverview overview, DateTime fetchedAt);

  /// The copy for [key], marked with when it was saved; null when there is
  /// none or it cannot be read.
  Future<VisitPlansOverview?> read(String key);

  /// Keeps a plan's depot location and radius for a check-in started
  /// offline.
  Future<void> saveTarget(PlanCheckInTarget target, DateTime fetchedAt);

  /// The kept target of [planId] and when it was fetched; null when none.
  Future<({PlanCheckInTarget target, DateTime fetchedAt})?> readTarget(
      String planId);
}

/// Keys: one per endpoint.
abstract final class VisitPlanCacheKeys {
  static const today = 'Today';
  static String period(PlanPeriod period) => period.apiValue;
  static String target(String planId) => 'target:$planId';
}

class DriftVisitPlanLocalDataSource implements VisitPlanLocalDataSource {
  const DriftVisitPlanLocalDataSource(this._dao);

  final VisitPlanDao _dao;

  @override
  Future<void> save(
          String key, VisitPlansOverview overview, DateTime fetchedAt) =>
      _dao.save(key, jsonEncode(VisitPlansModel.toJson(overview)), fetchedAt);

  @override
  Future<VisitPlansOverview?> read(String key) async {
    final row = await _dao.read(key);
    if (row == null) return null;
    try {
      final json = jsonDecode(row.payload);
      if (json is! Map) return null;
      return VisitPlansModel.fromJson(json.cast<String, dynamic>())
          .savedCopy(row.fetchedAt.toLocal());
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> saveTarget(PlanCheckInTarget target, DateTime fetchedAt) =>
      _dao.save(VisitPlanCacheKeys.target(target.planId),
          jsonEncode(PlanCheckInModel.targetToJson(target)), fetchedAt);

  @override
  Future<({PlanCheckInTarget target, DateTime fetchedAt})?> readTarget(
      String planId) async {
    final row = await _dao.read(VisitPlanCacheKeys.target(planId));
    if (row == null) return null;
    try {
      final json = jsonDecode(row.payload);
      if (json is! Map) return null;
      return (
        target: PlanCheckInModel.targetFromJson(json.cast<String, dynamic>()),
        fetchedAt: row.fetchedAt.toLocal(),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}
