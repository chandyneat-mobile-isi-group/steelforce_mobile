import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_address.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_unit.dart';
import 'package:steelforce/features/geo_location/domain/usecases/ensure_geo_data_ready.dart';
import 'package:steelforce/features/geo_location/domain/usecases/get_geo_children.dart';
import 'package:steelforce/features/geo_location/domain/usecases/resolve_geo_address.dart';
import 'package:steelforce/features/geo_location/domain/usecases/search_geo_units.dart';

part 'geo_location_event.dart';
part 'geo_location_state.dart';

/// Drives the cascade for one address form.
///
/// ## One bloc per selector, not one per app
///
/// Registered as a factory. A quotation screen that captures a billing address
/// and a delivery address needs two independent cascades, and a singleton would
/// make changing the billing province clear the delivery village.
///
/// ## Where the cascade rule lives
///
/// Not here. [GeoAddress.select] clears the deeper levels, and this bloc's job
/// is to notice which levels changed and reload their lists. That split is what
/// makes the reset testable without a bloc and impossible to get half-right in
/// one place and not the other — see `geo_address_test.dart`.
class GeoLocationBloc extends Bloc<GeoLocationEvent, GeoLocationState> {
  GeoLocationBloc({
    required EnsureGeoDataReady ensureReady,
    required GetGeoChildren getChildren,
    required SearchGeoUnits searchUnits,
    required ResolveGeoAddress resolveAddress,
    GeoAddressRequirement requirement = GeoAddressRequirement.standard,
  })  : _ensureReady = ensureReady,
        _getChildren = getChildren,
        _searchUnits = searchUnits,
        _resolveAddress = resolveAddress,
        super(GeoLocationState(requirement: requirement)) {
    on<GeoLocationStarted>(_onStarted);
    on<GeoLevelSelected>(_onLevelSelected);
    // `restartable`: each keystroke supersedes the last, so a slow query for
    // "Ph" cannot land after "Phnom" and repopulate the list with the wrong
    // results. `droppable` would drop the newest keystroke, which is the one
    // the rep is looking at.
    on<GeoLevelSearched>(_onLevelSearched, transformer: restartable());
    on<GeoLevelRetried>(_onLevelRetried);
    on<GeoPostalCodeEntered>(_onPostalCodeEntered);
    on<GeoLocationReset>(_onReset);
    on<GeoValidationRequested>(
      (_, emit) => emit(state.copyWith(showValidationErrors: true)),
    );
  }

  final EnsureGeoDataReady _ensureReady;
  final GetGeoChildren _getChildren;
  final SearchGeoUnits _searchUnits;
  final ResolveGeoAddress _resolveAddress;

  Future<void> _onStarted(
    GeoLocationStarted event,
    Emitter<GeoLocationState> emit,
  ) async {
    emit(state.copyWith(
      seedStatus: GeoSeedStatus.seeding,
      clearSeedFailure: true,
    ));

    final seeded = await _ensureReady(const NoParams());
    final seedFailure = seeded.when(
      success: (_) => null,
      failure: (f) => f.message,
    );
    if (seedFailure != null) {
      emit(state.copyWith(
        seedStatus: GeoSeedStatus.failure,
        seedFailureMessage: seedFailure,
      ));
      return;
    }

    // Restore any prior selection before loading lists, so the lists that get
    // loaded are the ones the restored address actually needs.
    var address = event.initialAddress ?? GeoAddress.empty;
    if (event.initialAddress == null && event.initialCodes != null) {
      final resolved = await _resolveAddress(event.initialCodes!);
      address = resolved.when(
        success: (a) => a,
        // A resolve failure is not fatal: the rep gets an empty cascade and
        // re-picks, which beats blocking the form on reference data.
        failure: (_) => GeoAddress.empty,
      );
    }

    emit(state.copyWith(seedStatus: GeoSeedStatus.ready, address: address));
    await _loadLevelsFor(address, emit);
  }

  /// Loads every level that [address] can currently show: always the provinces,
  /// then one level below each selection.
  Future<void> _loadLevelsFor(
    GeoAddress address,
    Emitter<GeoLocationState> emit,
  ) async {
    await _loadLevel(GeoLevel.province, null, emit);
    // Walk down from the province, stopping at the first level with no
    // selection: below that point there is no parent to load children for, and
    // the field is legitimately locked.
    for (final level in GeoLevel.values) {
      final selected = address.unitAt(level);
      if (selected == null) break;
      final childIndex = level.index + 1;
      if (childIndex >= GeoLevel.values.length) break;
      await _loadLevel(GeoLevel.values[childIndex], selected.code, emit);
    }
  }

