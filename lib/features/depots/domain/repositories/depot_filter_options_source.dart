import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/depot_filter_options.dart';
import 'package:steelforce/features/depots/domain/entities/depot_list_kind.dart';

/// The filter choices of one list, read from the depots on this device.
abstract interface class DepotFilterOptionsSource {
  ResultFuture<DepotFilterOptions> load(DepotListKind kind);
}
