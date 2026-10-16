import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/portal_depot.dart';

/// Parses the **portal** depot shape returned by
/// `GET /depots/by-code/{code}`.
///
/// Kept well away from [DepotApiMapper]: the field names and the envelope
/// both differ, and the integration guide is explicit that one parser must not
/// serve both surfaces. Every field is read defensively — this is a lookup on a
/// surface the mobile app is a secondary consumer of, so an unexpected null
/// must degrade rather than throw.
abstract final class PortalDepotMapper {
  static PortalDepot fromJson(DataMap json) {
    // Flat on the mobile surface, nested here.
    final address =
        (json['address'] as Map?)?.cast<String, dynamic>() ?? const {};

    return PortalDepot(
      id: json['id']?.toString() ?? '',
      // `code`, not `depotCode`.
      code: json['code'] as String? ?? '',
      // `name`, not `shopName`, and not localised.
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'Draft',
      // Computed server-side as `status == Active`. Used as sent rather than
      // re-derived, so the two can never disagree.
      canTrade: json['canTrade'] as bool? ?? false,
      type: json['type'] as String?,
      phone: json['phone'] as String?,
      city: address['city'] as String?,
      latitude: (address['latitude'] as num?)?.toDouble(),
      longitude: (address['longitude'] as num?)?.toDouble(),
      // A bare decimal on this surface, not `{ amount, currency }`.
      creditLimit: (json['creditLimit'] as num?)?.toDouble(),
      creditTermDays: (json['creditTermDays'] as num?)?.toInt(),
      assignedSalesRepId: json['assignedSalesRepId'] as String?,
      createdAt: parseUtc(json['createdAt']),
    );
  }

  /// Unwraps the portal envelope, which is `{ data, meta }` — **no `success`
  /// and no `message`**, so [ApiEnvelope] cannot be reused here.
  static PortalDepot? fromEnvelope(Object? body) {
    if (body is! Map) return null;
    final data = body['data'];
    if (data is! Map) return null;
    final depot = fromJson(data.cast<String, dynamic>());
    // An empty id means the row came back unusable; treat it as absent rather
    // than handing the UI a depot it cannot open.
    return depot.id.isEmpty ? null : depot;
  }
}
