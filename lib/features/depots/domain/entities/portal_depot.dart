import 'package:equatable/equatable.dart';

/// A depot as the **portal** surface describes it, returned only by
/// `GET /depots/by-code/{code}`.
///
/// ## Why this is a separate type from [Depot]
///
/// That endpoint lives on `/depots`, not `/mobile/depots`, and its shape
/// differs in five ways that all fail silently if you assume otherwise:
///
/// | Mobile | Portal (`by-code`) |
/// |---|---|
/// | `{ success, message, data, metadata, traceId }` | `{ data, meta }` |
/// | `depotCode` | `code` |
/// | `shopName` (localised) | `name` (not localised) |
/// | `statusDisplay` present | absent — localise `status` yourself |
/// | `creditLimit: { amount, currency }` | `creditLimit: 0.0` — a bare number |
/// | flat `city` / `latitude` | nested under `address` |
///
/// The integration guide is explicit that one parser must not serve both. This
/// type is deliberately small: it exists to answer "does this code exist?", not
/// to render a detail screen. Follow up with the mobile detail endpoint once the
/// platform id is known.
class PortalDepot extends Equatable {
  const PortalDepot({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    required this.canTrade,
    this.type,
    this.phone,
    this.city,
    this.latitude,
    this.longitude,
    this.creditLimit,
    this.creditTermDays,
    this.assignedSalesRepId,
    this.createdAt,
  });

  /// The platform id — what the mobile detail endpoint takes.
  final String id;

  /// The depot number. `code` here, `depotCode` on the mobile surface.
  final String code;

  /// Not localised on this surface, unlike `shopName`.
  final String name;

  /// A stable code to branch on. There is no `statusDisplay` here, so the
  /// client resolves the label itself — which this app does anyway.
  final String status;

  final bool canTrade;
  final String? type;
  final String? phone;
  final String? city;
  final double? latitude;
  final double? longitude;

  /// A bare number on this surface, not a `{ amount, currency }` object.
  final double? creditLimit;
  final int? creditTermDays;
  final String? assignedSalesRepId;
  final DateTime? createdAt;

  /// Whether this depot has a usable position. `(0, 0)` is a real point in
  /// the Gulf of Guinea and what a device reports on a failed GPS fix, so it is
  /// treated as absent — the same rule `Depot.hasCoordinates` applies.
  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      !(latitude == 0 && longitude == 0);

  @override
  List<Object?> get props => [id, code, name, status];
}
