import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/depots/domain/entities/depot_filter.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_filter_cubit.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_filter_state.dart';

void main() {
  group('DepotFilterCubit', () {
    test('starts with the passed filter as both draft and baseline', () {
      const initial = DepotFilter(territory: 'North');
      final cubit = DepotFilterCubit(initial);

      expect(cubit.state.draft, initial);
      expect(cubit.state.initial, initial);
      expect(cubit.state.hasChanges, isFalse);
      addTearDown(cubit.close);
    });

    blocTest<DepotFilterCubit, DepotFilterState>(
      'selecting a status marks the draft as changed',
      build: () => DepotFilterCubit(const DepotFilter()),
      act: (cubit) => cubit.selectStatus(DepotStatus.active),
      verify: (cubit) {
        expect(cubit.state.draft.status, DepotStatus.active);
        expect(cubit.state.hasChanges, isTrue);
        expect(cubit.state.activeCount, 1);
      },
    );

    blocTest<DepotFilterCubit, DepotFilterState>(
      'selecting null clears a criterion rather than being ignored',
      build: () => DepotFilterCubit(const DepotFilter(territory: 'North')),
      act: (cubit) => cubit.selectTerritory(null),
      verify: (cubit) {
        expect(cubit.state.draft.territory, isNull);
        expect(cubit.state.activeCount, 0);
      },
    );

    blocTest<DepotFilterCubit, DepotFilterState>(
      'toggling the open section twice collapses it',
      build: () => DepotFilterCubit(const DepotFilter()),
      act: (cubit) => cubit
        ..toggleSection(DepotFilterSection.status)
        ..toggleSection(DepotFilterSection.status),
      verify: (cubit) => expect(cubit.state.openSection, isNull),
    );

    blocTest<DepotFilterCubit, DepotFilterState>(
      'opening a second section replaces the first',
      build: () => DepotFilterCubit(const DepotFilter()),
      act: (cubit) => cubit
        ..toggleSection(DepotFilterSection.status)
        ..toggleSection(DepotFilterSection.territory),
      verify: (cubit) => expect(
        cubit.state.openSection,
        DepotFilterSection.territory,
      ),
    );

    blocTest<DepotFilterCubit, DepotFilterState>(
      'reset clears every criterion but preserves the chosen sort order',
      build: () => DepotFilterCubit(
        const DepotFilter(
          territory: 'North',
          status: DepotStatus.active,
          productCategory: 'Rebar',
          sortBy: DepotSortBy.nameAsc,
        ),
      ),
      act: (cubit) => cubit.reset(),
      verify: (cubit) {
        expect(cubit.state.draft.isEmpty, isTrue);
        expect(cubit.state.activeCount, 0);
        // Resetting filters is not a request to re-sort.
        expect(cubit.state.draft.sortBy, DepotSortBy.nameAsc);
        expect(cubit.state.territoryQuery, '');
        expect(cubit.state.openSection, isNull);
      },
    );

    blocTest<DepotFilterCubit, DepotFilterState>(
      'sort selection alone does not count as an active filter',
      build: () => DepotFilterCubit(const DepotFilter()),
      act: (cubit) => cubit.selectSort(DepotSortBy.valueDesc),
      verify: (cubit) {
        expect(cubit.state.hasChanges, isTrue);
        expect(cubit.state.activeCount, 0);
        expect(cubit.state.hasActiveFilters, isFalse);
      },
    );

    blocTest<DepotFilterCubit, DepotFilterState>(
      'searching territory does not alter the draft filter',
      build: () => DepotFilterCubit(const DepotFilter()),
      act: (cubit) => cubit.searchTerritory('nor'),
      verify: (cubit) {
        expect(cubit.state.territoryQuery, 'nor');
        expect(cubit.state.hasChanges, isFalse);
      },
    );
  });
}
