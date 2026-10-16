import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/my_visits/domain/entities/depot_stop_info.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';
import 'package:steelforce/features/my_visits/domain/entities/territory_type.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/domain/services/stop_distance_sorter.dart';

DepotStopInfo _cust(String id, double lat, double lng) => DepotStopInfo(
      id: id,
      name: 'Shop $id',
      code: 'C$id',
      contact: 'Owner',
      phone: '012000000',
      address: 'Phnom Penh',
      territory: 'Phnom Penh',
      territoryType: TerritoryType.urban,
      latitude: lat,
      longitude: lng,
    );

RouteStop _stop(String id, int sequence, double lat, double lng) => RouteStop(
      id: id,
      routeId: 'R1',
      depot: _cust(id, lat, lng),
      sequence: sequence,
      plannedArrival: DateTime.utc(2026, 8, 3, 8),
      plannedDeparture: DateTime.utc(2026, 8, 3, 9),
      status: VisitStatus.pending,
    );

void main() {
  const sorter = StopDistanceSorter();

  // Phnom Penh reference point; three stops at increasing distances, given out
  // of order so a correct sort must reorder them.
  final near = _stop('near', 3, 11.5564, 104.9282); // at origin
  final mid = _stop('mid', 1, 11.60, 104.9282); // ~5 km north
  final far = _stop('far', 2, 11.70, 104.9282); // ~16 km north

  group('StopDistanceSorter', () {
    test('with a position, sorts nearest-first and stamps distances', () {
      final ranked = sorter.sort(
        [far, mid, near],
        latitude: 11.5564,
        longitude: 104.9282,
      );

      expect(ranked.map((r) => r.stop.id).toList(), ['near', 'mid', 'far']);
      // Distances are stamped and strictly increasing.
      expect(ranked[0].distanceMeters, isNotNull);
      expect(ranked[0].distanceMeters! < ranked[1].distanceMeters!, isTrue);
      expect(ranked[1].distanceMeters! < ranked[2].distanceMeters!, isTrue);
      // Nearest is essentially at the origin.
      expect(ranked[0].distanceMeters! < 50, isTrue);
    });

    test('without a position, keeps planned order and leaves distances null',
        () {
      final ranked = sorter.sort([far, mid, near]);

      // Planned order = by sequence (mid=1, far=2, near=3).
      expect(ranked.map((r) => r.stop.id).toList(), ['mid', 'far', 'near']);
      expect(ranked.every((r) => r.distanceMeters == null), isTrue);
    });

    test('empty input yields empty output', () {
      expect(sorter.sort(const [], latitude: 11.5, longitude: 104.9), isEmpty);
      expect(sorter.sort(const []), isEmpty);
    });
  });
}
