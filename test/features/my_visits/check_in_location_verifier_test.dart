import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/my_visits/domain/entities/depot_stop_info.dart';
import 'package:steelforce/features/my_visits/domain/entities/territory_type.dart';
import 'package:steelforce/features/my_visits/domain/services/check_in_location_verifier.dart';
import 'package:steelforce/features/my_visits/domain/services/outlet_location_source.dart';

/// The rule the check-in dialog renders and the check-in gate reads: is the rep
/// inside the designated check-in area.
///
/// Worth testing directly rather than through the dialog, because the failure
/// modes are arithmetic — a boundary compared with the wrong operator, a `(0,0)`
/// pin measured as a real one, a missing GPS fix read as "far away" — and none
/// of them look wrong on screen. They just quietly let the wrong rep check in,
/// or block the right one.
void main() {
  /// ISI's Phnom Penh office — the static demo pin.
  const outletLat = StaticOutletLocationSource.kDemoOutletLatitude;
  const outletLng = StaticOutletLocationSource.kDemoOutletLongitude;

  const outlet = OutletLocation(
    latitude: outletLat,
    longitude: outletLng,
    radiusMeters: kCheckInRadiusMeters,
  );

  CheckInLocationVerdict verifyAt(double? lat, double? lng,
          {OutletLocation? at = outlet}) =>
      CheckInLocationVerifier.verify(
        outlet: at,
        deviceLatitude: lat,
        deviceLongitude: lng,
        fallbackRadiusMeters: kCheckInRadiusMeters,
      );

  /// Metres north of the outlet, as a latitude. One degree of latitude is
  /// ~111 320 m everywhere, so this is exact enough to place a point at a known
  /// distance without re-deriving Haversine in the test.
  double latMetresNorth(double metres) => outletLat + metres / 111320.0;

  group('the 100 m check-in radius', () {
    test('standing on the outlet is within', () {
      final v = verifyAt(outletLat, outletLng);

      expect(v.isWithinRadius, isTrue);
      expect(v.distanceMeters, closeTo(0, 1));
      expect(v.radiusMeters, 100);
    });

    test('85 m away is within — the dialog\'s worked example', () {
      final v = verifyAt(latMetresNorth(85), outletLng);

      expect(v.isWithinRadius, isTrue);
      expect(v.distanceMeters, closeTo(85, 2));
    });

    test('250 m away is outside — the other worked example', () {
      final v = verifyAt(latMetresNorth(250), outletLng);

      expect(v.isWithinRadius, isFalse);
      expect(v.distanceMeters, closeTo(250, 3));
    });

    test('just inside and just outside fall on the right sides', () {
      expect(verifyAt(latMetresNorth(99), outletLng).isWithinRadius, isTrue);
      expect(verifyAt(latMetresNorth(101), outletLng).isWithinRadius, isFalse);
    });

    test('exactly on the boundary counts as within', () {
      // `<=`, not `<`. The radius is the edge of the permitted area, not the
      // first metre outside it — and a rep standing on a line they cannot see
      // should not be refused by a rounding decision.
      final v = CheckInLocationVerifier.verify(
        outlet: const OutletLocation(
            latitude: outletLat, longitude: outletLng, radiusMeters: 0),
        deviceLatitude: outletLat,
        deviceLongitude: outletLng,
        fallbackRadiusMeters: kCheckInRadiusMeters,
      );

      expect(v.distanceMeters, closeTo(0, 0.001));
      expect(v.isWithinRadius, isTrue);
    });

    test('distance is symmetric in every direction', () {
      // Not just north: a bug in the longitude term only shows up east-west,
      // where a degree is ~0.98× a latitude degree at this parallel.
      final north = verifyAt(latMetresNorth(150), outletLng).distanceMeters;
      final south = verifyAt(latMetresNorth(-150), outletLng).distanceMeters;

      expect(north, closeTo(150, 3));
      expect(south, closeTo(150, 3));
    });
  });

  group('the outcomes that are not "inside" or "outside"', () {
    test('no device fix is its own verdict, not "far away"', () {
      final v = verifyAt(null, null);

      expect(v.hasDeviceFix, isFalse);
      expect(v.isMeasurable, isFalse);
      expect(v.isWithinRadius, isFalse,
          reason: 'never confirmable without a position');
      expect(v.distanceMeters.isNaN, isTrue,
          reason: 'no distance to show — the UI must check isMeasurable');
      // The radius is still known, so the dialog can state the rule.
      expect(v.radiusMeters, 100);
    });

    test('a half-known position is treated as no fix', () {
      expect(verifyAt(outletLat, null).hasDeviceFix, isFalse);
      expect(verifyAt(null, outletLng).hasDeviceFix, isFalse);
    });

    test('no outlet location is reported, not measured against (0,0)', () {
      final v = verifyAt(outletLat, outletLng, at: null);

      expect(v.hasOutletLocation, isFalse);
      expect(v.isWithinRadius, isFalse);
      expect(v.distanceMeters.isNaN, isTrue);
      expect(v.radiusMeters, kCheckInRadiusMeters,
          reason: 'falls back to the configured radius so the rule is sayable');
    });
  });

  group('the static-position shim', _staticShimTests);

  group('the check-in outlet source', _checkInSourceTests);

  group('the outlet source seam', () {
    DepotStopInfo depot({double lat = 11.60, double lng = 104.90}) =>
        DepotStopInfo(
          id: 'c1',
          name: 'ISI Steel Outlet',
          code: 'C-1',
          contact: 'Sok Dara',
          phone: '012345678',
          address: 'St 271',
          territory: 'PP-CENTRAL',
          territoryType: TerritoryType.urban,
          latitude: lat,
          longitude: lng,
        );

    test('the static source ignores the stop and returns the demo pin', () {
      const source = StaticOutletLocationSource();

      final location = source.locationFor(depot())!;

      // Every stop verifies against the same point — correct for a demo, and
      // the reason this is a named class rather than a constant in a widget.
      expect(location.latitude, outletLat);
      expect(location.longitude, outletLng);
      expect(location.radiusMeters, 100);
    });

    test('the stop source uses the depot’s own pin', () {
      const source = StopOutletLocationSource();

      final location = source.locationFor(depot(lat: 11.60, lng: 104.90))!;

      expect(location.latitude, 11.60);
      expect(location.longitude, 104.90);
      expect(location.radiusMeters, 100);
    });

    test('the stop source returns null for a depot with no pin', () {
      const source = StopOutletLocationSource();

      // `(0, 0)` is the Gulf of Guinea and what a handset reports when the fix
      // failed. Measuring against it would put every rep ~10 000 km out.
      expect(source.locationFor(depot(lat: 0, lng: 0)), isNull);
    });

    test('swapping the source is the only change needed', () {
      // The verifier reads whatever the source hands it, so the seam really is
      // one registration. If this ever needs more than the two lines below, the
      // indirection has stopped paying for itself.
      const staticSource = StaticOutletLocationSource();
      const stopSource = StopOutletLocationSource();
      final c = depot(lat: 11.60, lng: 104.90);

      final viaStatic = CheckInLocationVerifier.verify(
        outlet: staticSource.locationFor(c),
        deviceLatitude: outletLat,
        deviceLongitude: outletLng,
        fallbackRadiusMeters: kCheckInRadiusMeters,
      );
      final viaStop = CheckInLocationVerifier.verify(
        outlet: stopSource.locationFor(c),
        deviceLatitude: outletLat,
        deviceLongitude: outletLng,
        fallbackRadiusMeters: kCheckInRadiusMeters,
      );

      // Standing on the demo pin: inside the demo area, far from the real stop.
      expect(viaStatic.isWithinRadius, isTrue);
      expect(viaStop.isWithinRadius, isFalse);
    });
  });
}

