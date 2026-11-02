import 'package:equatable/equatable.dart';
import 'package:steelforce/features/depots/domain/entities/depot_list_kind.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';

enum DepotSortBy { recentOrder, nameAsc, nearest, valueDesc }

class DepotFilter extends Equatable {
  const DepotFilter({
    this.territory,
    this.status,
    this.productCategory,
    this.province,
    this.channel,
    this.sortBy = DepotSortBy.recentOrder,
    this.kind = DepotListKind.depot,
  });

  final String? territory;
  final DepotStatus? status;
  final String? productCategory;

  /// The region: the province the depot's address ends with.
  final String? province;

  /// The type: the depot's distribution channel ("Distributor", …).
  final String? channel;
  final DepotSortBy sortBy;

  /// Which list is shown — depots, Non-BP depots or awaiting approval. Not a
  /// filter the rep sets in the sheet, so [isEmpty] ignores it.
  final DepotListKind kind;

  bool get isEmpty =>
      territory == null &&
      status == null &&
      productCategory == null &&
      province == null &&
      channel == null;

  /// How many criteria are set — the Advanced Filters badge.
  int get activeCount => [territory, status, productCategory, province, channel]
      .where((c) => c != null)
      .length;

  DepotFilter copyWith({
    String? Function()? territory,
    DepotStatus? Function()? status,
    String? Function()? productCategory,
    String? Function()? province,
    String? Function()? channel,
    DepotSortBy? sortBy,
    DepotListKind? kind,
  }) {
    return DepotFilter(
      territory: territory != null ? territory() : this.territory,
      status: status != null ? status() : this.status,
      productCategory:
          productCategory != null ? productCategory() : this.productCategory,
      province: province != null ? province() : this.province,
      channel: channel != null ? channel() : this.channel,
      sortBy: sortBy ?? this.sortBy,
      kind: kind ?? this.kind,
    );
  }

  @override
  List<Object?> get props =>
      [territory, status, productCategory, province, channel, sortBy, kind];
}
