import 'package:steelforce/core/utils/enum_parse.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/models/depot_contact_model.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';

/// Hand-written mapping (mirrors `order`'s `ProductModel`) — the remote SAP
/// payload shape and the flat sqlite row shape differ enough that
/// generated code wouldn't buy much here.
class DepotModel extends Depot {
  const DepotModel({
    required super.id,
    super.sapDepotId,
    required super.depotCode,
    required super.shopName,
    required super.ownerName,
    required super.phone,
    required super.address,
    required super.province,
    required super.district,
    required super.territory,
    required super.latitude,
    required super.longitude,
    required super.creditLimit,
    required super.status,
    required super.assignedRepId,
    required super.assignedRepName,
    required super.updatedAt,
    super.email,
    super.whatsapp,
    super.originLeadId,
    super.productsPurchased,
    super.contacts,
    super.lastOrderDate,
    super.lastVisitDate,
    super.lifetimeValue,
    super.openOpportunityCount,
    super.salesOrg,
    super.division,
    super.distributionChannel,
    super.depotGroup,
    super.priceGroup,
    super.enName,
    super.khName,
    super.taxNumber,
    super.creditBalance,
    super.currency,
    super.totalOrders,
    super.createdAt,
    this.deleted = false,
  });

  final bool deleted;

  factory DepotModel.fromJson(DataMap json) => DepotModel(
        id: json['id'] as String,
        // Wire keys, not field names: ADR-0007 moved the routes to /depots and
        // deliberately left the payloads on SAP's "customer". `customerCode`
        // below survived the rename sweep; this one did not, which is the
        // inconsistency rather than the intent.
        sapDepotId: json['sapCustomerId'] as String?,
        depotCode: json['customerCode'] as String,
        shopName: json['shopName'] as String,
        ownerName: json['ownerName'] as String,
        phone: json['phone'] as String,
        email: json['email'] as String?,
        whatsapp: json['whatsapp'] as String?,
        address: json['address'] as String,
        province: json['province'] as String,
        district: json['district'] as String,
        territory: json['territory'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        creditLimit: (json['creditLimit'] as num).toDouble(),
        status: DepotStatus.values.byNameOr(
            json['status'] as String?, DepotStatus.draft,
            context: 'depot.json.status'),
        assignedRepId: json['assignedRepId'] as String,
        assignedRepName: json['assignedRepName'] as String,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        originLeadId: json['originLeadId'] as String?,
        productsPurchased:
            (json['productsPurchased'] as List<dynamic>? ?? const [])
                .map((e) => e as String)
                .toList(),
        contacts: (json['contacts'] as List<dynamic>? ?? const [])
            .map((e) => DepotContactModel.fromRow(e as DataMap))
            .toList(),
        lastOrderDate: json['lastOrderDate'] == null
            ? null
            : DateTime.parse(json['lastOrderDate'] as String),
        lastVisitDate: json['lastVisitDate'] == null
            ? null
            : DateTime.parse(json['lastVisitDate'] as String),
        lifetimeValue: (json['lifetimeValue'] as num?)?.toDouble() ?? 0,
        openOpportunityCount: json['openOpportunityCount'] as int? ?? 0,
        // SAP sales area / commercial block. Keys match the SAP Depot (BP)
        // API field names in `SapAPI_Technical_Document_v1_BP.docx` §5.4, so a
        // real SAP payload deserialises here unchanged (ADR-009 decision 4).
        salesOrg: json['salesOrg'] as String?,
        division: json['division'] as String?,
        distributionChannel: json['distributionChannel'] as String?,
        depotGroup: json['customerGroup'] as String?,
        priceGroup: json['priceGroup'] as String?,
        enName: json['enName'] as String?,
        khName: json['khName'] as String?,
        taxNumber: json['taxNumber'] as String?,
        creditBalance: (json['creditBalance'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] as String? ?? 'USD',
        totalOrders: json['totalOrders'] as int? ?? 0,
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.parse(json['createdAt'] as String),
        deleted: json['deleted'] as bool? ?? false,
      );

  factory DepotModel.fromRow(DataMap row,
          {List<DepotContactModel> contacts = const []}) =>
      DepotModel(
        id: row['id'] as String,
        sapDepotId: row['sap_depot_id'] as String?,
        depotCode: row['depot_code'] as String,
        shopName: row['shop_name'] as String,
        ownerName: row['owner_name'] as String,
        phone: row['phone'] as String,
        email: row['email'] as String?,
        whatsapp: row['whatsapp'] as String?,
        address: row['address'] as String,
        province: row['province'] as String,
        district: row['district'] as String,
        territory: row['territory'] as String,
        latitude: (row['latitude'] as num).toDouble(),
        longitude: (row['longitude'] as num).toDouble(),
        creditLimit: (row['credit_limit'] as num).toDouble(),
        status: DepotStatus.values.byNameOr(
            row['status'] as String?, DepotStatus.draft,
            context: 'depot.row.status'),
        assignedRepId: row['assigned_rep_id'] as String,
        assignedRepName: row['assigned_rep_name'] as String,
        updatedAt: DateTime.parse(row['updated_at'] as String),
        originLeadId: row['origin_lead_id'] as String?,
        productsPurchased: ((row['products_purchased'] as String?) ?? '')
            .split('|')
            .where((e) => e.isNotEmpty)
            .toList(),
        contacts: contacts,
        lastOrderDate: row['last_order_date'] == null
            ? null
            : DateTime.parse(row['last_order_date'] as String),
        lastVisitDate: row['last_visit_date'] == null
            ? null
            : DateTime.parse(row['last_visit_date'] as String),
        lifetimeValue: (row['lifetime_value'] as num?)?.toDouble() ?? 0,
        openOpportunityCount: row['open_opportunity_count'] as int? ?? 0,
        deleted: (row['deleted'] as int? ?? 0) == 1,
      );

  DataMap toRow() => {
        'id': id,
        'sap_depot_id': sapDepotId,
        'depot_code': depotCode,
        'shop_name': shopName,
        'owner_name': ownerName,
        'phone': phone,
        'email': email,
        'whatsapp': whatsapp,
        'address': address,
        'province': province,
        'district': district,
        'territory': territory,
        'latitude': latitude,
        'longitude': longitude,
        'credit_limit': creditLimit,
        'status': status.name,
        'assigned_rep_id': assignedRepId,
        'assigned_rep_name': assignedRepName,
        'updated_at': updatedAt.toIso8601String(),
        'origin_lead_id': originLeadId,
        'products_purchased': productsPurchased.join('|'),
        'last_order_date': lastOrderDate?.toIso8601String(),
        'last_visit_date': lastVisitDate?.toIso8601String(),
        'lifetime_value': lifetimeValue,
        'open_opportunity_count': openOpportunityCount,
        'deleted': deleted ? 1 : 0,
      };

  DataMap toFtsRow() => {
        'depot_id': id,
        'shop_name': shopName,
        'depot_code': depotCode,
        'owner_name': ownerName,
        'phone': phone,
      };
}
