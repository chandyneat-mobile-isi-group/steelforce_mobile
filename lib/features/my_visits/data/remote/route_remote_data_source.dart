import 'package:steelforce/features/my_visits/data/remote/route_sync_page.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_sync_scope.dart';

/// Route/depot pull source, scoped to the signed-in rep.
///
/// One implementation: [ApiRouteRemoteDataSource], against
/// `GET /api/v1/mobile/visits/routes`. The bundled fixture source was removed
/// once the real endpoint landed — routes are rep- and day-scoped, so a
/// committed fixture set is wrong as soon as the calendar moves, and a feed
/// that always answers made a broken one look healthy. Tests script the
/// transport instead (`test/features/my_visits/route_feed_fixture.dart`).
///
/// Note the scope is a *filter*, never an authorisation claim: the real
/// implementation sends `territory` but not `repId`, because the server
/// derives the rep from the bearer token and must refuse to answer for anyone
/// else (`docs/feature/my-visits/api.md` §5, §8.1).
abstract interface class RouteRemoteDataSource {
  Future<RouteSyncPage> fetchInitial(
      {required RouteSyncScope scope,
      required int page,
      required int pageSize});

  /// The per-rep route set is small by design (a handful of routes/day),
  /// unlike the product catalog's 17k+ rows — so unlike
  /// `MockProductRemoteDataSource`'s randomized delta, this simply re-pulls
  /// the rep's current scoped route/depot set. Still guarded by the same
  /// `since`-driven sync-meta watermark at the repository layer.
  Future<RouteSyncPage> fetchDelta(
      {required RouteSyncScope scope, required DateTime since});
}
