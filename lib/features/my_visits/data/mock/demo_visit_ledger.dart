/// TODO(release-gate): demo-only, selected only when DataSourceMode.useMocks.
///
/// The demo backend's memory of what happened on each stop.
///
/// The real server is one database seen through several endpoints: a check-in
/// posted online, the same row arriving later in a `/push` batch, and the next
/// route pull all agree. The demo data sources share this ledger so they agree
/// too — a stop checked in while "offline" reads as checked in on the route
/// delta that follows the drain.
///
/// In memory only. A restart forgets it, which costs the demo the server-side
/// copy of earlier visits; the device's own Drift copy is unaffected.
library;

import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_repository_impl.dart';

/// Every stop id the demo issues starts with this, on route fixtures and ad
/// hoc stops alike, so "is this one of our stops" survives a restart.
const String kDemoStopIdPrefix = 'demo-stop-';

class DemoVisitLedger {
  DemoVisitLedger({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, _Visit> _visits = {};

  /// Ad hoc stops by `clientRequestId`, each with the UTC day it belongs to.
  final Map<String, ({String day, DataMap stop})> _adHoc = {};

  /// Every capture row id a push has acknowledged.
  final Set<String> _pushedIds = {};

  DateTime now() => _clock();

  bool isKnownStop(String stopId) => stopId.startsWith(kDemoStopIdPrefix);

  bool hasVisit(String stopId) => _visits.containsKey(stopId);

  Set<String> get pushedIds => Set.unmodifiable(_pushedIds);

  void rememberPushed(Iterable<String> ids) => _pushedIds.addAll(ids);

  /// Records a check-in and returns the server's `VisitDto` for the stop.
  ///
  /// [strict] is the online endpoint, which refuses conflicts with the
  /// documented 409s; the `/push` path accepts and keeps the server's copy
  /// (`check-in-check-out-mobile.md` §4, §9).
  DataMap checkIn({
    required String id,
    required String stopId,
    required DateTime timestamp,
    String? overrideReason,
    bool isMocked = false,
    bool strict = true,
  }) {
    _requireStop(stopId);
    final existing = _visits[stopId];
    if (existing != null && existing.checkInId != id) {
      if (strict) {
        throw _conflict(
          existing.isClosed
              ? VisitErrorCodes.alreadyCompleted
              : VisitErrorCodes.alreadyCheckedIn,
          stopId,
        );
      }
      return visitDto(stopId);
    }
    if (existing == null) {
      _closeOtherOpenVisits(except: stopId);
      _visits[stopId] = _Visit(
        checkInId: id,
        checkedInAt: timestamp.toUtc(),
        receivedAt: now().toUtc(),
        flagged: isMocked || overrideReason != null,
        overrideReason: overrideReason,
      );
    }
    return visitDto(stopId);
  }

  /// Records a check-out. A check-out whose check-in never arrived is still
  /// accepted, as the real server does, and carries `checkOutBeforeCheckIn`.
  DataMap checkOut({
    required String id,
    required String stopId,
    required DateTime timestamp,
    required int durationMinutes,
    String? checkInId,
    String? outcome,
    String? noOrderReason,
    bool strict = true,
  }) {
    _requireStop(stopId);
    final visit = _visits.putIfAbsent(
      stopId,
      () => _Visit(
        checkInId: checkInId,
        receivedAt: now().toUtc(),
        issues: const ['checkOutBeforeCheckIn'],
      ),
    );
    if (visit.checkOutId != null && visit.checkOutId != id) {
      if (strict) throw _conflict(VisitErrorCodes.alreadyCheckedOut, stopId);
      return visitDto(stopId);
    }
    visit
      ..checkOutId = id
      ..checkedOutAt = timestamp.toUtc()
      ..durationMinutes = durationMinutes
      ..outcome = outcome ?? 'unknown'
      ..noOrderReason = noOrderReason;
    return visitDto(stopId);
  }

  /// The execution fields a route pull carries for [stopId], or null when the
  /// server has nothing on it.
  ({String status, String? arrival, String? departure})? execution(
      String stopId) {
    final v = _visits[stopId];
    if (v == null) return null;
    return (
      status: v.isClosed ? 'checkedOut' : 'checkedIn',
      arrival: v.checkedInAt?.toIso8601String(),
      departure: v.checkedOutAt?.toIso8601String(),
    );
  }

  ({String day, DataMap stop})? adHocFor(String clientRequestId) =>
      _adHoc[clientRequestId];

  void addAdHoc(String clientRequestId, String day, DataMap stop) =>
      _adHoc[clientRequestId] = (day: day, stop: stop);

  /// Ad hoc stops on [day] (`YYYY-MM-DD`, UTC), oldest first.
  List<DataMap> adHocStopsOn(String day) => [
        for (final entry in _adHoc.values)
          if (entry.day == day) entry.stop,
      ];

  /// The `VisitDto` (`check-in-check-out-mobile.md` §8) for [stopId].
  DataMap visitDto(String stopId) {
    final v = _visits[stopId];
    if (v == null) {
      return {
        'visitId': null,
        'stopId': stopId,
        'status': 'pending',
        'checkIn': null,
        'checkOut': null,
        'updatedAt': now().toUtc().toIso8601String(),
      };
    }
    return {
      'visitId': v.checkInId,
      'stopId': stopId,
      'status': v.isClosed ? 'checkedOut' : 'checkedIn',
      'checkIn': v.checkedInAt == null
          ? null
          : {
              'id': v.checkInId,
              'timestamp': v.checkedInAt!.toIso8601String(),
              'receivedAt': v.receivedAt.toIso8601String(),
              'geofence': 'inside',
              'flagged': v.flagged,
              'overrideReason': v.overrideReason,
              'photoIds': const <String>[],
            },
      'checkOut': !v.isClosed
          ? null
          : {
              'id': v.checkOutId,
              'timestamp': v.checkedOutAt!.toIso8601String(),
              'receivedAt': now().toUtc().toIso8601String(),
              'durationMinutes': v.durationMinutes,
              'outcome': v.outcome,
              'orders': const <DataMap>[],
              'noOrderReason': v.noOrderReason,
              'noOrderNote': null,
              'departureInferred': v.checkOutId == null,
              'issues': v.issues,
            },
      'updatedAt': now().toUtc().toIso8601String(),
    };
  }

  void _requireStop(String stopId) {
    if (isKnownStop(stopId)) return;
    throw const ApiException(ApiError(
      code: VisitErrorCodes.stopNotFound,
      statusCode: 404,
      message: 'This stop is not on your routes.',
    ));
  }

  ApiException _conflict(String code, String stopId) => ApiException(
        ApiError(code: code, statusCode: 409, details: visitDto(stopId)),
      );

  /// The server closes a stop left open when the rep checks in elsewhere,
  /// as an inferred departure (`check-in-check-out-mobile.md` §4).
  void _closeOtherOpenVisits({required String except}) {
    for (final entry in _visits.entries) {
      if (entry.key == except || entry.value.isClosed) continue;
      entry.value
        ..checkedOutAt = now().toUtc()
        ..outcome = 'unknown'
        ..inferred = true;
    }
  }
}

class _Visit {
  _Visit({
    required this.checkInId,
    required this.receivedAt,
    this.checkedInAt,
    this.flagged = false,
    this.overrideReason,
    this.issues = const [],
  });

  final String? checkInId;
  final DateTime? checkedInAt;
  final DateTime receivedAt;
  final bool flagged;
  final String? overrideReason;
  final List<String> issues;

  String? checkOutId;
  DateTime? checkedOutAt;
  int durationMinutes = 0;
  String? outcome;
  String? noOrderReason;
  bool inferred = false;

  bool get isClosed => checkOutId != null || inferred;
}
