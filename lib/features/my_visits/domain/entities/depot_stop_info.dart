import 'package:equatable/equatable.dart';
import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/features/my_visits/domain/entities/territory_type.dart';

/// A depot/depot location a route can stop at.
class DepotStopInfo extends Equatable {
  const DepotStopInfo({
    required this.id,
    required this.name,
    required this.code,
    required this.contact,
    required this.phone,
    required this.address,
    required this.territory,
    required this.territoryType,
    required this.latitude,
    required this.longitude,
    this.nameKh = '',
    this.geofenceRadiusOverride,
  });

  final String id;

  /// Latin shop name — SAP `name1` / the directory's `shopName`. Kept under
  /// its original name because the check-in, map and telemetry paths all read
  /// it; [displayName] is the localised accessor.
  final String name;

  /// Khmer shop name (SAP `name3`), projected from the depot directory by
  /// `DepotRowStopInfoMapper.toStopInfo`.
  ///
  /// Defaulted rather than required: a stop for a depot SAP has no Khmer
  /// name for is legitimate, and [LocalizedText.resolve] falls back to [name]
  /// rather than rendering a blank stop card — a rep standing outside a shop
  /// needs *something* to match against the signage.
  final String nameKh;

  /// Whether this stop has a usable position.
  ///
  /// `(0, 0)` encodes "no GPS fix was ever captured" — it is a real point in
  /// the Gulf of Guinea, roughly 10 000 km away, which is why the depot API
  /// rejects it on write and sends null instead. Distance ranking and geofence
  /// evaluation must both check this before measuring anything; see
  /// `Depot.hasCoordinates`, which this mirrors.
  bool get hasCoordinates => latitude != 0 || longitude != 0;

  final String code;
  final String contact;
  final String phone;
  final String address;
  final String territory;
  final TerritoryType territoryType;
  final double latitude;
  final double longitude;
  final double? geofenceRadiusOverride;

  double get geofenceRadiusMeters =>
      geofenceRadiusOverride ?? territoryType.defaultGeofenceRadiusMeters;

  /// The stop's name in both languages, for rendering. Widgets call
  /// `context.localized(stop.depot.displayName)`.
  LocalizedText get displayName => LocalizedText(en: name, km: nameKh);

  /// Both names plus the code, for the dashboard's stop search — a rep looking
  /// for a shop types whichever name they know, in whichever language the UI
  /// happens to be in.
  Iterable<String> get searchableValues sync* {
    yield* displayName.allValues;
    yield code;
  }

  @override
  List<Object?> get props => [
        id,
        name,
        nameKh,
        code,
        territory,
        latitude,
        longitude,
        geofenceRadiusOverride,
      ];
}
