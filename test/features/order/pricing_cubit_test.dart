import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/mobile_price.dart';
import 'package:steelforce/features/order/domain/repositories/pricing_repository.dart';
import 'package:steelforce/features/order/domain/usecases/get_depot_material_prices.dart';
import 'package:steelforce/features/order/presentation/bloc/pricing/pricing_cubit.dart';

class _FakePricingRepository implements PricingRepository {
  final List<List<String>> requests = [];
  Map<String, double?> priceBook = {};

  /// Overrides keyed by depot, so a test can assert that switching account
  /// actually re-prices rather than re-showing the previous figure.
  Map<String, Map<String, double?>> perDepot = {};
  Failure? failure;

  @override
  ResultFuture<List<MobilePrice>> getPrices({
    required String depotId,
    required List<String> materials,
  }) async {
    requests.add(List.of(materials));
    final f = failure;
    if (f != null) return Failed(f);
    final book = perDepot[depotId] ?? priceBook;
    return Success([
      for (final material in materials)
        if (book[material] == null)
          MobilePrice(
            material: material,
            state: PricingState.unavailable,
            errorKind: PricingErrorKind.noPrice,
          )
        else
          MobilePrice(
            material: material,
            state: PricingState.loaded,
            price: book[material],
            currency: 'USD',
          ),
    ]);
  }
}

class _FakeRealtime implements PricingRealtimeSource {
  final updatesController = StreamController<MobilePrice>.broadcast();
  final reconnectController = StreamController<void>.broadcast();
  final List<String> subscribed = [];
  int unsubscribeCount = 0;

  @override
  Stream<MobilePrice> get updates => updatesController.stream;
  @override
  Stream<void> get reconnections => reconnectController.stream;
  @override
  bool get isConnected => true;
  @override
  Future<void> subscribe(String depotId) async => subscribed.add(depotId);
  @override
  Future<void> unsubscribe() async => unsubscribeCount++;
  @override
  Future<void> dispose() async {
    await updatesController.close();
    await reconnectController.close();
  }
}

