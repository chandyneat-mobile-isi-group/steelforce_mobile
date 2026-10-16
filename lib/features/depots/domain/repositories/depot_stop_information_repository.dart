import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/depot_stop_information.dart';

/// The outlet profile and credit position behind a visit's stop screen.
///
/// Consumed by `my_visits` through this interface rather than by reaching into
/// the depots feature's `data/` layer — the endpoint lives under
/// `/mobile/depots/…` and the depots feature owns it (CLAUDE.md §4).
abstract interface class DepotStopInformationRepository {
  /// Loads the profile for [depotId], the GUID the route sync puts on each stop.
  ///
  /// A **404 is reported as [DepotStopInformationUnavailableFailure]**, which
  /// covers "no such outlet" and "not entitled" together. The server refuses to
  /// distinguish them, so neither may be presented as "deleted".
  ResultFuture<DepotStopInformation> fetch(String depotId);
}
