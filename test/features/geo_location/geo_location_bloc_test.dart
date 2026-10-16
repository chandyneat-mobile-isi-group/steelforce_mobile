import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_address.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_unit.dart';
import 'package:steelforce/features/geo_location/domain/usecases/ensure_geo_data_ready.dart';
import 'package:steelforce/features/geo_location/domain/usecases/get_geo_children.dart';
import 'package:steelforce/features/geo_location/domain/usecases/resolve_geo_address.dart';
import 'package:steelforce/features/geo_location/domain/usecases/search_geo_units.dart';
import 'package:steelforce/features/geo_location/presentation/bloc/geo_location_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _MockEnsureReady extends Mock implements EnsureGeoDataReady {}

class _MockGetChildren extends Mock implements GetGeoChildren {}

class _MockSearch extends Mock implements SearchGeoUnits {}

class _MockResolve extends Mock implements ResolveGeoAddress {}

GeoUnit _u(GeoLevel level, String code, String en, {String? postal}) => GeoUnit(
      level: level,
      code: code,
      name: LocalizedText(en: en, km: en),
      unit: 'Unit',
      postalCode: postal,
    );

final _pp = _u(GeoLevel.province, '12', 'Phnom Penh');
final _kandal = _u(GeoLevel.province, '08', 'Kandal');
final _chamkarMon = _u(GeoLevel.district, '1201', 'Chamkar Mon');
final _tonleBasak =
    _u(GeoLevel.commune, '120101', 'Tonle Basak', postal: '120101');
final _village = _u(GeoLevel.village, '12010101', 'Ou Thum');