void main() {
  late _FakePricingRepository repo;
  late _FakeRealtime realtime;
  late PricingCubit cubit;

  setUp(() {
    repo = _FakePricingRepository();
    realtime = _FakeRealtime();
    cubit = PricingCubit(
      getPrices: GetDepotMaterialPrices(repo),
      realtime: realtime,
    );
  });

  tearDown(() async {
    await cubit.close();
    await realtime.dispose();
  });

  group('fetching', () {
    test('batches every material into one request', () async {
      // The endpoint takes a repeatable `materials` parameter precisely so a
      // quotation with three lines is one round trip, not three.
      repo.priceBook = {'A': 100, 'B': 250, 'C': 75};
      await cubit.setDepot('cust_1');
      await cubit.track(['A', 'B', 'C']);

      expect(repo.requests, hasLength(1));
      expect(repo.requests.single, ['A', 'B', 'C']);
      expect(cubit.of('B')?.price, 250);
    });

    test('does not re-ask for a material already priced', () async {
      repo.priceBook = {'A': 100, 'B': 250};
      await cubit.setDepot('cust_1');
      await cubit.track(['A']);
      await cubit.track(['A', 'B']);

      expect(repo.requests, hasLength(2));
      expect(repo.requests.last, ['B'], reason: 'only the new line');
    });

    test('one unpriced material does not disturb the others', () async {
      // The failure-isolation rule: a quotation shows four independent states.
      repo.priceBook = {'A': 100, 'B': null, 'C': 75};
      await cubit.setDepot('cust_1');
      await cubit.track(['A', 'B', 'C']);

      expect(cubit.of('A')?.state, PricingState.loaded);
      expect(cubit.of('B')?.state, PricingState.unavailable);
      expect(cubit.of('C')?.state, PricingState.loaded);
    });

    test('a walk-in is unavailable, not an error', () async {
      // Nothing is wrong and nothing is retryable — there is simply no
      // depot to price against.
      await cubit.setDepot(null);
      await cubit.track(['A']);

      expect(cubit.of('A')?.state, PricingState.unavailable);
      expect(cubit.of('A')?.isRetryable, isFalse);
      expect(repo.requests, isEmpty, reason: 'nothing to ask');
    });

    test('a failure never substitutes a local price', () async {
      repo.failure = const ServerFailure(message: 'boom');
      await cubit.setDepot('cust_1');
      await cubit.track(['A']);

      expect(cubit.of('A')?.state, PricingState.error);
      expect(cubit.of('A')?.price, isNull);
    });
  });

  group('retrying one card', () {
    test('re-asks for that material only', () async {
      // The point of a per-card retry: a rep retrying one failed line must not
      // put the seven prices that answered fine back into a spinner.
      repo.priceBook = {'A': 100, 'B': 250, 'C': 75};
      await cubit.setDepot('cust_1');
      await cubit.track(['A', 'B', 'C']);
      repo.requests.clear();

      await cubit.retry('B');

      expect(repo.requests.single, ['B']);
      expect(cubit.of('A')?.price, 100, reason: 'untouched by the retry');
      expect(cubit.of('C')?.price, 75, reason: 'untouched by the retry');
    });

    test('a failed price becomes real once the retry succeeds', () async {
      repo.failure = const ServerFailure(message: 'boom');
      await cubit.setDepot('cust_1');
      await cubit.track(['A']);
      expect(cubit.of('A')?.state, PricingState.error);

      repo.failure = null;
      repo.priceBook = {'A': 100};
      await cubit.retry('A');

      expect(cubit.of('A')?.state, PricingState.loaded);
      expect(cubit.of('A')?.price, 100);
    });

    test('a material no longer on the quotation is not re-fetched', () async {
      // A retry racing a line removal must not resurrect the card.
      repo.priceBook = {'A': 100};
      await cubit.setDepot('cust_1');
      await cubit.track(['A']);
      cubit.untrack('A');
      repo.requests.clear();

      await cubit.retry('A');

      expect(repo.requests, isEmpty);
      expect(cubit.of('A'), isNull);
    });
  });

  group('realtime updates', () {
    setUp(() async {
      repo.priceBook = {'A': 100, 'B': 250};
      await cubit.setDepot('cust_1');
      await cubit.track(['A', 'B']);
    });

    test('updates only the material the event names', () async {
      realtime.updatesController.add(MobilePrice(
        material: 'B',
        state: PricingState.updated,
        price: 275,
        currency: 'USD',
        updatedAt: DateTime.utc(2026, 6, 1, 10),
      ));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.of('B')?.price, 275);
      expect(cubit.of('A')?.price, 100, reason: 'untouched');
    });

    test('an older event cannot walk the price backwards', () async {
      final newer = DateTime.utc(2026, 6, 1, 12);
      final older = DateTime.utc(2026, 6, 1, 9);

      realtime.updatesController.add(MobilePrice(
        material: 'A',
        state: PricingState.updated,
        price: 300,
        currency: 'USD',
        updatedAt: newer,
      ));
      await Future<void>.delayed(Duration.zero);
      realtime.updatesController.add(MobilePrice(
        material: 'A',
        state: PricingState.updated,
        price: 111,
        currency: 'USD',
        updatedAt: older,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.of('A')?.price, 300,
          reason: 'a delayed packet must not overwrite a newer price');
    });

    test('ignores a material the quotation is not tracking', () async {
      realtime.updatesController.add(MobilePrice(
        material: 'ZZZ',
        state: PricingState.updated,
        price: 9,
        currency: 'USD',
        updatedAt: DateTime.utc(2026, 6, 1),
      ));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.of('ZZZ'), isNull);
    });
  });

  group('reconnection', () {
    test('re-subscribes and re-fetches over REST', () async {
      // Group membership does not survive a drop and the hub does not replay,
      // so re-subscribing alone would leave a stale price on screen.
      repo.priceBook = {'A': 100};
      await cubit.setDepot('cust_1');
      await cubit.track(['A']);
      final before = repo.requests.length;

      realtime.reconnectController.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(repo.requests.length, before + 1, reason: 'REST re-fetch');
      expect(realtime.subscribed.where((c) => c == 'cust_1').length, 2);
    });

    test('a dropped connection makes held prices stale, not gone', () async {
      repo.priceBook = {'A': 100};
      await cubit.setDepot('cust_1');
      await cubit.track(['A']);

      cubit.markStale();

      // The figure stays — a rep mid-conversation should not watch it vanish —
      // but it stops claiming to be live.
      expect(cubit.of('A')?.price, 100);
      expect(cubit.of('A')?.isStale, isTrue);
      expect(cubit.of('A')?.isLive, isFalse);
    });
  });

  group('depot context', () {
    test('switching depot unsubscribes before subscribing', () async {
      await cubit.setDepot('cust_1');
      await cubit.setDepot('cust_2');

      expect(realtime.unsubscribeCount, greaterThanOrEqualTo(2));
      expect(realtime.subscribed, ['cust_1', 'cust_2']);
    });

    test('switching depot re-prices rather than keeping the old figure',
        () async {
      // Prices are quoted per depot. Leaving the previous shop's figure on
      // screen would be both wrong and a disclosure.
      repo.perDepot = {
        'cust_1': {'A': 100},
        'cust_2': {'A': 180},
      };
      await cubit.setDepot('cust_1');
      await cubit.track(['A']);
      expect(cubit.of('A')?.price, 100);

      await cubit.setDepot('cust_2');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(cubit.of('A')?.price, 180);
    });
  });
}
