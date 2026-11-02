import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/daos/visit_plan_dao.dart';
import 'package:steelforce/features/my_visits/data/local/plan_visit_outbox_codec.dart';

export 'package:steelforce/features/my_visits/data/local/plan_visit_outbox_codec.dart';

/// Plan visit steps saved on the device until the server has them.
///
/// Photos are copied in when a step is saved: the camera's files live in a
/// cache the system may clear while the step waits, and a step sent without
/// its photos would be refused for good.
class PlanVisitOutboxStore {
  PlanVisitOutboxStore(
    this._dao, {
    Future<Directory> Function() documents = getApplicationDocumentsDirectory,
    DateTime Function() now = DateTime.now,
  })  : _documents = documents,
        _now = now;

  final VisitPlanDao _dao;
  final Future<Directory> Function() _documents;
  final DateTime Function() _now;

  /// Saves [request] behind whatever [request]'s plan already has waiting.
  ///
  /// A check-in replaces one the server refused — that is how the rep fixes
  /// it, e.g. with a reason — and goes back to the front, where a check-in
  /// belongs; the steps it held are released with it.
  Future<void> enqueue(Object request) async {
    final planId = PlanOutboxCodec.planIdOf(request);
    var at = _now().toUtc();
    if (PlanOutboxCodec.kindOf(request) == PlanStepKind.checkIn) {
      final waiting = await stepsFor(planId);
      for (final old in waiting.where((s) => s.kind == PlanStepKind.checkIn)) {
        await remove(old);
      }
      if (waiting.isNotEmpty) {
        at = waiting.first.createdAt.subtract(const Duration(milliseconds: 1));
      }
      await _dao.clearFlagsFor(planId);
    }
    final id = PlanOutboxCodec.idOf(request);
    final kept = PlanOutboxCodec.withPhotos(
        request, await _copyPhotos(id, PlanOutboxCodec.photosOf(request)));
    await _dao.enqueueStep(PlanVisitOutboxCompanion.insert(
      id: id,
      planId: planId,
      kind: PlanOutboxCodec.kindOf(request).name,
      payload: PlanOutboxCodec.encode(kept),
      createdAt: at,
    ));
  }

  Future<List<PlanOutboxStep>> all() async => _read(await _dao.allSteps());

  Stream<List<PlanOutboxStep>> watch() => _dao.watchSteps().map(_read);

  Future<List<PlanOutboxStep>> stepsFor(String planId) async =>
      _read(await _dao.stepsFor(planId));

  /// The step reached the server: its row and its photo copies go.
  Future<void> remove(PlanOutboxStep step) async {
    await _dao.deleteStep(step.id);
    await _deletePhotos(step.id);
  }

  /// The rep gave up on [planId]'s waiting steps.
  Future<void> discardPlan(String planId) async {
    for (final step in await stepsFor(planId)) {
      await _deletePhotos(step.id);
    }
    await _dao.deleteStepsFor(planId);
  }

  Future<void> markAttempted(String id, String code) =>
      _dao.markStepAttempted(id, code);

  Future<void> flag(String id, String code, String message) =>
      _dao.flagStep(id, code, message);

  Future<void> clearFlags(String planId) => _dao.clearFlagsFor(planId);

  /// Rows this version cannot read are skipped rather than failing every
  /// other step behind them.
  static List<PlanOutboxStep> _read(List<PlanVisitOutboxData> rows) => [
        for (final row in rows)
          if (_decode(row) case final request?)
            PlanOutboxStep(
              request: request,
              createdAt: row.createdAt,
              needsAttention: row.needsAttention,
              errorCode: row.needsAttention ? row.lastErrorCode : null,
              errorMessage: row.lastErrorMessage,
            ),
      ];

  static Object? _decode(PlanVisitOutboxData row) {
    try {
      return PlanOutboxCodec.decode(
          id: row.id, planId: row.planId, kind: row.kind, payload: row.payload);
    } on FormatException {
      return null;
    }
  }

  Future<Directory> _dirFor(String stepId) async =>
      Directory('${(await _documents()).path}/plan_outbox/$stepId');

  Future<List<String>> _copyPhotos(String stepId, List<String> paths) async {
    if (paths.isEmpty) return paths;
    final dir = await _dirFor(stepId);
    await dir.create(recursive: true);
    final copies = <String>[];
    for (final (i, path) in paths.indexed) {
      final source = File(path);
      final name = path.split(RegExp(r'[/\\]')).last;
      final target = '${dir.path}/${i + 1}_$name';
      // Already ours (a resend of a saved step): keep it where it is.
      if (path == target || !await source.exists()) {
        copies.add(path);
        continue;
      }
      await source.copy(target);
      copies.add(target);
    }
    return copies;
  }

  Future<void> _deletePhotos(String stepId) async {
    final dir = await _dirFor(stepId);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
