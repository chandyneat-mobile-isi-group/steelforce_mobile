import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/depot_filter_options.dart';
import 'package:steelforce/features/depots/domain/entities/depot_list_kind.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_filter_options_source.dart';

/// The Advanced Filters choices for [DepotListKind]'s list.
class LoadDepotFilterOptions
    extends UseCase<DepotFilterOptions, DepotListKind> {
  const LoadDepotFilterOptions(this._source);
  final DepotFilterOptionsSource _source;

  @override
  ResultFuture<DepotFilterOptions> call(DepotListKind params) =>
      _source.load(params);
}
