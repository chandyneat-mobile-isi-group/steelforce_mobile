import 'package:equatable/equatable.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/filter/category_filter_schema.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_option.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_selection.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_step.dart';
import 'package:steelforce/features/order/domain/repositories/product_filter_repository.dart';

class FilterStepOptionsParams extends Equatable {
  const FilterStepOptionsParams({
    required this.schema,
    required this.step,
    required this.selection,
  });

  final CategoryFilterSchema schema;
  final FilterStep step;
  final FilterSelection selection;

  @override
  List<Object?> get props => [schema, step, selection];
}

/// Resolves exactly one level of the flow. Called once per step the rep
/// reaches — never speculatively, and never for more than one level at a time.
class GetFilterStepOptions
    extends UseCase<List<FilterOption>, FilterStepOptionsParams> {
  const GetFilterStepOptions(this._repository);
  final ProductFilterRepository _repository;

  @override
  ResultFuture<List<FilterOption>> call(FilterStepOptionsParams params) =>
      _repository.getStepOptions(
        schema: params.schema,
        step: params.step,
        selection: params.selection,
      );
}
