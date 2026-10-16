part of 'geo_location_bloc.dart';

sealed class GeoLocationEvent extends Equatable {
  const GeoLocationEvent();

  @override
  List<Object?> get props => const [];
}

/// Seed the gazetteer if needed and load the province list. Emitted once when
/// the selector mounts.
final class GeoLocationStarted extends GeoLocationEvent {
  const GeoLocationStarted({this.initialAddress, this.initialCodes});

  /// An address already resolved by the host form — reused as-is.
  final GeoAddress? initialAddress;

  /// Raw codes from a saved draft or API payload, resolved and hierarchy-
  /// checked before they are trusted. Ignored when [initialAddress] is given.
  final ResolveGeoAddressParams? initialCodes;

  @override
  List<Object?> get props => [initialAddress, initialCodes];
}

/// Choose (or clear, with a null [unit]) one level.
///
/// One event for all four levels — the cascade rule is uniform, so four events
/// would be four copies of the same handler. Clearing is the same event rather
/// than its own, because "select nothing" resets its children exactly like
/// "select something else" does, and a separate event would be a second place
/// to get that right.
final class GeoLevelSelected extends GeoLocationEvent {
  const GeoLevelSelected(this.level, this.unit);

  final GeoLevel level;
  final GeoUnit? unit;

  @override
  List<Object?> get props => [level, unit];
}

/// Filter the open picker's list. [query] empty restores the full list.
final class GeoLevelSearched extends GeoLocationEvent {
  const GeoLevelSearched(this.level, this.query);

  final GeoLevel level;
  final String query;

  @override
  List<Object?> get props => [level, query];
}

/// Retry a level that failed to load (§11).
final class GeoLevelRetried extends GeoLocationEvent {
  const GeoLevelRetried(this.level);

  final GeoLevel level;

  @override
  List<Object?> get props => [level];
}

/// The rep typed a postal code, for the communes the gazetteer has none for.
final class GeoPostalCodeEntered extends GeoLocationEvent {
  const GeoPostalCodeEntered(this.value);

  final String value;

  @override
  List<Object?> get props => [value];
}

/// Clear every level (§8) — the "start over" affordance.
final class GeoLocationReset extends GeoLocationEvent {
  const GeoLocationReset();
}

/// Start showing validation errors — dispatched by
/// [GeoLocationBloc.validateForSubmission] when the host form submits.
final class GeoValidationRequested extends GeoLocationEvent {
  const GeoValidationRequested();
}
