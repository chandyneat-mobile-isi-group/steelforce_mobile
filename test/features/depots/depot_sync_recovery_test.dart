import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/features/depots/data/local/depot_local_data_source.dart';
import 'package:steelforce/features/depots/data/models/depot_model.dart';
import 'package:steelforce/features/depots/data/remote/depot_remote_data_source.dart';
import 'package:steelforce/features/depots/data/remote/depot_sync_page.dart';
import 'package:steelforce/features/depots/data/repositories/depot_sync_repository_impl.dart';
import 'package:steelforce/features/depots/domain/entities/depot_code_lookup.dart';
import 'package:steelforce/features/depots/domain/entities/depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';
import 'package:mocktail/mocktail.dart';

/// The two ways a synced depot book goes wrong on its own, and how it
/// recovers. Both are silent failures: nothing throws, nothing looks broken,
/// and the rep simply stops receiving correct data.
///
///  * **A poisoned watermark.** An older build could store a device-clock
///    timestamp. The server rejects a `modifiedSince` more than five minutes
///    ahead of its own clock, so every delta from then on fails identically and
///    the device never syncs again.
///
///  * **A language switch.** `shopName` is localised *server-side* against
///    `Accept-Language`, and the list summary carries no language-independent
///    name. A delta cannot repair it — `modifiedSince` returns what the server
///    changed, and changing language on the phone changes nothing there — so
///    the directory keeps rendering the language it was first synced in.
///
/// See `docs/feature/depot/mobile/get-depot.md` §The watermark rules and
/// §Local schema.
class _MockLocal extends Mock implements DepotLocalDataSource {}

class _MockNetwork extends Mock implements NetworkInfo {}

class _ScriptedRemote implements DepotRemoteDataSource {
  _ScriptedRemote({this.initial = const [], this.deltaError});

  final List<DepotInitialPage> initial;

  /// Thrown by the first `fetchDelta`, to simulate the server refusing the
  /// stored watermark.
  final Object? deltaError;

  final List<int> initialPagesRequested = [];
  final List<DateTime> deltaSinceRequested = [];

  @override
  Future<DepotInitialPage> fetchInitial({
    required int page,
    required int pageSize,
  }) async {
    initialPagesRequested.add(page);
    return initial[initialPagesRequested.length - 1];
  }

  @override
  Future<DepotDeltaPage> fetchDelta({
    required DateTime since,
    int page = 1,
    int pageSize = 200,
  }) async {
    deltaSinceRequested.add(since);
    if (deltaError != null) throw deltaError!;
    return DepotDeltaPage(
      upserted: const [],
      deletedIds: const [],
      hasMore: false,
      syncTimestamp: since,
    );
  }

  @override
  Future<DepotModel> create(DepotDraft draft) => throw UnimplementedError();

  @override
  Future<DepotModel> fetchById(String id) => throw UnimplementedError();

  @override
  Future<DepotCodeLookup> lookupByCode(String code) =>
      throw UnimplementedError('these tests exercise sync, not code lookup');
}

DepotModel _depot(String id) => DepotModel(
      id: id,
      depotCode: 'ISI-$id',
      shopName: 'Shop $id',
      ownerName: 'Owner',
      phone: '012345678',
      address: 'Street 1',
      province: 'Phnom Penh',
      district: 'Toul Kork',
      territory: 'PP-NORTH',
      latitude: 11.5,
      longitude: 104.9,
      creditLimit: 0,
      status: DepotStatus.active,
      assignedRepId: 'rep-1',
      assignedRepName: 'Rep',
      updatedAt: DateTime.utc(2026, 8, 12),
    );

