import 'package:equatable/equatable.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';

enum DepotSortBy { recentOrder, nameAsc, nearest, valueDesc }

class DepotFilter extends Equatable {
  const DepotFilter({
    this.territory,
    this.status,
    this.productCategory,
    this.sortBy = DepotSortBy.recentOrder,
  });

  final String? territory;
  final DepotStatus? status;
  final String? productCategory;
  final DepotSortBy sortBy;

  bool get isEmpty =>
      territory == null && status == null && productCategory == null;

  DepotFilter copyWith({
    String? Function()? territory,
    DepotStatus? Function()? status,
    String? Function()? productCategory,
    DepotSortBy? sortBy,
  }) {
    return DepotFilter(
      territory: territory != null ? territory() : this.territory,
      status: status != null ? status() : this.status,
      productCategory:
          productCategory != null ? productCategory() : this.productCategory,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  @override
  List<Object?> get props => [territory, status, productCategory, sortBy];
}
