/// TODO(release-gate): demo-only, selected only when DataSourceMode.useMocks.
///
/// [AdHocVisitRemoteDataSource] for a demo build: `POST /mobile/visits/ad-hoc`
/// answered from [DemoSeed] and [DemoVisitLedger].
///
/// Keeps the contract's behaviour (`ad-hoc-visits-mobile.md` §4, §8): keyed on
/// the depot's SAP code, idempotent on `clientRequestId` (a replay answers
/// `created: false` with the same stop), and the documented 404 / 409s, so
/// `AdHocVisitRepositoryImpl`'s queue and refusal handling run unchanged.
/// The new stop joins today's route, so the next route pull carries it too.
library;

import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_route_fixtures.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_visit_ledger.dart';
import 'package:steelforce/features/my_visits/data/models/ad_hoc_visit_response.dart';
import 'package:steelforce/features/my_visits/data/remote/ad_hoc_visit_remote_data_source.dart';

class DemoAdHocVisitRemoteDataSource implements AdHocVisitRemoteDataSource {
  const DemoAdHocVisitRemoteDataSource(this._network, this._ledger);

  final DemoNetwork _network;
  final DemoVisitLedger _ledger;

  /// Ad hoc stops sort after every planned one, as the server numbers them.
  static const int _firstSequence = 1001;

  @override
  Future<AdHocVisitResponse> create({
    required String sk,
    required String clientRequestId,
  }) async {
    await _network.roundTrip();

    final day =
        DemoRouteFixtures.dateKey(DemoRouteFixtures.utcDay(_ledger.now()));
    final depot = DemoSeed.depotById(sk);
    if (depot == null) {
      throw const ApiException(
          ApiError(code: ApiErrorCodes.visitDepotNotFound, statusCode: 404));
    }

    final replay = _ledger.adHocFor(clientRequestId);
    if (replay != null) {
      return _parse(replay.stop, depot, day: replay.day, created: false);
    }

    if (DemoSeed.todayStops.any((d) => d.id == depot.id)) {
      throw const ApiException(ApiError(
          code: ApiErrorCodes.visitDepotAlreadyPlanned, statusCode: 409));
    }
    final today = _ledger.adHocStopsOn(day);
    if (today.any((s) => s['customerId'] == depot.id)) {
      throw const ApiException(ApiError(
          code: ApiErrorCodes.visitAdHocAlreadyExists, statusCode: 409));
    }

    final stop = <String, dynamic>{
      'id': '${kDemoStopIdPrefix}adhoc-$clientRequestId',
      'routeId': DemoSeed.todayRouteId,
      'customerId': depot.id,
      'sequence': _firstSequence + today.length,
      'plannedArrival': null,
      'plannedDeparture': null,
      'status': 'pending',
      'actualArrival': null,
      'actualDeparture': null,
      'departureInferred': false,
      'visitSource': 'adHoc',
    };
    _ledger.addAdHoc(clientRequestId, day, stop);
    return _parse(stop, depot, day: day, created: true);
  }

  /// Through [AdHocVisitResponse.fromJson], as the live source does; an
  /// unreadable body leaves as a [ServerException] there too.
  AdHocVisitResponse _parse(
    DataMap stop,
    DemoDepot depot, {
    required String day,
    required bool created,
  }) {
    try {
      return AdHocVisitResponse.fromJson({
        'stop': stop,
        'visitDate': day,
        'depot': DemoRouteFixtures.depotJson(depot,
            territory: DemoRouteFixtures.territoryOr('')),
        'created': created,
      });
    } on FormatException catch (e) {
      throw ServerException(message: e.message);
    }
  }
}