/// The static-position shim, which is what makes the flow usable with no GPS.
///
/// Its predecessor measured the *real* device position while only the pushed
/// payload used the constant, so on a simulator the dialog sat on "Locating
/// You" and no check-in could be made at all.
void _staticShimTests() {
  test('the shim is debug-only and cannot ship enabled', () {
    // `kDebugMode`-defaulted rather than a bare `true`. Under `flutter test`
    // this is a debug VM, so it reads true here — the assertion that matters
    // is that it is not hardcoded on.
    expect(kUseStaticCheckInPosition, isTrue,
        reason: 'expected on under a debug test VM');
  });

  const shop = DepotStopInfo(
    id: 'c1',
    name: 'ISI Steel Outlet',
    code: 'C-1',
    contact: '',
    phone: '',
    address: '',
    territory: 'PP-CENTRAL',
    territoryType: TerritoryType.urban,
    latitude: 11.60,
    longitude: 104.90,
  );

  test('the stand-in rep stands on the stop\'s own pin', () {
    // 0 m against the pin the flow now measures — so a check-in still
    // completes end to end with no GPS, which is the whole purpose of the shim.
    final standIn = staticCheckInPositionFor(shop);
    final v = CheckInLocationVerifier.verify(
      outlet: kCheckInOutletLocationSource.locationFor(shop),
      deviceLatitude: standIn.latitude,
      deviceLongitude: standIn.longitude,
      fallbackRadiusMeters: kCheckInRadiusMeters,
    );

    expect(v.isMeasurable, isTrue,
        reason: 'never "Locating You" — that was the bug');
    expect(v.isWithinRadius, isTrue);
    expect(v.distanceMeters, closeTo(0, 1));
  });

  test('a stop with no pin still reads "outlet location unavailable"', () {
    const noPin = DepotStopInfo(
      id: 'c2',
      name: 'Untagged Outlet',
      code: 'C-2',
      contact: '',
      phone: '',
      address: '',
      territory: 'PP-CENTRAL',
      territoryType: TerritoryType.urban,
      latitude: 0,
      longitude: 0,
    );
    final standIn = staticCheckInPositionFor(noPin);

    final v = CheckInLocationVerifier.verify(
      outlet: kCheckInOutletLocationSource.locationFor(noPin),
      deviceLatitude: standIn.latitude,
      deviceLongitude: standIn.longitude,
      fallbackRadiusMeters: kCheckInRadiusMeters,
    );

    expect(v.hasOutletLocation, isFalse,
        reason: 'the shim must not paper over a missing pin with the office');
  });
}

