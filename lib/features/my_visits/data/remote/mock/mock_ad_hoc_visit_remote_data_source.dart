// TODO(release-gate): demo-only data source; must never be registered in a release mobile build (USE_MOCK_DATA=false).
//
// [AdHocVisitRemoteDataSource] for the static web demo: the route flow's
// `POST /mobile/visits/ad-hoc` answered from [MockVisitWorld], with no network
// call. Idempotent on `clientRequestId` and refusing the documented 404 / 409s
// like the server, so the repository's queue and refusal handling run as-is.
// The new visit joins today, so the Plans list and the next route pull carry
// it too.
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/mock_latency.dart';
import 'package:steelforce/features/my_visits/data/models/ad_hoc_visit_response.dart';
import 'package:steelforce/features/my_visits/data/remote/ad_hoc_visit_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/mock/mock_visit_world.dart';

class MockAdHocVisitRemoteDataSource implements AdHocVisitRemoteDataSource {
  const MockAdHocVisitRemoteDataSource(this._world);

  final MockVisitWorld _world;

  @override
  Future<AdHocVisitResponse> create({
    required String sk,
    required String clientRequestId,
  }) async {
    await MockLatency.tick();
    final id = 'demo-adhoc-$clientRequestId';
    final replay = _world.find(id);
    if (replay != null) return _response(replay, created: false);

    final depot = _world.depotByCode(sk) ??
        (throw const ApiException(
            ApiError(code: ApiErrorCodes.visitDepotNotFound, statusCode: 404)));
    final today = _world.today;
    final onToday = _world.visits
        .where((v) => v.day == today && v.depot.code == depot.code)
        .firstOrNull;
    if (onToday != null) {
      throw ApiException(ApiError(
          code: onToday.adHoc
              ? ApiErrorCodes.visitAdHocAlreadyExists
              : ApiErrorCodes.visitDepotAlreadyPlanned,
          statusCode: 409));
    }
    return _response(_world.addAdHoc(id, depot), created: true);
  }

  /// Through [AdHocVisitResponse.fromJson], as the live source parses it.
  AdHocVisitResponse _response(MockVisitRecord visit, {required bool created}) {
    final day = visit.day;
    String two(int n) => n.toString().padLeft(2, '0');
    return AdHocVisitResponse.fromJson({
      'stop': {
        'id': visit.id,
        'routeId': 'demo-route-${day.year}-${two(day.month)}-${two(day.day)}',
        'customerId': visit.depot.code,
        'sequence': 1001,
        'plannedArrival': null,
        'plannedDeparture': null,
        'status': 'pending',
        'visitSource': 'adHoc',
      },
      'visitDate': '${day.year}-${two(day.month)}-${two(day.day)}',
      'depot': {
        'id': visit.depot.code,
        'name': visit.depot.name,
        'code': visit.depot.code,
        'contact': '',
        'phone': '',
        'address': 'Phnom Penh',
        'territory': MockVisitWorld.territory,
        'territoryType': 'urban',
        'latitude': visit.depot.latitude,
        'longitude': visit.depot.longitude,
      },
      'created': created,
    });
  }
}