  Future<void> _loadLevel(
    GeoLevel level,
    String? parentCode,
    Emitter<GeoLocationState> emit, {
    String query = '',
  }) async {
    emit(_withLevel(
      level,
      state.levelState(level).copyWith(
            status: GeoLevelStatus.loading,
            query: query,
            clearFailure: true,
          ),
    ));

    final result = query.trim().isEmpty
        ? await _getChildren(
            GetGeoChildrenParams(level: level, parentCode: parentCode))
        : await _searchUnits(SearchGeoUnitsParams(
            level: level, parentCode: parentCode, query: query));

    emit(result.when(
      success: (units) => _withLevel(
        level,
        GeoLevelState(
          status: GeoLevelStatus.ready,
          units: units,
          query: query,
        ),
      ),
      failure: (f) => _withLevel(
        level,
        state.levelState(level).copyWith(
              status: GeoLevelStatus.failure,
              failureMessage: f.message,
              query: query,
            ),
      ),
    ));
  }

  Future<void> _onLevelSelected(
    GeoLevelSelected event,
    Emitter<GeoLocationState> emit,
  ) async {
    // The whole cascading reset, delegated to the entity (§8).
    final address = state.address.select(event.level, event.unit);

    // Every level below the one just changed is now stale — locked and emptied
    // in one pass rather than three named assignments, so adding a fifth level
    // needs no change here.
    final levels = Map<GeoLevel, GeoLevelState>.from(state.levels);
    for (final deeper in event.level.deeperLevels) {
      levels[deeper] = GeoLevelState.locked;
    }

    emit(state.copyWith(address: address, levels: levels));

    // Load the immediate child only. Loading grandchildren would be loading
    // lists for a level the rep cannot reach yet, and the cascade will ask for
    // them when they pick.
    final child = event.level.index + 1 < GeoLevel.values.length
        ? GeoLevel.values[event.level.index + 1]
        : null;
    if (child == null || event.unit == null) return;
    await _loadLevel(child, event.unit!.code, emit);
  }

  Future<void> _onLevelSearched(
    GeoLevelSearched event,
    Emitter<GeoLocationState> emit,
  ) async {
    final parent = event.level.parent;
    final parentCode =
        parent == null ? null : state.address.unitAt(parent)?.code;
    // Locked — there is no parent to scope the search to.
    if (parent != null && parentCode == null) return;
    await _loadLevel(event.level, parentCode, emit, query: event.query);
  }

  Future<void> _onLevelRetried(
    GeoLevelRetried event,
    Emitter<GeoLocationState> emit,
  ) async {
    // A retry after a failed seed has to redo the seed, not the level — the
    // level failed because there was nothing to read.
    if (state.seedStatus == GeoSeedStatus.failure) {
      add(GeoLocationStarted(initialAddress: state.address));
      return;
    }
    final parent = event.level.parent;
    final parentCode =
        parent == null ? null : state.address.unitAt(parent)?.code;
    if (parent != null && parentCode == null) return;
    await _loadLevel(
      event.level,
      parentCode,
      emit,
      query: state.levelState(event.level).query,
    );
  }

  void _onPostalCodeEntered(
    GeoPostalCodeEntered event,
    Emitter<GeoLocationState> emit,
  ) {
    emit(state.copyWith(
      address: state.address.withManualPostalCode(event.value),
    ));
  }

  Future<void> _onReset(
    GeoLocationReset event,
    Emitter<GeoLocationState> emit,
  ) async {
    emit(state.copyWith(
      address: GeoAddress.empty,
      levels: const {},
      showValidationErrors: false,
    ));
    await _loadLevel(GeoLevel.province, null, emit);
  }

  /// Marks the form as submitted so the fields start showing their errors, and
  /// reports whether it is actually submittable.
  ///
  /// The answer is returned synchronously — a host form calls this inside its
  /// own `onSubmit` and has to decide immediately whether to proceed. That is
  /// sound because [GeoLocationState.isSubmittable] is derived from the address
  /// already in `state`; the dispatched event only flips the flag that makes
  /// the errors visible, which is a rendering concern and can land next frame.
  bool validateForSubmission() {
    add(const GeoValidationRequested());
    return state.isSubmittable;
  }

  GeoLocationState _withLevel(GeoLevel level, GeoLevelState levelState) {
    return state.copyWith(
      levels: {...state.levels, level: levelState},
    );
  }
}
