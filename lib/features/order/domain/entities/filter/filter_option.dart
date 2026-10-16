import 'package:equatable/equatable.dart';

/// One selectable value at a single level of the guided filter flow.
///
/// [value] is the canonical catalog value the next query filters on; [label] is
/// what the rep reads. [matchCount] is how many SKUs remain if this option is
/// picked — resolved by the same query that produced the option, so it costs
/// nothing extra and lets the UI show "0 results" branches before they're
/// taken (in practice options with no matches are never returned at all).
class FilterOption extends Equatable {
  const FilterOption({
    required this.value,
    required this.label,
    required this.matchCount,
  });

  final String value;
  final String label;
  final int matchCount;

  @override
  List<Object?> get props => [value, label, matchCount];
}
