import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/order/domain/entities/sales_order.dart';
import 'package:steelforce/features/order/domain/entities/sales_order_status.dart';
import 'package:steelforce/features/order/domain/usecases/watch_sales_orders.dart';
import 'package:steelforce/features/order/presentation/bloc/sales_order/sales_order_list_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/sales_order/sales_order_list_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchSalesOrders extends Mock implements WatchSalesOrders {}

SalesOrder _order(
  String id, {
  required SalesOrderStatus status,
  required DateTime createdAt,
  double total = 100,
}) =>
    SalesOrder(
      id: id,
      quotationId: 'q-$id',
      lines: const [],
      subtotal: total,
      discount: 0,
      tax: 0,
      total: total,
      status: status,
      sapStatus: 'PENDING',
      createdAt: createdAt,
      shopName: 'Shop $id',
    );

void main() {
  late _MockWatchSalesOrders watchSalesOrders;

  final older = _order('SO-1',
      status: SalesOrderStatus.pending,
      createdAt: DateTime(2026, 8, 1),
      total: 50);
  final newer = _order('SO-2',
      status: SalesOrderStatus.confirmed,
      createdAt: DateTime(2026, 8, 20),
      total: 150);

  setUpAll(() => registerFallbackValue(const NoParams()));
  setUp(() => watchSalesOrders = _MockWatchSalesOrders());

  void streams(List<SalesOrder> orders) => when(() => watchSalesOrders(any()))
      .thenAnswer((_) => Stream.value(orders));

  SalesOrderListCubit build(
          {SalesOrderFilter initialFilter = SalesOrderFilter.all}) =>
      SalesOrderListCubit(
          watchSalesOrders: watchSalesOrders, initialFilter: initialFilter);

  group('loading the list', () {
    blocTest<SalesOrderListCubit, SalesOrderListState>(
      'emits the orders newest first',
      setUp: () => streams([older, newer]),
      build: build,
      expect: () => [
        isA<SalesOrderListLoaded>().having(
            (s) => s.orders.map((o) => o.id).toList(),
            'order',
            ['SO-2', 'SO-1']),
      ],
    );

    blocTest<SalesOrderListCubit, SalesOrderListState>(
      'an empty database is a loaded empty list, not an error',
      setUp: () => streams(const []),
      build: build,
      expect: () => [
        isA<SalesOrderListLoaded>()
            .having((s) => s.isEmpty, 'isEmpty', true)
            .having((s) => s.totalCount, 'totalCount', 0),
      ],
    );

    blocTest<SalesOrderListCubit, SalesOrderListState>(
      'a stream error becomes a state, never an uncaught throw',
      setUp: () => when(() => watchSalesOrders(any()))
          .thenAnswer((_) => Stream.error(StateError('db gone'))),
      build: build,
      expect: () => [isA<SalesOrderListError>()],
    );
  });

  group('counts and totals', () {
    blocTest<SalesOrderListCubit, SalesOrderListState>(
      'counts describe the whole set regardless of the active filter',
      setUp: () => streams([older, newer]),
      build: () => build(initialFilter: SalesOrderFilter.pending),
      verify: (cubit) {
        final state = cubit.state as SalesOrderListLoaded;
        expect(state.totalCount, 2);
        expect(state.pendingCount, 1);
        expect(state.confirmedCount, 1);
        // …while the visible list is narrowed.
        expect(state.visibleOrders.map((o) => o.id), ['SO-1']);
      },
    );

    blocTest<SalesOrderListCubit, SalesOrderListState>(
      'the visible total covers only the filtered orders',
      setUp: () => streams([older, newer]),
      build: () => build(initialFilter: SalesOrderFilter.confirmed),
      verify: (cubit) {
        final state = cubit.state as SalesOrderListLoaded;
        // Not 200: including the pending order here would overstate committed
        // revenue, which is the one figure on this screen nobody should have
        // to re-check.
        expect(state.visibleTotal, 150);
      },
    );
  });

  group('filtering', () {
    blocTest<SalesOrderListCubit, SalesOrderListState>(
      'an initial filter survives the first snapshot',
      setUp: () => streams([older, newer]),
      build: () => build(initialFilter: SalesOrderFilter.pending),
      expect: () => [
        // The regression: the filter used to live only in the state, which
        // starts as Loading — so the first emission reset it to `all` and the
        // caller's choice was silently dropped.
        isA<SalesOrderListLoaded>()
            .having((s) => s.filter, 'filter', SalesOrderFilter.pending),
      ],
    );

    test('setFilter narrows an already-loaded list', () async {
      // Driven off an explicit controller rather than `blocTest`'s `act`:
      // `act` runs before a `Stream.value` has delivered, so the cubit would
      // still be Loading and the test would be asserting the initial-filter
      // path instead of the narrowing one.
      final controller = StreamController<List<SalesOrder>>();
      addTearDown(controller.close);
      when(() => watchSalesOrders(any())).thenAnswer((_) => controller.stream);

      final cubit = build();
      addTearDown(cubit.close);

      controller.add([older, newer]);
      await Future<void>.delayed(Duration.zero);
      expect((cubit.state as SalesOrderListLoaded).visibleOrders.length, 2);

      cubit.setFilter(SalesOrderFilter.confirmed);

      final state = cubit.state as SalesOrderListLoaded;
      expect(state.visibleOrders.map((o) => o.id), ['SO-2']);
      // The unfiltered set is retained so the counts stay honest.
      expect(state.orders.length, 2);
    });

    blocTest<SalesOrderListCubit, SalesOrderListState>(
      're-selecting the active filter emits nothing',
      setUp: () => streams([older, newer]),
      build: build,
      act: (cubit) => cubit.setFilter(SalesOrderFilter.all),
      skip: 1,
      expect: () => const <SalesOrderListState>[],
    );

    test('the active filter survives a new snapshot from the stream', () async {
      // A row changing underneath the rep must not yank them out of the list
      // they were working through.
      final controller = StreamController<List<SalesOrder>>();
      addTearDown(controller.close);
      when(() => watchSalesOrders(any())).thenAnswer((_) => controller.stream);

      final cubit = build();
      addTearDown(cubit.close);

      controller.add([older, newer]);
      await Future<void>.delayed(Duration.zero);
      cubit.setFilter(SalesOrderFilter.pending);

      controller.add([
        older,
        newer,
        _order('SO-3',
            status: SalesOrderStatus.confirmed,
            createdAt: DateTime(2026, 8, 21))
      ]);
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as SalesOrderListLoaded;
      expect(state.filter, SalesOrderFilter.pending);
      expect(state.totalCount, 3);
      expect(state.visibleOrders.map((o) => o.id), ['SO-1']);
    });
  });
}
