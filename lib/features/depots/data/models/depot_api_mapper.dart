import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/utils/money.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/models/depot_api_fields.dart';
import 'package:steelforce/features/depots/data/models/depot_contact_model.dart';
import 'package:steelforce/features/depots/data/models/depot_model.dart';
import 'package:steelforce/features/depots/data/models/depot_profile_model.dart';
import 'package:steelforce/features/depots/data/models/depot_sales_area_model.dart';
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
  /// The row's platform id, or null when it carries none.
  ///
  /// `depotId`, then `id`, then `depotCode`. api-dev stopped sending
  /// `depotId` on 30 Oct; the server resolves a depot by its code, and every
  /// earlier answer sent a Depot's `depotId` equal to its code. A row with
  /// none of the three is not stored — it would share the empty key.
  static String? idOf(DataMap json) {
    final id = (json['depotId'] ?? json['id'])?.toString().trim() ?? '';
    if (id.isNotEmpty) return id;
    final code =
        (json['depotCode'] ?? json['customerCode'])?.toString().trim() ?? '';
    return code.isEmpty ? null : code;
  }

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
    final salesAreas = DepotSalesAreaModel.listFrom(json['salesAreas']);
    final coordinates = DepotApiFields.coordinates(json);
    // The `items` row (`depotId`, `depotName`, …) names the depot directly and
    // carries its rep in `salesEmployees`; the older `customers` row used
    // SAP's nouns. Both are read so cached and detail payloads still parse.
    final rep = DepotApiFields.primarySalesEmployee(json);
    final depotCode =
        (json['depotCode'] ?? json['customerCode']) as String? ?? '';

    final id = idOf(json);
    if (id == null) {
      // An empty id makes every record overwrite the same SQLite primary key
      // and can make a 200-row sync look successful while storing one row.
      // Fail the page without logging or retaining any payload values — the
      // key names are the contract, never a value, and say which field the
      // server sent instead.
      throw ServerException(
        message: 'The depot response contained a record without an id. '
            'Keys: ${(json.keys.toList()..sort()).join(',')}',
      );
    }

    return DepotModel(
      id: id,
      // SAP owns this and leaves it blank until the depot is linked, so a
      // draft registered in the field legitimately has none.
      // Null, never ''. The column is UNIQUE, and SQLite treats every NULL as
      // distinct while '' is a single value — so collapsing "not in SAP yet"
      // to an empty string made the second such depot violate the
      // constraint and abort the whole sync batch. Most rows in a fresh
      // territory are `PendingApproval` and have no SAP id at all.
      // `sapCustomerId`/`customerCode` are the wire's names and stay that way —
      // ADR-0007 moved the routes, not the payload keys.
      // In the `items` list only a `Depot` row is an SAP business partner, so
      // only its code is the SAP id — which turns on the ad hoc visit action.
      // A numbered `Draft` is still awaiting approval; a `NonDepot` has none.
      sapDepotId: json['sapCustomerId'] as String? ??
          (json['depotType'] == 'Depot' && depotCode.isNotEmpty
              ? depotCode
              : null),
      depotCode: depotCode,
      // Already localised by the server against `Accept-Language`. The fallback
      // chain is requested → English → legal name, so this is non-empty for
      // any real depot.
      shopName: (json['depotName'] ?? json['shopName']) as String? ?? '',
      ownerName: json['ownerName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      whatsapp: json['whatsapp'] as String?,
      // The summary DTO carries no street address — only city, district and
      // territory, which is all a list row and a map pin need. The full
      // address arrives with the detail aggregate (`fromDetail`), so a
      // freshly synced row shows a blank street until it is opened.
      address: DepotApiFields.address(json),
      // The list sends none; its address ends with the province.
      province: json['province'] as String? ??
          DepotApiFields.provinceOf(DepotApiFields.address(json)),
      district: json['district'] as String? ?? '',
      territory: json['territory'] as String? ??
          rep?['territoryCode'] as String? ??
          '',
      latitude: coordinates.$1,
      longitude: coordinates.$2,
      // The grouped list carries the limit only per sales area. Without a
      // top-level figure, the first area's stands in, so orders and the shop
      // list stop reading every depot as a zero limit.
      creditLimit: json.containsKey('creditLimit')
          ? creditLimit.amount
          : salesAreas?.firstOrNull?.creditLimit ?? creditLimit.amount,
      creditBalance: creditBalance.amount,
      currency: currency,
      // Branch on the stable code; render `statusDisplay`, which is localised
      // and therefore changes with the request language.
      status: DepotStatus.fromApi(json['status'] as String?),
      assignedRepId: json['assignedRepId'] as String? ??
          rep?['employeeCode'] as String? ??
          '',
      assignedRepName: json['assignedRepName'] as String? ??
          rep?['employeeName'] as String? ??
          '',
      updatedAt: parseUtc(json['updatedAt']) ??
          parseUtc(json['createdAt']) ??
          DateTime.now().toUtc(),
      createdAt: parseUtc(json['createdAt']),
      lastOrderDate: parseUtc(json['lastOrderDate']),
      lastVisitDate: parseUtc(json['lastVisitDate']),
      enName: json['enName'] as String? ?? json['depotName'] as String?,
      khName: json['khName'] as String? ?? json['depotNameKh'] as String?,
      // The list sends it per sales area only: the first one's stands in.
      distributionChannel:
          (json['depotChannel'] ?? json['distributionChannel']) as String? ??
              salesAreas?.firstOrNull?.channelName,
      depotType: json['depotType'] as String?,
      createdBy: json['createdBy']?.toString(),
      salesEmployees:
          DepotProfileModel.salesEmployeesFrom(json['salesEmployees']),
      profile: DepotProfileModel.profileFrom(json['profile']),
      // The list carries the shop's contacts inside `profile`.
      contacts: _contacts(
          json['profile'] is Map
              ? (json['profile'] as Map)['contactPersons']
              : null,
          depotId: id),
      // BP depots and non-BP outlets alike; credit terms live per area.
      salesAreas: salesAreas,
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
      address: DepotApiFields.address(json),
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
      assignedRepName: summary.assignedRepName,
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
      distributionChannel: summary.distributionChannel,
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
      // The detail answer's own `contacts`; else what the list sent.
      contacts: json['contacts'] is List
          ? _contacts(json['contacts'], depotId: summary.id)
          : summary.contacts,
      depotType: summary.depotType,
      createdBy: summary.createdBy,
      salesEmployees: summary.salesEmployees,
      profile: summary.profile,
      salesAreas: summary.salesAreas,
      deleted: summary.deleted,
    );
  }

  /// Contacts come back primary-first then alphabetical — a stable order, so a
  /// local diff does not show phantom changes on every sync. Preserved here.
  ///
  /// `profile.contactPersons` rows carry no id; each gets a local one from
  /// its depot and place in the list, so two never share a key.
  static List<DepotContactModel> _contacts(Object? raw,
      {required String depotId}) {
    if (raw is! List) return const [];
    final rows = raw.whereType<Map>().map((e) => e.cast<String, dynamic>());
    return [
      for (final (i, c) in rows.indexed)
        DepotContactModel(
          id: '${c['id'] ?? ''}'.trim().isNotEmpty
              ? '${c['id']}'
              : '$depotId#contact$i',
          name: c['name'] as String? ?? '',
          role: (c['position'] ?? c['role']) as String? ?? '',
          phone: c['phone'] as String? ?? '',
          email: c['email'] as String?,
        ),
    ];
  }
}
