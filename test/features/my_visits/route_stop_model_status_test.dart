import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/my_visits/data/models/depot_stop_info_model.dart';
import 'package:steelforce/features/my_visits/data/models/route_plan_model.dart';
import 'package:steelforce/features/my_visits/data/models/route_stop_model.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/territory_type.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

/// Guards the Objective-2 fix: the model mappers used to hardcode
/// `VisitStatus.pending` / `RouteStatus.published`, so the dashboard summary
/// always computed 0 completed / 0% progress no matter what the mock emitted.
/// These assert the execution state now flows from the payload into the entity.
void main() {
  const depot = DepotStopInfoModel(
    id: 'cust-1',
    name: 'ISI Hardware',
    code: 'C-1',
    contact: 'Sok Dara',
    phone: '012345678',
    address: 'St 271',
    territory: 'Phnom Penh',
    territoryType: TerritoryType.urban,
    latitude: 11.55,
    longitude: 104.91,
  );

  Map<String, dynamic> stopJson(Map<String, dynamic> extra) => {
        'id': 's-1',
        'routeId': 'r-1',
        'depotId': 'cust-1',
        'sequence': 1,
        'plannedArrival': '2026-07-15T09:00:00.000',
        'plannedDeparture': '2026-07-15T09:20:00.000',
        ...extra,
      };

  group('RouteStopModel.fromJson reads execution state', () {
    test('a checked-out stop carries its status and actual times', () {
      final stop = RouteStopModel.fromJson(
        stopJson({
          'status': 'checkedOut',
          'actualArrival': '2026-07-15T09:02:00.000',
          'actualDeparture': '2026-07-15T09:24:00.000',
        }),
        depot: depot,
      );

      expect(stop.status, VisitStatus.checkedOut);
      expect(stop.actualArrival, DateTime.parse('2026-07-15T09:02:00.000'));
      expect(stop.actualDeparture, DateTime.parse('2026-07-15T09:24:00.000'));
    });

    test('a missed stop maps to VisitStatus.missed with no actuals', () {
      final stop = RouteStopModel.fromJson(
        stopJson({'status': 'missed'}),
        depot: depot,
      );

      expect(stop.status, VisitStatus.missed);
      expect(stop.actualArrival, isNull);
      expect(stop.actualDeparture, isNull);
    });

    test('an absent status falls back to pending (payload without state)', () {
      final stop = RouteStopModel.fromJson(stopJson({}), depot: depot);

      expect(stop.status, VisitStatus.pending);
    });

    test('an unrecognised status falls back rather than throwing', () {
      final stop = RouteStopModel.fromJson(
        stopJson({'status': 'teleported'}),
        depot: depot,
      );

      expect(stop.status, VisitStatus.pending);
    });
  });

  group('RoutePlanModel.fromJson reads route state', () {
    Map<String, dynamic> routeJson(String status) => {
          'id': 'r-1',
          'name': 'North loop',
          'repId': 'rep-1',
          'repName': 'Rep One',
          'territory': 'Phnom Penh',
          'visitDate': '2026-07-15T00:00:00.000',
          'plannedStart': '2026-07-15T08:00:00.000',
          'plannedEnd': '2026-07-15T17:00:00.000',
          'status': status,
        };

    test('a completed route maps to RouteStatus.completed', () {
      final route =
          RoutePlanModel.fromJson(routeJson('completed'), stops: const []);
      expect(route.status, RouteStatus.completed);
    });

    test('an in-progress route maps to RouteStatus.inProgress', () {
      final route =
          RoutePlanModel.fromJson(routeJson('inProgress'), stops: const []);
      expect(route.status, RouteStatus.inProgress);
    });
  });
}
