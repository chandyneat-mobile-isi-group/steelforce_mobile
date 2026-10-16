import 'package:equatable/equatable.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_step.dart';

/// The filter hierarchy one product category exposes, exactly as SAP defines
/// it. Nothing about the order or the composition of [steps] is decided by the
/// app — Palm Profile walks Profile → Coating → Gauge → Colour while traded
/// reinforcement walks Product → Mill → Grade → Diameter, purely because the
/// two schemas differ.
///
/// Step counts differ too, and callers must not assume a floor: K-Pipe and
/// traded beams expose two steps, because SAP holds no brand or grade
/// variation on those lines and a one-option step is a wasted tap. A widget
/// that hard-codes "four steps" or indexes past [steps].length will break on
/// exactly those two categories.
class CategoryFilterSchema extends Equatable {
  const CategoryFilterSchema({
    required this.categoryId,
    required this.categoryName,
    required this.steps,
  });

  /// A category SAP has published no schema for. The flow degrades to
  /// "category → products" rather than blocking the rep.
  const CategoryFilterSchema.flat({
    required this.categoryId,
    required this.categoryName,
  }) : steps = const [];

  final String categoryId;
  final String categoryName;

  /// In presentation order. Callers can rely on this being sorted by
  /// [FilterStep.sortOrder] — the data layer sorts once, on the way in.
  final List<FilterStep> steps;

  bool get isFlat => steps.isEmpty;

  FilterStep? stepByKey(String key) {
    for (final step in steps) {
      if (step.key == key) return step;
    }
    return null;
  }

  /// Every step that must carry a value before products may be requested.
  List<FilterStep> get requiredSteps =>
      steps.where((step) => step.isRequired).toList(growable: false);

  @override
  List<Object?> get props => [categoryId, categoryName, steps];
}
