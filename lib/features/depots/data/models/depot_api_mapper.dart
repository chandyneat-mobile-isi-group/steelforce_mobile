import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/utils/money.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/models/depot_contact_model.dart';
import 'package:steelforce/features/depots/data/models/depot_model.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';

/// Maps the mobile depot API onto [DepotModel].
///
/// Kept apart from `DepotModel.fromJson` (the mock/legacy shape) and
/// `fromRow` (the local database shape) because the three genuinely differ:
/// the API's summary DTO is roughly a fifth of the full depot, its money
/// fields are objects rather than decimals, and almost everything the local
/// schema declares non-null is optional over the wire.
///
/// Everything here is tolerant by design. A field the server omits must
/// degrade to a sensible default rather than throw — a single unexpected null
/// in one row of a 200-row page would otherwise abort an entire sync.
abstract final class DepotApiMapper {
  /// The list row from `GET /mobile/depots`.
  ///
  /// **Tombstones arrive through here too.** A row with `deleted: true` carries
  /// little more than an id, so every other field falls back rather than
  /// failing; the caller checks [DepotModel.deleted] and deletes the local
  /// copy instead of upserting it.
  static DepotModel fromSummary(DataMap json) {
    // A depot trades in exactly one currency, carried at the top level, and
    // all the money fields share it.
    final currency = json['currency'] as String? ?? 'USD';
    final creditLimit =
        Money.fromJson(json['creditLimit'], fallbackCurrency: currency);
    final creditBalance =
        Money.fromJson(json['creditBalance'], fallbackCurrency: currency);
    final coordinates = _coordinates(json);

    return DepotModel(
      id: json['id']?.toString() ?? '',
      // SAP owns this and leaves it blank until the depot is linked, so a
      // draft registered in the field legitimately has none.
      // Null, never ''. The column is UNIQUE, and SQLite treats every NULL as
      // distinct while '' is a single value — so collapsing "not in SAP yet"
      // to an empty string made the second such depot violate the
      // constraint and abort the whole sync batch. Most rows in a fresh
      // territory are `PendingApproval` and have no SAP id at all.
      // `sapCustomerId`/`customerCode` are the wire's names and stay that way —
      // ADR-0007 moved the routes, not the payload keys.
      sapDepotId: json['sapCustomerId'] as String?,
      depotCode: json['customerCode'] as String? ?? '',
      // Already localised by the server against `Accept-Language`. The fallback
      // chain is requested → English → legal name, so this is non-empty for
      // any real depot.
      shopName: json['shopName'] as String? ?? '',
      ownerName: json['ownerName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      whatsapp: json['whatsapp'] as String?,
      // The summary DTO carries no street address — only city, district and
      // territory, which is all a list row and a map pin need. The full
      // address arrives with the detail aggregate (`fromDetail`), so a
      // freshly synced row shows a blank street until it is opened.
      address: _address(json),
      province: json['province'] as String? ?? '',
      district: json['district'] as String? ?? '',
      territory: json['territory'] as String? ?? '',
      latitude: coordinates.$1,
      longitude: coordinates.$2,
      creditLimit: creditLimit.amount,
      creditBalance: creditBalance.amount,
      currency: currency,
      // Branch on the stable code; render `statusDisplay`, which is localised
      // and therefore changes with the request language.
      status: DepotStatus.fromApi(json['status'] as String?),
      assignedRepId: json['assignedRepId'] as String? ?? '',
      // Resolved server-side via a directory lookup, and absent from the
      // summary. The detail payload supplies it.
      assignedRepName: json['assignedRepName'] as String? ?? '',
      updatedAt: parseUtc(json['updatedAt']) ??
          parseUtc(json['createdAt']) ??
          DateTime.now().toUtc(),
      createdAt: parseUtc(json['createdAt']),
      lastOrderDate: parseUtc(json['lastOrderDate']),
      lastVisitDate: parseUtc(json['lastVisitDate']),
      enName: json['enName'] as String?,
      khName: json['khName'] as String?,
      deleted: json['deleted'] as bool? ?? false,
    );
  }

  /// The full aggregate from `GET /mobile/depots/{id}`, which is a superset
  /// of the summary plus contacts, the SAP block and the metric cache.
  static DepotModel fromDetail(DataMap json) {
    final summary = fromSummary(json);
    final currency = json['currency'] as String? ?? summary.currency;

    return DepotModel(
      id: summary.id,
      sapDepotId: summary.sapDepotId,
      depotCode: summary.depotCode,
      shopName: summary.shopName,
      ownerName: summary.ownerName,
      phone: summary.phone,
      email: summary.email,
      whatsapp: summary.whatsapp,
      address: _address(json),
      province: summary.province,
      district: summary.district,
      territory: summary.territory,
      latitude: summary.latitude,
      longitude: summary.longitude,
      creditLimit: summary.creditLimit,
      creditBalance: summary.creditBalance,
      currency: currency,
      status: summary.status,
      assignedRepId: summary.assignedRepId,
      assignedRepName: json['assignedRepName'] as String? ?? '',
      updatedAt: summary.updatedAt,
      createdAt: summary.createdAt,
      lastOrderDate: summary.lastOrderDate,
      lastVisitDate: summary.lastVisitDate,
      enName: summary.enName,
      khName: summary.khName,
      taxNumber: json['taxNumber'] as String?,
      // Returned but never writable from the app — SAP owns this block.
      salesOrg: json['salesOrg'] as String?,
      division: json['division'] as String?,
      distributionChannel: json['distributionChannel'] as String?,
      depotGroup: json['customerGroup'] as String?,
      priceGroup: json['priceGroup'] as String?,
      // Denormalised metrics. They carry `metricsCalculatedAt` so staleness is
      // visible, and they are never authoritative — in particular do not build
      // a credit block on `creditBalance`, which is only as fresh as the last
      // SAP interface run.
      lifetimeValue:
          Money.fromJson(json['lifetimeValue'], fallbackCurrency: currency)
              .amount,
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      openOpportunityCount:
          (json['openOpportunityCount'] as num?)?.toInt() ?? 0,
      contacts: _contacts(json['contacts']),
      deleted: summary.deleted,
    );
  }

  /// Contacts come back primary-first then alphabetical — a stable order, so a
  /// local diff does not show phantom changes on every sync. Preserved here.
  static List<DepotContactModel> _contacts(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .map((c) => DepotContactModel(
              id: c['id']?.toString() ?? '',
              name: c['name'] as String? ?? '',
              role: (c['position'] ?? c['role']) as String? ?? '',
              phone: c['phone'] as String? ?? '',
              email: c['email'] as String?,
            ))
        .toList();
  }

  static String _address(DataMap json) {
    final line1 = json['addressLine1'] as String?;
    if (line1 != null && line1.trim().isNotEmpty) return line1.trim();
    // Fall back to what the summary does carry, so a list row is not blank.
    final parts = [json['district'], json['city']]
        .whereType<String>()
        .where((e) => e.trim().isNotEmpty);
    return parts.join(', ');
  }

  /// Coordinates, with `(0, 0)` treated as absent.
  ///
  /// The API sends null for both when a device reported no GPS fix, and
  /// explicitly rejects `(0, 0)` on write because it is a real point in the
  /// Gulf of Guinea — exactly what a failed fix looks like. The local schema
  /// still declares these columns non-null, so `(0, 0)` is what gets stored
  /// for "unknown"; [DepotModel] exposes `hasCoordinates` so the geofence
  /// and distance sorter can tell the difference rather than measuring to the
  /// Atlantic. See `docs/API_INTEGRATION.md` for the migration that makes
  /// these properly nullable.
  static (double, double) _coordinates(DataMap json) {
    final lat = (json['latitude'] as num?)?.toDouble();
    final lng = (json['longitude'] as num?)?.toDouble();
    // Latitude and longitude are only ever meaningful together.
    if (lat == null || lng == null) return (0, 0);
    if (lat.abs() > 90 || lng.abs() > 180) return (0, 0);
    return (lat, lng);
  }
}