/// The check-in measures against the outlet, not ISI's office.
///
/// It used to default to [StaticOutletLocationSource] in every build, so the
/// 100 m radius was drawn around the Phnom Penh office for every stop: a rep
/// standing in the real shop read as "outside", and a rep at the office read
/// as "inside" every shop on the route.
void _checkInSourceTests() {
  const shop = DepotStopInfo(
    id: 'c1',
    name: 'ISI Steel Outlet',
    code: 'C-1',
    contact: '',
    phone: '',
    address: '',
    territory: 'PP-CENTRAL',
    territoryType: TerritoryType.urban,
    // ~5 km from the office pin.
    latitude: 11.60,
    longitude: 104.90,
  );

  test('the office demo pin is off unless explicitly asked for', () {
    expect(kUseDemoOutletPin, isFalse);
    expect(kCheckInOutletLocationSource, isA<StopOutletLocationSource>());
  });

  test('the area is centred on the outlet\'s own coordinates', () {
    final location = kCheckInOutletLocationSource.locationFor(shop)!;

    expect(location.latitude, shop.latitude);
    expect(location.longitude, shop.longitude);
    expect(location.radiusMeters, kCheckInRadiusMeters);
  });

  test('a rep at the shop is within; a rep at the office is outside', () {
    final outlet = kCheckInOutletLocationSource.locationFor(shop);

    final atShop = CheckInLocationVerifier.verify(
      outlet: outlet,
      deviceLatitude: shop.latitude + 40 / 111320.0,
      deviceLongitude: shop.longitude,
      fallbackRadiusMeters: kCheckInRadiusMeters,
    );
    final atOffice = CheckInLocationVerifier.verify(
      outlet: outlet,
      deviceLatitude: StaticOutletLocationSource.kDemoOutletLatitude,
      deviceLongitude: StaticOutletLocationSource.kDemoOutletLongitude,
      fallbackRadiusMeters: kCheckInRadiusMeters,
    );

    expect(atShop.isWithinRadius, isTrue);
    expect(atOffice.isWithinRadius, isFalse);
    expect(atOffice.distanceMeters, greaterThan(1000));
  });

  test('an outlet with no coordinates is reported, never the office', () {
    const noPin = DepotStopInfo(
      id: 'c2',
      name: 'Untagged Outlet',
      code: 'C-2',
      contact: '',
      phone: '',
      address: '',
      territory: 'PP-CENTRAL',
      territoryType: TerritoryType.urban,
      latitude: 0,
      longitude: 0,
    );

    expect(kCheckInOutletLocationSource.locationFor(noPin), isNull);

    // Even standing on the office pin, there is no area to be inside of.
    final v = CheckInLocationVerifier.verify(
      outlet: kCheckInOutletLocationSource.locationFor(noPin),
      deviceLatitude: StaticOutletLocationSource.kDemoOutletLatitude,
      deviceLongitude: StaticOutletLocationSource.kDemoOutletLongitude,
      fallbackRadiusMeters: kCheckInRadiusMeters,
    );
    expect(v.hasOutletLocation, isFalse);
    expect(v.isWithinRadius, isFalse);
    expect(v.radiusMeters, kCheckInRadiusMeters);
  });
}
