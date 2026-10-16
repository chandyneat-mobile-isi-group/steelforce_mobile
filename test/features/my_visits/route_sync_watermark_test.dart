import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/features/my_visits/data/local/route_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/models/depot_stop_info_model.dart';
import 'package:steelforce/features/my_visits/data/models/route_plan_model.dart';
import 'package:steelforce/features/my_visits/data/remote/route_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/route_sync_page.dart';
import 'package:steelforce/features/my_visits/data/repositories/route_sync_repository_impl.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_sync_scope.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

/// The delta pull sends the stored watermark as `since`, and the API now
/// rejects a `since` more than five minutes in the future with a 400
/// (`api.md` §5.2). This repository used to store `DateTime.now()` — the
/// *device* clock — so a handset running fast poisoned its own watermark and
/// every later delta failed. Before the API started rejecting it, the same bug
/// was worse and quieter: the server answered an empty page, the client stored
/// that timestamp, and the route feed silently never synced again.
///
/// `generatedAt` is the server's own clock and is on every response. These
/// tests hold the client to using it.
class _AlwaysOnline implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

class _StubRemote implements RouteRemoteDataSource {
  _StubRemote({this.generatedAt, this.pages = 1});

  final DateTime? generatedAt;
  final int pages;

  /// Every `since` this source was asked for, so a test can assert what the
  /// next pull would actually send.
  final List<DateTime> sinceSeen = [];

  RouteSyncPage _page({required bool hasMore, DateTime? at}) => RouteSyncPage(
        depots: const <DepotStopInfoModel>[],
        routes: const <RoutePlanModel>[],
        hasMore: hasMore,
        generatedAt: at ?? generatedAt,
      );

  @override
  Future<RouteSyncPage> fetchInitial({
    required RouteSyncScope scope,
    required int page,
    required int pageSize,
  }) async =>
      // Each page carries a slightly later clock, so "the last page wins" is
      // observable rather than incidental.
      _page(
        hasMore: page < pages - 1,
        at: generatedAt?.add(Duration(minutes: page)),
      );

  @override
  Future<RouteSyncPage> fetchDelta({
    required RouteSyncScope scope,
    required DateTime since,
  }) async {
    sinceSeen.add(since);
    return _page(hasMore: false);
  }
}

class _FakeLocal implements RouteLocalDataSource {
  DateTime? watermark;

  @override
  Future<DateTime?> getLastSyncedAt(String entity) async => watermark;

  @override
  Future<void> setLastSyncedAt(String entity, DateTime at) async =>
      watermark = at;

  @override
  Future<void> upsertDepots(List<DepotStopInfoModel> depots) async {}
  @override
  Future<void> upsertRoutes(List<RoutePlanModel> routes) async {}
  @override
  Future<List<RoutePlanModel>> fetchTodayRoutes() async => const [];
  @override
  Future<List<RoutePlanModel>> fetchAllRoutes() async => const [];
  @override
  Future<RoutePlanModel?> getRoute(String routeId) async => null;
  @override
  Future<void> updateRouteStatus(String routeId, RouteStatus status) async {}
  @override
  Future<void> updateStopStatus(String stopId,
      {required VisitStatus status,
      DateTime? actualArrival,
      DateTime? actualDeparture}) async {}
}

void main() {
  const scope = RouteSyncScope(repId: 'rep-1', territory: 'PP-NORTH');

  /// Far enough ahead to be outside the API's five-minute skew allowance.
  final deviceClockRunningFast = DateTime.now().add(const Duration(hours: 2));

  /// Relative to now, not a fixed literal. The point of the last assertion
  /// below is "the watermark is not in the future", and a hardcoded instant
  /// silently stops testing that the moment the wall clock passes it — which
  /// is exactly what happened when this was `DateTime.utc(2026, 9, 8, 8, 41)`.
  final serverClock =
      DateTime.now().toUtc().subtract(const Duration(minutes: 10));

  ({RouteSyncRepositoryImpl repo, _FakeLocal local, _StubRemote remote}) build({
    DateTime? generatedAt,
    int pages = 1,
    DateTime? existingWatermark,
  }) {
    final remote = _StubRemote(generatedAt: generatedAt, pages: pages);
    final local = _FakeLocal()..watermark = existingWatermark;
    return (
      repo: RouteSyncRepositoryImpl(
          remote: remote, local: local, network: _AlwaysOnline()),
      local: local,
      remote: remote,
    );
  }

  group('initial sync', () {
    test('stores the server clock, not the device clock', () async {
      final t = build(generatedAt: serverClock);

      await t.repo.runInitialSync(scope);

      expect(t.local.watermark, serverClock);
    });

    test('the last page read wins across pagination', () async {
      // Three pages, each a minute later. The newest view of the server clock
      // is the one worth keeping; anything changed mid-pagination is caught by
      // the next delta.
      final t = build(generatedAt: serverClock, pages: 3);

      await t.repo.runInitialSync(scope);

      expect(t.local.watermark, serverClock.add(const Duration(minutes: 2)));
    });

    test('falls back to the device clock when the feed omits generatedAt',
        () async {
      // Old behaviour, kept on purpose: a mocked or older feed should still
      // advance its watermark rather than re-running an initial sync forever.
      final before = DateTime.now();
      final t = build(generatedAt: null);

      await t.repo.runInitialSync(scope);

      expect(t.local.watermark, isNotNull);
      expect(t.local.watermark!.isBefore(before), isFalse);
    });
  });

  group('delta sync', () {
    test('sends the stored watermark as since', () async {
      final t = build(generatedAt: serverClock, existingWatermark: serverClock);

      await t.repo.runDeltaSync(scope);

      expect(t.remote.sinceSeen, [serverClock]);
    });

    test('advances the watermark to the server clock', () async {
      final later = serverClock.add(const Duration(hours: 1));
      final t = build(generatedAt: later, existingWatermark: serverClock);

      await t.repo.runDeltaSync(scope);

      expect(t.local.watermark, later);
    });

    test('a fast device clock cannot poison the next since', () async {
      // The regression. The repository used to write `DateTime.now()` here, so
      // a handset two hours fast sent a future `since` on every later delta —
      // a 400 today, and a permanent silent stall before the API rejected it.
      final t = build(
        generatedAt: serverClock,
        existingWatermark: deviceClockRunningFast,
      );

      await t.repo.runDeltaSync(scope);

      expect(t.local.watermark, serverClock,
          reason: 'the server clock must replace a poisoned watermark');
      expect(t.local.watermark!.isAfter(DateTime.now()), isFalse,
          reason: 'a stored watermark in the future 400s on the next pull');
    });

    test('with no watermark yet it runs an initial sync instead', () async {
      final t = build(generatedAt: serverClock);

      await t.repo.runDeltaSync(scope);

      expect(t.remote.sinceSeen, isEmpty);
      expect(t.local.watermark, serverClock);
    });
  });
}