void main() {
  late _MockEnsureReady ensureReady;
  late _MockGetChildren getChildren;
  late _MockSearch search;
  late _MockResolve resolve;

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const GetGeoChildrenParams(level: GeoLevel.province));
    registerFallbackValue(
        const SearchGeoUnitsParams(level: GeoLevel.province, query: ''));
    registerFallbackValue(const ResolveGeoAddressParams());
  });

  setUp(() {
    ensureReady = _MockEnsureReady();
    getChildren = _MockGetChildren();
    search = _MockSearch();
    resolve = _MockResolve();

    when(() => ensureReady(any())).thenAnswer((_) async => const Success(null));

    // Each level answers with its own fixture, so a wrongly-scoped request is
    // visible in the resulting state rather than silently returning the same
    // list for everything.
    when(() => getChildren(any())).thenAnswer((invocation) async {
      final p = invocation.positionalArguments.first as GetGeoChildrenParams;
      return Success(switch (p.level) {
        GeoLevel.province => [_pp, _kandal],
        GeoLevel.district => [_chamkarMon],
        GeoLevel.commune => [_tonleBasak],
        GeoLevel.village => [_village],
      });
    });
  });

  GeoLocationBloc build({
    GeoAddressRequirement requirement = GeoAddressRequirement.standard,
  }) =>
      GeoLocationBloc(
        ensureReady: ensureReady,
        getChildren: getChildren,
        searchUnits: search,
        resolveAddress: resolve,
        requirement: requirement,
      );

  group('startup', () {
    blocTest<GeoLocationBloc, GeoLocationState>(
      'seeds, then loads the provinces and locks everything below',
      build: build,
      act: (b) => b.add(const GeoLocationStarted()),
      verify: (b) {
        expect(b.state.seedStatus, GeoSeedStatus.ready);
        expect(
            b.state.levelState(GeoLevel.province).status, GeoLevelStatus.ready);
        expect(b.state.levelState(GeoLevel.province).units.length, 2);
        expect(b.state.levelState(GeoLevel.district).status,
            GeoLevelStatus.locked);
        expect(
            b.state.levelState(GeoLevel.village).status, GeoLevelStatus.locked);
      },
    );

    blocTest<GeoLocationBloc, GeoLocationState>(
      'a failed seed reports failure and does not load any level',
      build: () {
        when(() => ensureReady(any())).thenAnswer(
          (_) async => const Failed(CacheFailure(message: 'asset missing')),
        );
        return build();
      },
      act: (b) => b.add(const GeoLocationStarted()),
      verify: (b) {
        expect(b.state.seedStatus, GeoSeedStatus.failure);
        expect(b.state.seedFailureMessage, 'asset missing');
        verifyNever(() => getChildren(any()));
      },
    );

    blocTest<GeoLocationBloc, GeoLocationState>(
      'restores a saved address and loads every level it needs',
      build: () {
        when(() => resolve(any())).thenAnswer(
          (_) async => Success(GeoAddress(
            province: _pp,
            district: _chamkarMon,
            commune: _tonleBasak,
          )),
        );
        return build();
      },
      act: (b) => b.add(const GeoLocationStarted(
        initialCodes: ResolveGeoAddressParams(
          provinceCode: '12',
          districtCode: '1201',
          communeCode: '120101',
        ),
      )),
      verify: (b) {
        expect(b.state.address.commune, _tonleBasak);
        // Provinces, districts and communes are populated; villages too, since
        // a commune is selected.
        expect(
            b.state.levelState(GeoLevel.district).status, GeoLevelStatus.ready);
        expect(
            b.state.levelState(GeoLevel.village).status, GeoLevelStatus.ready);
      },
    );

    blocTest<GeoLocationBloc, GeoLocationState>(
      'a failed resolve leaves an empty cascade rather than blocking the form',
      build: () {
        when(() => resolve(any())).thenAnswer(
          (_) async => const Failed(CacheFailure(message: 'bad codes')),
        );
        return build();
      },
      act: (b) => b.add(const GeoLocationStarted(
        initialCodes: ResolveGeoAddressParams(provinceCode: '12'),
      )),
      verify: (b) {
        expect(b.state.seedStatus, GeoSeedStatus.ready);
        expect(b.state.address, GeoAddress.empty);
        expect(b.state.levelState(GeoLevel.province).units, isNotEmpty);
      },
    );
  });

  group('cascade (§8)', () {
    blocTest<GeoLocationBloc, GeoLocationState>(
      'selecting a province loads its districts and leaves the rest locked',
      build: build,
      act: (b) async {
        b.add(const GeoLocationStarted());
        await Future<void>.delayed(Duration.zero);
        b.add(GeoLevelSelected(GeoLevel.province, _pp));
      },
      verify: (b) {
        expect(b.state.address.province, _pp);
        expect(
            b.state.levelState(GeoLevel.district).status, GeoLevelStatus.ready);
        expect(
            b.state.levelState(GeoLevel.commune).status, GeoLevelStatus.locked);
      },
    );

    blocTest<GeoLocationBloc, GeoLocationState>(
      'changing the province clears every child selection and relocks them',
      build: build,
      act: (b) async {
        b.add(const GeoLocationStarted());
        await Future<void>.delayed(Duration.zero);
        b.add(GeoLevelSelected(GeoLevel.province, _pp));
        await Future<void>.delayed(Duration.zero);
        b.add(GeoLevelSelected(GeoLevel.district, _chamkarMon));
        await Future<void>.delayed(Duration.zero);
        b.add(GeoLevelSelected(GeoLevel.commune, _tonleBasak));
        await Future<void>.delayed(Duration.zero);
        b.add(GeoLevelSelected(GeoLevel.village, _village));
        await Future<void>.delayed(Duration.zero);

        // …and now the rep realises they picked the wrong province.
        b.add(GeoLevelSelected(GeoLevel.province, _kandal));
      },
      verify: (b) {
        expect(b.state.address.province, _kandal);
        expect(b.state.address.district, isNull);
        expect(b.state.address.commune, isNull);
        expect(b.state.address.village, isNull);
        expect(b.state.address.postalCode, isNull);

        expect(
            b.state.levelState(GeoLevel.commune).status, GeoLevelStatus.locked);
        expect(b.state.levelState(GeoLevel.commune).units, isEmpty,
            reason: 'a stale list under a new parent is as bad as a stale '
                'selection');
        expect(
            b.state.levelState(GeoLevel.village).status, GeoLevelStatus.locked);
      },
    );

    blocTest<GeoLocationBloc, GeoLocationState>(
      'selecting a commune derives the postal code',
      build: build,
      act: (b) async {
        b.add(const GeoLocationStarted());
        await Future<void>.delayed(Duration.zero);
        b.add(GeoLevelSelected(GeoLevel.province, _pp));
        await Future<void>.delayed(Duration.zero);
        b.add(GeoLevelSelected(GeoLevel.district, _chamkarMon));
        await Future<void>.delayed(Duration.zero);
        b.add(GeoLevelSelected(GeoLevel.commune, _tonleBasak));
      },
      verify: (b) {
        expect(b.state.address.postalCode, '120101');
        expect(b.state.address.isPostalCodeDerived, isTrue);
        expect(b.state.isPostalCodeEditable, isFalse);
      },
    );

    blocTest<GeoLocationBloc, GeoLocationState>(
      'a commune with no postal code unlocks the field for manual entry',
      build: build,
      act: (b) async {
        b.add(const GeoLocationStarted());
        await Future<void>.delayed(Duration.zero);
        b.add(GeoLevelSelected(GeoLevel.province, _pp));
        await Future<void>.delayed(Duration.zero);
        b.add(GeoLevelSelected(GeoLevel.district, _chamkarMon));
        await Future<void>.delayed(Duration.zero);
        b.add(GeoLevelSelected(
            GeoLevel.commune, _u(GeoLevel.commune, '120199', 'Uncovered')));
        await Future<void>.delayed(Duration.zero);
        b.add(const GeoPostalCodeEntered('120199'));
      },
      verify: (b) {
        expect(b.state.isPostalCodeEditable, isTrue);
        expect(b.state.address.postalCode, '120199');
        expect(b.state.address.isPostalCodeDerived, isFalse);
      },
    );

    blocTest<GeoLocationBloc, GeoLocationState>(
      'clearing a level relocks its children',
      build: build,
      act: (b) async {
        b.add(const GeoLocationStarted());
        await Future<void>.delayed(Duration.zero);
        b.add(GeoLevelSelected(GeoLevel.province, _pp));
        await Future<void>.delayed(Duration.zero);
        b.add(const GeoLevelSelected(GeoLevel.province, null));
      },
      verify: (b) {
        expect(b.state.address.province, isNull);
        expect(b.state.levelState(GeoLevel.district).status,
            GeoLevelStatus.locked);
      },
    );

    blocTest<GeoLocationBloc, GeoLocationState>(
      'reset clears everything and reloads the provinces',
      build: build,
      act: (b) async {
        b.add(const GeoLocationStarted());
        await Future<void>.delayed(Duration.zero);
        b.add(GeoLevelSelected(GeoLevel.province, _pp));
        await Future<void>.delayed(Duration.zero);
        b.add(const GeoLocationReset());
      },
      verify: (b) {
        expect(b.state.address, GeoAddress.empty);
        expect(
            b.state.levelState(GeoLevel.province).status, GeoLevelStatus.ready);
        expect(b.state.levelState(GeoLevel.district).status,
            GeoLevelStatus.locked);
      },
    );
  });

  group('errors and retry (§11)', () {
    blocTest<GeoLocationBloc, GeoLocationState>(
      'a failed level load surfaces on that level only',
      build: () {
        when(() => getChildren(any())).thenAnswer((invocation) async {
          final p =
              invocation.positionalArguments.first as GetGeoChildrenParams;
          if (p.level == GeoLevel.district) {
            return const Failed(CacheFailure(message: 'boom'));
          }
          return Success(p.level == GeoLevel.province ? [_pp] : const []);
        });
        return build();
      },
      act: (b) async {
        b.add(const GeoLocationStarted());
        await Future<void>.delayed(Duration.zero);
        b.add(GeoLevelSelected(GeoLevel.province, _pp));
      },
      verify: (b) {
        expect(b.state.levelState(GeoLevel.district).status,
            GeoLevelStatus.failure);
        expect(b.state.levelState(GeoLevel.district).failureMessage, 'boom');
        expect(
            b.state.levelState(GeoLevel.province).status, GeoLevelStatus.ready);
      },
    );

    blocTest<GeoLocationBloc, GeoLocationState>(
      'retrying a failed level reloads it',
      build: () {
        var firstCall = true;
        when(() => getChildren(any())).thenAnswer((invocation) async {
          final p =
              invocation.positionalArguments.first as GetGeoChildrenParams;
          if (p.level == GeoLevel.district && firstCall) {
            firstCall = false;
            return const Failed(CacheFailure(message: 'boom'));
          }
          return Success(switch (p.level) {
            GeoLevel.province => [_pp],
            GeoLevel.district => [_chamkarMon],
            _ => const <GeoUnit>[],
          });
        });
        return build();
      },
      act: (b) async {
        b.add(const GeoLocationStarted());
        await Future<void>.delayed(Duration.zero);
        b.add(GeoLevelSelected(GeoLevel.province, _pp));
        await Future<void>.delayed(Duration.zero);
        b.add(const GeoLevelRetried(GeoLevel.district));
      },
      verify: (b) {
        expect(
            b.state.levelState(GeoLevel.district).status, GeoLevelStatus.ready);
        expect(b.state.levelState(GeoLevel.district).units, [_chamkarMon]);
      },
    );

    blocTest<GeoLocationBloc, GeoLocationState>(
      'retrying after a failed seed re-runs the seed, not the level',
      build: () {
        var firstSeed = true;
        when(() => ensureReady(any())).thenAnswer((_) async {
          if (firstSeed) {
            firstSeed = false;
            return const Failed(CacheFailure(message: 'asset missing'));
          }
          return const Success(null);
        });
        return build();
      },
      act: (b) async {
        b.add(const GeoLocationStarted());
        await Future<void>.delayed(Duration.zero);
        b.add(const GeoLevelRetried(GeoLevel.province));
      },
      wait: const Duration(milliseconds: 50),
      verify: (b) {
        expect(b.state.seedStatus, GeoSeedStatus.ready);
        expect(b.state.levelState(GeoLevel.province).units, isNotEmpty);
      },
    );

    blocTest<GeoLocationBloc, GeoLocationState>(
      'an empty level is ready-and-empty, not locked',
      build: () {
        when(() => getChildren(any())).thenAnswer((invocation) async {
          final p =
              invocation.positionalArguments.first as GetGeoChildrenParams;
          return Success(
              p.level == GeoLevel.province ? [_pp] : const <GeoUnit>[]);
        });
        return build();
      },
      act: (b) async {
        b.add(const GeoLocationStarted());
        await Future<void>.delayed(Duration.zero);
        b.add(GeoLevelSelected(GeoLevel.province, _pp));
      },
      verify: (b) {
        final district = b.state.levelState(GeoLevel.district);
        expect(district.status, GeoLevelStatus.ready);
        expect(district.isEmpty, isTrue);
        expect(district.isEmptyBecauseOfSearch, isFalse);
      },
    );
  });

  group('search (§7)', () {
    blocTest<GeoLocationBloc, GeoLocationState>(
      'narrows a level and records the query',
      build: () {
        when(() => search(any())).thenAnswer((_) async => Success([_pp]));
        return build();
      },
      act: (b) async {
        b.add(const GeoLocationStarted());
        await Future<void>.delayed(Duration.zero);
        b.add(const GeoLevelSearched(GeoLevel.province, 'Phnom'));
      },
      verify: (b) {
        final level = b.state.levelState(GeoLevel.province);
        expect(level.units, [_pp]);
        expect(level.query, 'Phnom');
      },
    );

    blocTest<GeoLocationBloc, GeoLocationState>(
      'a search with no matches is distinguished from an empty level',
      build: () {
        when(() => search(any()))
            .thenAnswer((_) async => const Success(<GeoUnit>[]));
        return build();
      },
      act: (b) async {
        b.add(const GeoLocationStarted());
        await Future<void>.delayed(Duration.zero);
        b.add(const GeoLevelSearched(GeoLevel.province, 'zzzz'));
      },
      verify: (b) {
        final level = b.state.levelState(GeoLevel.province);
        expect(level.isEmpty, isTrue);
        expect(level.isEmptyBecauseOfSearch, isTrue);
      },
    );

    blocTest<GeoLocationBloc, GeoLocationState>(
      'searching a locked level is a no-op',
      build: build,
      act: (b) async {
        b.add(const GeoLocationStarted());
        await Future<void>.delayed(Duration.zero);
        b.add(const GeoLevelSearched(GeoLevel.village, 'anything'));
      },
      verify: (b) {
        expect(
            b.state.levelState(GeoLevel.village).status, GeoLevelStatus.locked);
        verifyNever(() => search(any()));
      },
    );
  });

  group('validation (§10)', () {
    blocTest<GeoLocationBloc, GeoLocationState>(
      'errors stay hidden until the form is submitted',
      build: build,
      act: (b) => b.add(const GeoLocationStarted()),
      verify: (b) {
        expect(b.state.visibleErrors, isEmpty);
        expect(b.state.isSubmittable, isFalse);
      },
    );

    blocTest<GeoLocationBloc, GeoLocationState>(
      'validateForSubmission reveals the errors and reports not-submittable',
      build: build,
      act: (b) async {
        b.add(const GeoLocationStarted());
        await Future<void>.delayed(Duration.zero);
        expect(b.validateForSubmission(), isFalse);
      },
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(b.state.showValidationErrors, isTrue);
        expect(
            b.state.visibleErrors, contains(GeoAddressError.missingProvince));
      },
    );

    blocTest<GeoLocationBloc, GeoLocationState>(
      'a complete address is submittable',
      build: build,
      act: (b) async {
        b.add(const GeoLocationStarted());
        await Future<void>.delayed(Duration.zero);
        b.add(GeoLevelSelected(GeoLevel.province, _pp));
        await Future<void>.delayed(Duration.zero);
        b.add(GeoLevelSelected(GeoLevel.district, _chamkarMon));
        await Future<void>.delayed(Duration.zero);
        b.add(GeoLevelSelected(GeoLevel.commune, _tonleBasak));
        await Future<void>.delayed(Duration.zero);
        expect(b.validateForSubmission(), isTrue);
      },
      wait: const Duration(milliseconds: 20),
      verify: (b) => expect(b.state.visibleErrors, isEmpty),
    );

    blocTest<GeoLocationBloc, GeoLocationState>(
      'a delivery address is not submittable without a village',
      build: () => build(requirement: GeoAddressRequirement.delivery),
      act: (b) async {
        b.add(const GeoLocationStarted());
        await Future<void>.delayed(Duration.zero);
        b.add(GeoLevelSelected(GeoLevel.province, _pp));
        await Future<void>.delayed(Duration.zero);
        b.add(GeoLevelSelected(GeoLevel.district, _chamkarMon));
        await Future<void>.delayed(Duration.zero);
        b.add(GeoLevelSelected(GeoLevel.commune, _tonleBasak));
        await Future<void>.delayed(Duration.zero);
        expect(b.validateForSubmission(), isFalse);
      },
      wait: const Duration(milliseconds: 20),
      verify: (b) => expect(
        b.state.visibleErrors,
        contains(GeoAddressError.missingVillage),
      ),
    );
  });
}