void main() {
  late _MockLocal local;
  late _MockNetwork network;

  final serverTime = DateTime.utc(2026, 8, 28, 9, 44, 12);
  final storedWatermark = DateTime.utc(2026, 8, 12, 9, 44, 12);

  setUp(() {
    local = _MockLocal();
    network = _MockNetwork();
    when(() => network.isConnected).thenAnswer((_) async => true);
    when(() => local.upsertDepots(any())).thenAnswer((_) async {});
    when(() => local.markDeleted(any())).thenAnswer((_) async {});
    when(() => local.setLastSyncedAt(any(), any(),
        language: any(named: 'language'))).thenAnswer((_) async {});
    when(() => local.getLastSyncedAt(any()))
        .thenAnswer((_) async => storedWatermark);
    when(() => local.getSyncedLanguage(any())).thenAnswer((_) async => null);
  });

  DepotSyncRepositoryImpl build(
    _ScriptedRemote remote, {
    String language = 'en-US',
  }) =>
      DepotSyncRepositoryImpl(
        remote: remote,
        local: local,
        network: network,
        logger: const ConsoleAppLogger(verbose: false),
        readLanguageTag: () => language,
      );

  _ScriptedRemote oneInitialPage() => _ScriptedRemote(initial: [
        DepotInitialPage(
          items: [_depot('a')],
          hasMore: false,
          syncTimestamp: serverTime,
        ),
      ]);

  group('a rejected watermark self-heals', () {
    /// Exactly what the server sends: 400 `General.Validation` naming
    /// `modifiedSince` in the per-field errors map.
    ApiException rejectedWatermark() => ApiException(
          const ApiError(
            statusCode: 400,
            code: 'General.Validation',
            message: 'Validation failed.',
            fieldErrors: {
              'parameters.modifiedSince': [
                'modifiedSince cannot be in the future. Send the syncTimestamp '
                    'from the previous response rather than the device clock.',
              ],
            },
          ),
        );

    test('the delta falls back to a full re-page instead of failing', () async {
      final remote = _ScriptedRemote(
        initial: [
          DepotInitialPage(
            items: [_depot('a')],
            hasMore: false,
            syncTimestamp: serverTime,
          ),
        ],
        deltaError: rejectedWatermark(),
      );

      final result = await build(remote).runDeltaSync();

      expect(result.when(success: (_) => true, failure: (_) => false), isTrue,
          reason: 'left as a failure this is terminal — every later delta '
              'fails the same way and the device never syncs again');
      expect(remote.initialPagesRequested, [1],
          reason: 'the recovery is a full re-page, which rewrites the '
              'watermark from the server clock');
    });

    test('the fresh watermark comes from the server, not the bad stored one',
        () async {
      final remote = _ScriptedRemote(
        initial: [
          DepotInitialPage(
            items: [_depot('a')],
            hasMore: false,
            syncTimestamp: serverTime,
          ),
        ],
        deltaError: rejectedWatermark(),
      );

      await build(remote).runDeltaSync();

      verify(() => local.setLastSyncedAt('depots', serverTime,
          language: any(named: 'language'))).called(1);
    });

    test('an unrelated 400 is still reported, not silently re-paged', () async {
      // A blanket "400 means resync" would turn every ordinary validation
      // error into a 31-request re-page.
      final remote = _ScriptedRemote(
        initial: [
          DepotInitialPage(
              items: const [], hasMore: false, syncTimestamp: serverTime),
        ],
        deltaError: ApiException(
          const ApiError(
            statusCode: 400,
            code: 'General.Validation',
            message: 'Validation failed.',
            fieldErrors: {
              'parameters.pageSize': ['Invalid.']
            },
          ),
        ),
      );

      final result = await build(remote).runDeltaSync();

      expect(result.when(success: (_) => false, failure: (_) => true), isTrue);
      expect(remote.initialPagesRequested, isEmpty);
    });

    test('a 500 is still reported — it is transient, not a bad watermark',
        () async {
      final remote = _ScriptedRemote(
        initial: [
          DepotInitialPage(
              items: const [], hasMore: false, syncTimestamp: serverTime),
        ],
        deltaError: ApiException(
          const ApiError(statusCode: 500, code: 'Server.Error'),
        ),
      );

      final result = await build(remote).runDeltaSync();

      expect(result.when(success: (_) => false, failure: (_) => true), isTrue);
      expect(remote.initialPagesRequested, isEmpty);
    });
  });

  group('a language switch forces a full resync', () {
    test('a delta becomes a full re-page when the language changed', () async {
      when(() => local.getSyncedLanguage(any()))
          .thenAnswer((_) async => 'km-KH');
      final remote = oneInitialPage();

      await build(remote, language: 'en-US').runDeltaSync();

      expect(remote.deltaSinceRequested, isEmpty,
          reason: 'a delta cannot relocalise rows the server did not change');
      expect(remote.initialPagesRequested, [1]);
    });

    test('the new language is recorded with the new watermark', () async {
      when(() => local.getSyncedLanguage(any()))
          .thenAnswer((_) async => 'km-KH');

      await build(oneInitialPage(), language: 'en-US').runDeltaSync();

      verify(() =>
              local.setLastSyncedAt('depots', serverTime, language: 'en-US'))
          .called(1);
    });

    test('an unchanged language runs an ordinary delta', () async {
      when(() => local.getSyncedLanguage(any()))
          .thenAnswer((_) async => 'km-KH');
      final remote = _ScriptedRemote();

      await build(remote, language: 'km-KH').runDeltaSync();

      expect(remote.deltaSinceRequested, [storedWatermark]);
      expect(remote.initialPagesRequested, isEmpty);
    });

    test('an unknown stored language is treated as a match', () async {
      // Null means "synced before the language was recorded". Forcing a resync
      // would put every upgrading device through a 31-request re-page for a
      // book that is almost certainly already in the right language.
      when(() => local.getSyncedLanguage(any())).thenAnswer((_) async => null);
      final remote = _ScriptedRemote();

      await build(remote, language: 'en-US').runDeltaSync();

      expect(remote.deltaSinceRequested, [storedWatermark]);
      expect(remote.initialPagesRequested, isEmpty);
    });

    test('an initial sync records the language it fetched under', () async {
      await build(oneInitialPage(), language: 'km-KH').runInitialSync();

      verify(() =>
              local.setLastSyncedAt('depots', serverTime, language: 'km-KH'))
          .called(1);
    });
  });
}
