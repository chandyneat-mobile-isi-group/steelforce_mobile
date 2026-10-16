import 'package:equatable/equatable.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_step.dart';

/// The filter hierarchy one product category exposes, exactly as SAP defines
/// it. Nothing about the order or the composition of [steps] is decided by the
/// app — Palm walks Profile → Family → Thickness → Colour → Length while Rebar
/// walks Diameter → Grade → Length purely because the two schemas differ.
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
