import 'package:equatable/equatable.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_option.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_selection.dart';
import 'package:steelforce/features/order/domain/repositories/product_filter_repository.dart';

class StockLocationOptionsParams extends Equatable {
  const StockLocationOptionsParams({
    required this.categoryId,
    required this.selection,
  });

  final String? categoryId;
  final FilterSelection selection;

  @override
  List<Object?> get props => [categoryId, selection];
}

/// Which stock locations can supply the SKUs the rep has narrowed to.
///
/// Runs once the hierarchy resolves to products, not per keystroke: it costs
/// one grouped read over an indexed column and returns a handful of codes, so
/// it stays inside the flow's "never page the catalog to answer a question"
/// rule.
class GetStockLocationOptions
    extends UseCase<List<FilterOption>, StockLocationOptionsParams> {
  const GetStockLocationOptions(this._repository);

  final ProductFilterRepository _repository;

  @override
  ResultFuture<List<FilterOption>> call(StockLocationOptionsParams params) =>
      _repository.getStockLocationOptions(
        categoryId: params.categoryId,
        selection: params.selection,
      );
}
