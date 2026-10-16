import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/models/material_api_mapper.dart';
import 'package:steelforce/features/order/data/remote/material_selection_remote_data_source.dart';
import 'package:steelforce/features/order/domain/entities/material_availability.dart';
import 'package:steelforce/features/order/domain/repositories/material_availability_repository.dart';

/// Banded stock for one material, over the platform's `/stock` read.
///
/// ## Why `/stock` and not `/availability`
///
/// Both endpoints answer "may this be sold?". Only one of them can answer it
/// today.
///
/// `/availability` validates against a sales area and needs `salesOrg`,
/// `disChannel` and `division`. The session carries none of them, so SAP
/// answers **HTTP 200** with `isSellable: false` and `INPUT_VKORG` /
/// `INPUT_VTWEG` checks — the validation never ran. Gating the quantity
/// stepper on that would disable every `+` button in the app for a reason
/// that has nothing to do with the material.
///
/// `/stock` needs no sales area. It answers a real band and a real verdict, so
/// it is what the order flow gates on. [checkAvailability] therefore calls it,
/// and the sales-area check stays available for a future commit-time
/// confirmation once the rep's sales area is resolved.
///
/// TODO(release-gate): once the session carries the sales area, call
/// `/availability` as a second, confirming check at the point the quotation is
/// submitted — not here, where it would block browsing.
class MaterialAvailabilityRepositoryImpl
    implements MaterialAvailabilityRepository {
  const MaterialAvailabilityRepositoryImpl({
    required MaterialSelectionRemoteDataSource remote,
    required NetworkInfo network,
  })  : _remote = remote,
        _network = network;

  final MaterialSelectionRemoteDataSource _remote;
  final NetworkInfo _network;

  @override
  ResultFuture<MaterialAvailability> checkAvailability(String material) async {
    if (material.trim().isEmpty) {
      return const Failed(
          ServerFailure(message: 'No material number to check.'));
    }

    // Checked up front because this is the one call in the feature that
    // genuinely cannot work offline. Letting it fail at the socket would
    // surface a transport error where the honest answer is "not asked yet" —
    // and the flow renders an unchecked material differently from a refused
    // one for exactly that reason.
    if (!await _network.isConnected) {
      return const Failed(NetworkFailure());
    }

    try {
      final number = material.trim();
      final json = await _remote.fetchStock(number);
      return Success(MaterialApiMapper.stockFrom(json, requested: number));
    } on ApiException catch (e) {
      return Failed(ServerFailure(
        message: e.error.message ?? 'Could not check stock.',
        statusCode: e.statusCode,
      ));
    } on ServerException catch (e) {
      return Failed(ServerFailure(message: e.message));
    }
  }
}
