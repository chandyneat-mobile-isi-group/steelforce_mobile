import 'package:equatable/equatable.dart';
import 'package:steelforce/features/depots/domain/entities/depot_filter.dart';

/// Which collapsible group is currently open. Exactly one at a time, so the
/// sheet stays short and the user is guided top-to-bottom instead of scrolling
/// a wall of expanded chips.
enum DepotFilterSection { status, territory, productCategory, sort }

/// Draft state for the filter sheet.
///
/// Deliberately separate from `DepotsState`: editing a draft must not
/// re-query the depot list on every tap. Only [DepotFilterSheet]'s apply
/// action pushes the draft into `DepotsBloc`, which is what keeps the list
/// from rebuilding while the user is still choosing.
class DepotFilterState extends Equatable {
  const DepotFilterState({
    required this.draft,
    required this.initial,
    this.openSection,
    this.territoryQuery = '',
  });

  const DepotFilterState.from(DepotFilter filter)
      : draft = filter,
        initial = filter,
        openSection = null,
        territoryQuery = '';

  final DepotFilter draft;

  /// The filter as it was when the sheet opened — lets the UI enable "Apply"
  /// only when something actually changed.
  final DepotFilter initial;

  final DepotFilterSection? openSection;
  final String territoryQuery;

  bool get hasChanges => draft != initial;
  bool get hasActiveFilters => !draft.isEmpty;

  /// Count shown on the sheet header and the list's filter button.
  int get activeCount => [
        draft.status != null,
        draft.territory != null,
        draft.productCategory != null,
      ].where((selected) => selected).length;

  DepotFilterState copyWith({
    DepotFilter? draft,
    DepotFilterSection? Function()? openSection,
    String? territoryQuery,
  }) {
    return DepotFilterState(
      draft: draft ?? this.draft,
      initial: initial,
      openSection: openSection != null ? openSection() : this.openSection,
      territoryQuery: territoryQuery ?? this.territoryQuery,
    );
  }

  @override
  List<Object?> get props => [draft, initial, openSection, territoryQuery];
}
