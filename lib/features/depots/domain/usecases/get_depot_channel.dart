import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_channel_source.dart';

/// Which depot: by code, or by id for a Non-BP depot.
typedef DepotRef = ({String? depotCode, String? depotId});

/// The channel of one depot — "Distributor", "Contractor", … — for screens
/// outside the depots feature that name a depot, such as a visit plan card.
class GetDepotChannel extends UseCase<String?, DepotRef> {
  const GetDepotChannel(this._source);
  final DepotChannelSource _source;

  @override
  ResultFuture<String?> call(DepotRef params) =>
      _source.channelOf(depotCode: params.depotCode, depotId: params.depotId);
}
