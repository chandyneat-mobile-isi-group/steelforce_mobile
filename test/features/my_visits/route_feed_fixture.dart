import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:steelforce/features/my_visits/data/remote/api_route_remote_data_source.dart';

/// A stand-in for the live route feed, for tests that need routes to arrive
/// the way the app actually receives them.
///
/// This replaced `MockRouteRemoteDataSource`, which was deleted along with the
/// rest of the bundled route fixtures. The substitution is deliberate rather
/// than mechanical: the old mock built [RouteSyncPage] objects directly, so
/// every test using it skipped the JSON the real app has to parse. Scripting
/// the transport instead means these tests now exercise
/// [ApiRouteRemoteDataSource] end to end — envelope, field names, enum
/// strings, the depot/stop join — which is the layer most likely to drift
/// away from the backend contract.
///
/// [depotIds] is resolved *per request*, not once at construction: a caller
/// that syncs its depot directory first cannot know the ids until that has
/// run, and `route_stops.depot_id` is a live FK, so the feed has to name
/// depots that really exist locally.
Dio scriptedRouteFeed({
  required Future<List<String>> Function() depotIds,
  String territory = 'Phnom Penh',
  int stopsPerRoute = 3,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://routes.test'));
  dio.httpClientAdapter = _RouteFeedAdapter(
    depotIds: depotIds,
    territory: territory,
    stopsPerRoute: stopsPerRoute,
  );
  return dio;
}

class _RouteFeedAdapter implements HttpClientAdapter {
  _RouteFeedAdapter({
    required this.depotIds,
    required this.territory,
    required this.stopsPerRoute,
  });

  final Future<List<String>> Function() depotIds;
  final String territory;
  final int stopsPerRoute;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? stream,
      Future<void>? cancelFuture) async {
    final ids = await depotIds();

    // Anchored to the UTC calendar day, matching `RouteDao.fetchRoutesForDay`.
    // A local-midnight date lands on the previous UTC day in Cambodia (UTC+7)
    // and silently falls outside every "today" query — the bug the deleted
    // fixtures were repeatedly caught by.
    final now = DateTime.now().toUtc();
    final day = DateTime.utc(now.year, now.month, now.day);
    String at(int hour) => day.add(Duration(hours: hour)).toIso8601String();

    final stopIds = ids.take(stopsPerRoute).toList();

    final body = {
      'data': {
        // `customers`, not `depots` — see the note on the directory feed below.
        'customers': [
          for (final id in stopIds)
            {
              'id': id,
              'name': 'ISI Hardware $id',
              'nameKh': 'ISI ហាឌវែរ $id',
              'code': 'C-$id',
              'contact': 'Sok Dara',
              'phone': '012345678',
              'address': 'Street 271',
              'territory': territory,
              'territoryType': 'industrial',
              'latitude': 11.55,
              'longitude': 104.91,
              'geofenceRadiusOverride': null,
            }
        ],
        'routes': [
          if (stopIds.isNotEmpty)
            {
              'id': 'route-today',
              'name': 'my_visits.route_info.plan_daily',
              'repId': 'rep-1',
              'repName': 'Rep One',
              'territory': territory,
              'visitDate': day.toIso8601String(),
              'plannedStart': at(8),
              'plannedEnd': at(17),
              'status': 'published',
              'stops': [
                for (var i = 0; i < stopIds.length; i++)
                  {
                    'id': 'stop-$i',
                    'routeId': 'route-today',
                    'customerId': stopIds[i],
                    'sequence': i + 1,
                    'plannedArrival': at(9 + i),
                    'plannedDeparture': at(9 + i),
                    'status': 'pending',
                    'actualArrival': null,
                    'actualDeparture': null,
                  }
              ],
            }
        ],
        'hasMore': false,
      },
      'message': null,
      'metadata': null,
    };

    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// A feed that names depots the local directory does not have.
///
/// `RouteDriftLocalDataSource.upsertDepots` only *updates* existing rows —
/// the depot directory is SAP-owned and route sync may never invent one
/// (ADR-001) — so the stops then violate the `route_stops.depot_id` FK and
/// the whole transaction aborts. That is the real shape of "routes arrived
/// before the directory did", and it has to surface as a reported failure
/// rather than an empty dashboard with no explanation.
Dio unsatisfiableRouteFeed() =>
    scriptedRouteFeed(depotIds: () async => ['ghost-depot']);

/// A scripted depot feed for pipeline tests.
Dio scriptedDepotFeed({int depotCount = 6}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://depots.test'));
  dio.httpClientAdapter = _DepotFeedAdapter(depotCount: depotCount);
  return dio;
}

class _DepotFeedAdapter implements HttpClientAdapter {
  _DepotFeedAdapter({this.depotCount = 6});

  final int depotCount;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? stream,
      Future<void>? cancelFuture) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final body = {
      'data': {
        // SAP's nouns, deliberately. The route is /mobile/depots and every
        // payload key underneath it is still `customer` (ADR-0007). This
        // fixture exists to catch drift from the backend contract, so it has
        // to spell the contract, not the Dart field names.
        'customers': [
          for (var i = 1; i <= depotCount; i++)
            {
              'id': 'cust-$i',
              'sapCustomerId': 'SAP-$i',
              'customerCode': 'ISI-$i',
              'shopName': 'Hardware Shop $i',
              'ownerName': 'Owner $i',
              'phone': '01234567$i',
              'province': 'Phnom Penh',
              'district': 'Chamkar Mon',
              'territory': 'Phnom Penh',
              'status': 'Active',
              'latitude': 11.55,
              'longitude': 104.91,
              'creditLimit': {'amount': 50000.0, 'currency': 'USD'},
              'creditBalance': {'amount': 12000.0, 'currency': 'USD'},
            }
        ],
      },
      'message': null,
      'metadata': {
        'pageNumber': 1,
        'pageSize': depotCount,
        'hasNextPage': false,
        'syncTimestamp': now,
      },
    };

    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
