import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/features/depots/data/local/master_data_cache.dart';
import 'package:steelforce/features/depots/data/remote/master_data_remote_data_source.dart';
import 'package:steelforce/features/depots/data/repositories/master_data_repository_impl.dart';
import 'package:steelforce/features/depots/domain/entities/master_data_item.dart';
import 'package:steelforce/features/depots/domain/entities/master_data_type.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements MasterDataRemoteDataSource {}

class _MockCache extends Mock implements MasterDataCache {}

class _MockNetwork extends Mock implements NetworkInfo {}

const _type = MasterDataType.salesOrg;
const _rows = [
  MasterDataItem(code: '1000', name: 'Sales Org Cambodia'),
  MasterDataItem(code: '2000', name: 'Sales Org Export'),
];
const _staleRows = [MasterDataItem(code: '9000', name: 'Old Org')];

void main() {
  late _MockRemote remote;
  late _MockCache cache;
  late _MockNetwork network;
  late MasterDataRepositoryImpl repository;

  setUpAll(() => registerFallbackValue(_type));

  setUp(() {
    remote = _MockRemote();
    cache = _MockCache();
    network = _MockNetwork();
    repository = MasterDataRepositoryImpl(
      remote: remote,
      cache: cache,
      network: network,
    );

    when(() => cache.write(any(), any())).thenAnswer((_) async {});
    when(() => cache.cachedAt(any())).thenReturn(null);
    when(() => cache.readStale(any())).thenReturn(null);
  });

  group('fetch', () {
    test('online, the API is read even when a fresh copy is cached', () async {
      // Online-first: a cached list never stands in for the server while the
      // device can reach it.
      when(() => cache.readFresh(_type)).thenReturn(const []);
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => remote.fetch(_type)).thenAnswer((_) async => _rows);

      final result = await repository.fetch(_type);

      expect(result.items, _rows);
      expect(result.fromCache, isFalse);
      verify(() => remote.fetch(_type)).called(1);
    });

    test('a cache miss while online fetches remotely and writes the cache',
        () async {
      when(() => cache.readFresh(_type)).thenReturn(null);
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => remote.fetch(_type)).thenAnswer((_) async => _rows);

      final result = await repository.fetch(_type);

      expect(result.items, _rows);
      expect(result.fromCache, isFalse);
      expect(result.isStale, isFalse);
      verify(() => cache.write(_type, _rows)).called(1);
    });

    test('offline with a stale copy serves it, flagged as stale', () async {
      when(() => cache.readFresh(_type)).thenReturn(null);
      when(() => cache.readStale(_type)).thenReturn(_staleRows);
      when(() => network.isConnected).thenAnswer((_) async => false);

      final result = await repository.fetch(_type);

      expect(result.items, _staleRows);
      expect(result.isStale, isTrue);
      expect(result.fromCache, isTrue);
      verifyNever(() => remote.fetch(any()));
    });

    test('offline with no cache at all throws NetworkFailure', () async {
      when(() => cache.readFresh(_type)).thenReturn(null);
      when(() => cache.readStale(_type)).thenReturn(null);
      when(() => network.isConnected).thenAnswer((_) async => false);

      expect(() => repository.fetch(_type), throwsA(isA<NetworkFailure>()));
    });

    test('a remote failure falls back to stale rather than surfacing an error',
        () async {
      when(() => cache.readFresh(_type)).thenReturn(null);
      when(() => cache.readStale(_type)).thenReturn(_staleRows);
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => remote.fetch(_type)).thenThrow(
        const ServerFailure(message: 'SAP unavailable', statusCode: 500),
      );

      final result = await repository.fetch(_type);

      expect(result.items, _staleRows);
      expect(result.isStale, isTrue);
    });

    test('a remote failure with no cached copy rethrows the typed failure',
        () async {
      when(() => cache.readFresh(_type)).thenReturn(null);
      when(() => cache.readStale(_type)).thenReturn(null);
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => remote.fetch(_type)).thenThrow(
        const ServerFailure(message: 'SAP unavailable', statusCode: 500),
      );

      expect(() => repository.fetch(_type), throwsA(isA<ServerFailure>()));
    });
  });

  group('refresh', () {
    test('bypasses a fresh cache and re-reads from the network', () async {
      when(() => cache.readFresh(_type)).thenReturn(_rows);
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => remote.fetch(_type)).thenAnswer((_) async => _rows);

      final result = await repository.refresh(_type);

      expect(result.fromCache, isFalse);
      verify(() => remote.fetch(_type)).called(1);
      verify(() => cache.write(_type, _rows)).called(1);
      // Fresh cache must not short-circuit an *explicit* refresh.
      verifyNever(() => cache.readFresh(any()));
    });
  });
}
