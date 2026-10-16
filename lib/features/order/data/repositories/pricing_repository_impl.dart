import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/models/mobile_price_model.dart';
import 'package:steelforce/features/order/data/remote/pricing_remote_data_source.dart';
import 'package:steelforce/features/order/domain/entities/mobile_price.dart';
import 'package:steelforce/features/order/domain/repositories/pricing_repository.dart';

/// Live depot pricing, transcribed rather than computed.
///
/// Two rules this implementation exists to hold:
///
///  * **No local price, ever.** A failure returns a failure state, not a
///    catalogue figure wearing a live badge. Substituting a plausible number
///    is the one outcome worse than showing none.
///  * **A failure is per material, never per screen.** Every requested
///    material comes back with a verdict, so one unpriceable line cannot blank
///    the other seven.
class PricingRepositoryImpl implements PricingRepository {
  const PricingRepositoryImpl({
    required PricingRemoteDataSource remote,
    required NetworkInfo network,
  })  : _remote = remote,
        _network = network;

  final PricingRemoteDataSource _remote;
  final NetworkInfo _network;

  @override
  ResultFuture<List<MobilePrice>> getPrices({
    required String depotId,
    required List<String> materials,
  }) async {
    final wanted = materials
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();
    if (wanted.isEmpty) return const Success(<MobilePrice>[]);

    if (depotId.trim().isEmpty) {
      // A walk-in has no depot to price against. That is a settled answer,
      // not an error — the rep is not doing anything wrong and there is
      // nothing to retry.
      return Success(_allWith(
        wanted,
        PricingState.unavailable,
        PricingErrorKind.depotNotFound,
      ));
    }

    // Checked first: pricing is live backend data and cannot be answered from
    // the device. Failing at the socket would surface as a generic error where
    // the honest answer is "you are offline", which is the one a rep can act
    // on.
    if (!await _network.isConnected) {
      return Success(_allWith(
        wanted,
        PricingState.error,
        PricingErrorKind.networkUnavailable,
      ));
    }

    try {
      final rows = await _remote.fetchPrices(
        depotId: depotId,
        materials: wanted,
      );

      final byMaterial = <String, MobilePrice>{
        for (final row in rows)
          MobilePriceMapper.fromJson(row).material:
              MobilePriceMapper.fromJson(row),
      };

      // Every material asked about gets an answer. A material the backend
      // simply omitted is "no price", not "never asked" — leaving it absent
      // would strand its card on a spinner forever.
      return Success([
        for (final material in wanted)
          byMaterial[material] ??
              MobilePrice(
                material: material,
                state: PricingState.unavailable,
                errorKind: PricingErrorKind.noPrice,
              ),
      ]);
    } on ApiException catch (e) {
      return Success(_allWith(wanted, PricingState.error, _kindFor(e)));
    } on ServerException {
      return Success(_allWith(
        wanted,
        PricingState.error,
        PricingErrorKind.backendUnavailable,
      ));
    }
  }

  static List<MobilePrice> _allWith(
    List<String> materials,
    PricingState state,
    PricingErrorKind kind,
  ) =>
      [
        for (final material in materials)
          MobilePrice(material: material, state: state, errorKind: kind),
      ];

  /// Maps the transport failure onto something a rep can act on.
  ///
  /// "No signal" sends them to find some; "not priceable" sends them to the
  /// office; "unauthorized" sends them to IT. One generic message sends them
  /// nowhere, which is why these are kept apart.
  static PricingErrorKind _kindFor(ApiException e) {
    if (e.statusCode == 401) return PricingErrorKind.unauthorized;
    if (e.statusCode == 403) return PricingErrorKind.unauthorized;
    if (e.statusCode == 404) return PricingErrorKind.depotNotFound;
    if (e.statusCode == 422) return PricingErrorKind.depotNotPriceable;
    final status = e.statusCode;
    if (status != null && status >= 500) {
      return PricingErrorKind.backendUnavailable;
    }
    // A transport failure with no status at all: the socket never got an
    // answer. Connectivity is checked before the call, so by here this is the
    // gateway rather than the handset.
    if (status == null) return PricingErrorKind.backendUnavailable;
    return PricingErrorKind.unknown;
  }
}
