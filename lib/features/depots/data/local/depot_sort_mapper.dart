import 'package:steelforce/core/database/drift/daos/depot_dao.dart';
import 'package:steelforce/features/depots/domain/entities/depot_filter.dart';

/// Maps the feature's sort enum onto the DAO's decoupled equivalent.
extension DepotSortMapper on DepotSortBy {
  DepotBrowseSort toBrowseSort() => switch (this) {
        DepotSortBy.recentOrder => DepotBrowseSort.recentOrder,
        DepotSortBy.nameAsc => DepotBrowseSort.nameAsc,
        DepotSortBy.nearest => DepotBrowseSort.nearest,
        DepotSortBy.valueDesc => DepotBrowseSort.valueDesc,
      };
}
