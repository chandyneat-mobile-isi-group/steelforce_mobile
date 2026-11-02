import 'package:steelforce/core/database/drift/daos/depot_dao.dart';
import 'package:steelforce/features/depots/data/local/depot_drift_mappers.dart';
import 'package:steelforce/features/depots/data/local/depot_sort_mapper.dart';
import 'package:steelforce/features/depots/domain/entities/depot_filter.dart';
import 'package:steelforce/features/depots/data/models/depot_model.dart';

/// A page of the depot list, read from the database.
extension DepotPageReader on DepotDao {
  /// One page of [filter]'s list. List cards show no contacts, so none are
  /// read here; the details screen reads its depot's own.
  Future<List<DepotModel>> browsePage({
    required int page,
    required int pageSize,
    required String query,
    required DepotFilter filter,
  }) async =>
      [
        for (final row in await browse(
          page: page,
          pageSize: pageSize,
          query: query,
          territory: filter.territory,
          status: filter.status?.name,
          productCategory: filter.productCategory,
          province: filter.province,
          distributionChannel: filter.channel,
          depotTypes: filter.kind.storedTypes,
          includeUntypedDepots: filter.kind.includesUntyped,
          sort: filter.sortBy.toBrowseSort(),
        ))
          row.toModel(),
      ];
}
