part of 'geo_location_bloc.dart';

/// What one dropdown is currently doing (§11).
enum GeoLevelStatus {
  /// Its parent has not been chosen — the field renders disabled with a
  /// "select X first" hint.
  locked,
  loading,
  ready,
  failure,
}

/// One level's list, status and error — the whole of what a single dropdown
/// renders.
///
/// Modelled per level rather than as `isLoadingDistricts` / `districtsError` /
/// `districts` triples on a flat state (which is what the spec sketches at
/// §13). Four levels × three fields is twelve fields that must be kept
/// consistent by hand, and the reset path has to clear nine of them in the
/// right order. One object per level makes a reset an assignment.
class GeoLevelState extends Equatable {
  const GeoLevelState({
    this.status = GeoLevelStatus.locked,
    this.units = const [],
    this.query = '',
    this.failureMessage,
  });

  static const locked = GeoLevelState();

  final GeoLevelStatus status;

  /// The options to show — already narrowed by [query] when one is set.
  final List<GeoUnit> units;

  /// The live search box contents for this level's picker.
  final String query;

  final String? failureMessage;

  /// Ready, but nothing to show. Distinct from `locked`: "no districts found"
  /// is a data problem worth reporting, "select a province first" is the
  /// normal state of an untouched form, and showing one message for both is
  /// how a rep concludes the app is broken.
  bool get isEmpty => status == GeoLevelStatus.ready && units.isEmpty;

  /// True when [isEmpty] is the result of a search rather than of the level
  /// genuinely having no children — the message differs.
  bool get isEmptyBecauseOfSearch => isEmpty && query.trim().isNotEmpty;

  GeoLevelState copyWith({
    GeoLevelStatus? status,
    List<GeoUnit>? units,
    String? query,
    String? failureMessage,
    bool clearFailure = false,
  }) =>
      GeoLevelState(
        status: status ?? this.status,
        units: units ?? this.units,
        query: query ?? this.query,
        failureMessage:
            clearFailure ? null : (failureMessage ?? this.failureMessage),
      );

  @override
  List<Object?> get props => [status, units, query, failureMessage];
}

/// Whether the gazetteer itself is available. Separate from the per-level
/// states because a failed seed is not a failure of any one dropdown — it takes
/// out all four, and the retry belongs to the component, not to a level.
enum GeoSeedStatus { initial, seeding, ready, failure }

class GeoLocationState extends Equatable {
  const GeoLocationState({
    this.seedStatus = GeoSeedStatus.initial,
    this.address = GeoAddress.empty,
    this.levels = const {},
    this.requirement = GeoAddressRequirement.standard,
    this.seedFailureMessage,
    this.showValidationErrors = false,
  });

  final GeoSeedStatus seedStatus;

  /// The current selection. The single value a host form reads and submits.
  final GeoAddress address;

  final Map<GeoLevel, GeoLevelState> levels;

  final GeoAddressRequirement requirement;

  final String? seedFailureMessage;

  /// Set once the host form has tried to submit. Until then the fields show no
  /// error, so an untouched form is not a wall of red before the rep has typed
  /// anything.
  final bool showValidationErrors;

  GeoLevelState levelState(GeoLevel level) =>
      levels[level] ?? GeoLevelState.locked;

  /// Errors to display, or empty while [showValidationErrors] is false.
  List<GeoAddressError> get visibleErrors =>
      showValidationErrors ? address.validate(requirement) : const [];

  bool get isSubmittable => address.isValid(requirement);

  /// The commune has no code of its own, so the postal field must accept
  /// typing (§10 — never silently submit a wrong code).
  bool get isPostalCodeEditable => address.needsManualPostalCode;

  GeoLocationState copyWith({
    GeoSeedStatus? seedStatus,
    GeoAddress? address,
    Map<GeoLevel, GeoLevelState>? levels,
    GeoAddressRequirement? requirement,
    String? seedFailureMessage,
    bool clearSeedFailure = false,
    bool? showValidationErrors,
  }) =>
      GeoLocationState(
        seedStatus: seedStatus ?? this.seedStatus,
        address: address ?? this.address,
        levels: levels ?? this.levels,
        requirement: requirement ?? this.requirement,
        seedFailureMessage: clearSeedFailure
            ? null
            : (seedFailureMessage ?? this.seedFailureMessage),
        showValidationErrors: showValidationErrors ?? this.showValidationErrors,
      );

  @override
  List<Object?> get props => [
        seedStatus,
        address,
        levels,
        requirement,
        seedFailureMessage,
        showValidationErrors,
      ];
}
