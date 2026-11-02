import 'package:steelforce/core/database/drift/daos/depot_dao.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/depot_filter_options.dart';
import 'package:steelforce/features/depots/domain/entities/depot_list_kind.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_filter_options_source.dart';

/// [DepotFilterOptionsSource] over the encrypted database.
class DriftDepotFilterOptionsSource implements DepotFilterOptionsSource {
  const DriftDepotFilterOptionsSource(this._dao);
  final DepotDao _dao;

  @override
  ResultFuture<DepotFilterOptions> load(DepotListKind kind) async {
    try {
      final choices = await _dao.filterChoices(
        depotTypes: kind.storedTypes,
        includeUntypedDepots: kind.includesUntyped,
      );
      return Success(DepotFilterOptions(
        // Stored by enum name (`active`, `suspended`); a name this build
        // does not know is left out rather than offered as something else.
        statuses: [
          for (final s in choices.statuses)
            if (DepotStatus.values.asNameMap()[s] case final status?) status,
        ],
        provinces: choices.provinces,
        channels: choices.channels,
      ));
    } catch (e) {
      return Failed(CacheFailure(message: 'Failed to read depot filters: $e'));
    }
  }
}
