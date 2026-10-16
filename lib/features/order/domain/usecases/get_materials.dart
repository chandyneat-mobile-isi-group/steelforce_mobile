import 'package:equatable/equatable.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_selection.dart';
import 'package:steelforce/features/order/domain/entities/paged_result.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';
import 'package:steelforce/features/order/domain/repositories/product_filter_repository.dart';

class GetMaterialsParams extends Equatable {
  const GetMaterialsParams({
    required this.categoryCode,
    required this.selection,
    required this.page,
    required this.pageSize,
    this.search = '',
    this.sortBy = ProductSortBy.relevance,
    this.availableOnly = false,
    this.warehouseCode,
  });

  final String? categoryCode;
  final FilterSelection selection;

  /// One-based, like every other paged mobile endpoint.
  final int page;
  final int pageSize;
  final String search;

  /// Result-set preferences from the Filter sheet. They re-run the query but
  /// never invalidate an answered step.
  final ProductSortBy sortBy;
  final bool availableOnly;
  final String? warehouseCode;

  /// Whether this request narrows anything at all.
  ///
  /// Mirrors the server's rule exactly: one answered step, or two characters of
  /// search. A category on its own is not narrowing — checked here, in the
  /// domain, so both the bloc's gate and any future caller read the same
  /// definition rather than each re-deriving it.
  bool get isBounded => selection.hasAnswer || search.trim().length >= 2;

  @override
  List<Object?> get props => [
        categoryCode,
        selection,
        page,
        pageSize,
        search,
        sortBy,
        availableOnly,
        warehouseCode,
      ];
}

/// The terminal read of the guided flow — the only call in the feature that
/// returns material rows, and the only one that can.
///
/// Everything above it trades in option labels and counts measured in bytes.
/// This one is paged, and it refuses to run unbounded.
class GetMaterials extends UseCase<PagedResult<Product>, GetMaterialsParams> {
  const GetMaterials(this._repository);
  final ProductFilterRepository _repository;

  @override
  ResultFuture<PagedResult<Product>> call(GetMaterialsParams params) =>
      _repository.getMaterials(
        categoryCode: params.categoryCode,
        selection: params.selection,
        page: params.page,
        pageSize: params.pageSize,
        search: params.search,
        sortBy: params.sortBy,
        availableOnly: params.availableOnly,
        warehouseCode: params.warehouseCode,
      );
}
