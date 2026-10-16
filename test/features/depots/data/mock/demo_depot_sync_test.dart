import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/depots/data/local/depot_local_data_source.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_directory.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_remote_data_source.dart';
import 'package:steelforce/features/depots/data/models/depot_model.dart';
import 'package:steelforce/features/depots/data/repositories/depot_sync_repository_impl.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/depot_sync_result.dart';

class _SilentLogger extends Mock implements AppLogger {}

class _DemoReachability implements NetworkInfo {
  _DemoReachability(this._network);
  final DemoNetwork _network;

  @override
  Future<bool> get isConnected async => _network.isOnline;
}

/// Only the sync surface; everything else would fail loudly if touched.
class _MemoryBook extends Fake implements DepotLocalDataSource {
  final Map<String, DepotModel> rows = {};
  DateTime? watermark;

  @override
  Future<void> upsertDepots(List<DepotModel> depots) async {
    for (final d in depots) {
      rows[d.id] = d;
    }
  }

  @override
  Future<void> markDeleted(List<String> ids) async => ids.forEach(rows.remove);

  @override
  Future<DateTime?> getLastSyncedAt(String entity) async => watermark;

  @override
  Future<void> setLastSyncedAt(String entity, DateTime at,
          {String? language}) async =>
      watermark = at;

  @override
  Future<String?> getSyncedLanguage(String entity) async => null;
}

/// The path a demo build takes after sign-in: the real sync repository over
/// the demo source, filling the local book the Depots screen reads.
void main() {
  late DemoNetwork network;
  late _MemoryBook book;
  late DepotSyncRepositoryImpl repository;
  late DemoDepotRemoteDataSource remote;

  setUp(() {
    network = DemoNetwork();
    book = _MemoryBook();
    remote = DemoDepotRemoteDataSource(network, DemoDepotDirectory());
    repository = DepotSyncRepositoryImpl(
      remote: remote,
      local: book,
      network: _DemoReachability(network),
      logger: _SilentLogger(),
      readLanguageTag: () => 'en',
    );
  });

  test('initial sync fills the book; a later create arrives by delta',
      () async {
    final initial = await repository.runInitialSync();
    expect(initial, isA<Success<DepotSyncResult>>());
    expect(book.rows.keys.toSet(), DemoSeed.depots.map((d) => d.id).toSet());

    final created = await repository.createDepot(const DepotDraft(
      depotCode: 'FIELD-002',
      shopName: 'Demo Delta Shop',
      type: 'Retailer',
      phone: '012 000 888',
      addressLine1: 'No. 3, Street 1986',
      city: 'Phnom Penh',
    ));
    expect(created, isA<Success<Depot>>());
    book.rows.clear();

    final delta = await repository.runDeltaSync();
    expect(delta, isA<Success<DepotSyncResult>>());
    expect(book.rows.values.map((d) => d.shopName), ['Demo Delta Shop']);
  });

  test('switching the demo offline yields a NetworkFailure, not a crash',
      () async {
    network.setOnline(false);

    final result = await repository.runInitialSync();

    expect(
      result,
      isA<Failed<DepotSyncResult>>()
          .having((r) => r.failure, 'failure', isA<NetworkFailure>()),
    );
  });
}
