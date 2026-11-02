import 'package:hive_flutter/hive_flutter.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/data/local/plan_visit_outbox_store.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_visit_close.dart';

/// Which of today's plan visits have their Inventory Visibility photos —
/// what Home's "Continue visit" card needs before it offers Check out (the
/// server refuses a check-out without a photo).
///
/// Done means the photos were sent, saved to send later (they are in the
/// outbox), or the server answered `PLAN_INVENTORY_PHOTO_LIMIT` — the visit
/// already holds them. Plan ids by date in the plain Hive cache box: no PII,
/// and only today's are kept. Never throws: unknown reads as not done, which
/// costs the rep a tap through the photo step, never a refused check-out.
class PlanInventoryLog {
  PlanInventoryLog({
    required Box<dynamic> box,
    required PlanVisitOutboxStore store,
    DateTime Function() now = DateTime.now,
  })  : _box = box,
        _store = store,
        _now = now;

  final Box<dynamic> _box;
  final PlanVisitOutboxStore _store;
  final DateTime Function() _now;

  static const String _key = 'isi.plan_inventory_done';

  String get _today {
    final d = _now();
    return '${d.year}-${d.month}-${d.day}';
  }

  Map<String, String> _read() {
    try {
      final raw = _box.get(_key);
      if (raw is! Map) return {};
      return {
        for (final MapEntry(:key, :value) in raw.entries)
          if (key is String && value is String) key: value,
      };
    } on Object {
      return {};
    }
  }

  /// Records [planId] as done today, dropping earlier days.
  Future<void> mark(String planId) async {
    try {
      final today = _today;
      final kept = _read()..removeWhere((_, day) => day != today);
      await _box.put(_key, {...kept, planId: today});
    } on Object {
      // A convenience: the card falls back to asking for the photos.
    }
  }

  Future<bool> isDone(String planId) async {
    if (_read()[planId] == _today) return true;
    try {
      return (await _store.stepsFor(planId))
          .any((s) => s.kind == PlanStepKind.inventory);
    } on Object {
      return false;
    }
  }

  /// Runs the upload [send] for [planId] and records it once it is done.
  Future<Result<T>> track<T>(
      String planId, ResultFuture<T> Function() send) async {
    final result = await send();
    final done = switch (result) {
      Success() => true,
      Failed(:final failure) =>
        failure is ServerFailure && failure.code == planInventoryPhotoLimitCode,
    };
    if (done) await mark(planId);
    return result;
  }
}
