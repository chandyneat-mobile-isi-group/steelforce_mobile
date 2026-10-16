/// Builds the demo depots as the API would send them.
///
/// The rows are wire JSON, not models, so every demo source runs them through
/// the same mapper its live twin uses (`DepotApiMapper`, `PortalDepotMapper`,
/// `DepotStopInformationMapper`). A demo that skipped the parsers would prove
/// nothing about them.
///
/// TODO(release-gate): demo-only, selected only when DataSourceMode.useMocks.
library;

import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_profile.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_profiles.dart';
import 'package:steelforce/features/depots/data/mock/demo_registration_references.dart';

abstract final class DemoDepotFixtures {
  static const String currency = 'USD';

  /// Keys the detail aggregate carries and the list summary does not. Stripped
  /// from list rows so the demo has the real list/detail split — a synced row
  /// shows a blank street until the depot is opened, exactly as it does live.
  static const Set<String> detailOnlyKeys = {
    'addressLine1',
    'contacts',
    'taxNumber',
    'salesOrg',
    'division',
    'distributionChannel',
    'customerGroup',
    'priceGroup',
    'lifetimeValue',
    'totalOrders',
    'openOpportunityCount',
  };

  /// Every seeded depot as a full detail row, timestamped relative to [now].
  static List<DataMap> seedRows(DateTime now) => [
        for (final (index, depot) in DemoSeed.depots.indexed)
          _row(depot, demoDepotProfiles[depot.id]!, index, now.toUtc()),
      ];

  static DataMap _row(
    DemoDepot depot,
    DemoDepotProfile profile,
    int index,
    DateTime now,
  ) {
    final slug = depot.name.toLowerCase().replaceAll(RegExp('[^a-z]+'), '.');
    return {
      'id': depot.id,
      // Null until SAP has the partner — the column is UNIQUE and an empty
      // string would collide (see `DepotApiMapper.fromSummary`).
      'sapCustomerId': profile.isInSap ? depot.code : null,
      'customerCode': depot.code,
      'shopName': depot.name,
      'enName': depot.name,
      'khName': depot.nameKm,
      'ownerName': depot.ownerName,
      'phone': depot.phone,
      'email': '$slug@example.com',
      'whatsapp': depot.phone,
      'addressLine1': '${profile.street}, ${depot.district}',
      'district': depot.district,
      'city': depot.province,
      'province': depot.province,
      'territory': profile.territory,
      'latitude': depot.latitude,
      'longitude': depot.longitude,
      'currency': currency,
      'creditLimit': money(profile.creditLimit),
      'creditBalance': money(profile.creditBalance),
      'status': profile.status,
      'statusDisplay': profile.status,
      'assignedRepId': DemoSeed.repId,
      'assignedRepName': DemoSeed.repName,
      // Spread over the past weeks so the list's "recently updated" order is
      // stable and no seeded row looks newer than a depot created in the demo.
      'updatedAt': iso(now.subtract(Duration(days: 20 + index))),
      'createdAt': iso(now.subtract(Duration(days: 400 + index * 37))),
      'lastVisitDate':
          iso(now.subtract(Duration(days: profile.lastVisitDaysAgo))),
      'lastOrderDate': profile.lastOrderDaysAgo == null
          ? null
          : iso(now.subtract(Duration(days: profile.lastOrderDaysAgo!))),
      'taxNumber': profile.taxNumber,
      'salesOrg': profile.isInSap ? DemoSeed.salesOrg : null,
      'division': profile.isInSap ? DemoSeed.division : null,
      'distributionChannel':
          profile.isInSap ? DemoSeed.distributionChannel : null,
      'customerGroup': profile.depotGroup,
      'priceGroup': profile.priceGroup,
      'lifetimeValue': money(profile.lifetimeValue),
      'totalOrders': profile.totalOrders,
      'openOpportunityCount': profile.openOpportunities,
      'contacts': [
        for (final (i, c) in profile.contacts.indexed)
          {
            'id': '${depot.id}-contact-${i + 1}',
            'name': c.name,
            'position': c.position,
            'phone': c.phone,
            'email': null,
            'isPrimary': i == 0,
          },
      ],
      // Not part of the depot DTO; carried for the stop-information view.
      'outletType': profile.outletType,
      'paymentTermCode': profile.paymentTerm,
      'telegram': profile.telegram,
      'deleted': false,
    };
  }

  /// A depot the demo backend has just registered in SAP.
  ///
  /// Both registration routes funnel through here so a shop created by either
  /// looks the same in the book. Blank inputs fall back rather than leaving
  /// the list row unreadable.
  static DataMap registered({
    required String id,
    required String code,
    required String name,
    String nameKm = '',
    String ownerName = '',
    String phone = '',
    String street = '',
    String district = '',
    String city = '',
    double? latitude,
    double? longitude,
    String? depotGroup,
    String? priceGroup,
    String? paymentTerm,
    double creditLimit = 0,
    String? salesOrg,
    String? distributionChannel,
    String? division,
  }) =>
      {
        'id': id,
        'sapCustomerId': code,
        'customerCode': code,
        'shopName': name.isEmpty ? code : name,
        'enName': name,
        'khName': nameKm.isEmpty ? null : nameKm,
        'ownerName': ownerName,
        'phone': phone,
        'addressLine1':
            [street, district].where((part) => part.isNotEmpty).join(', '),
        'district': district,
        'city': city,
        'province': city,
        'territory': '',
        'latitude': latitude,
        'longitude': longitude,
        'currency': currency,
        'creditLimit': money(creditLimit),
        'creditBalance': money(0),
        'status': 'Active',
        'statusDisplay': 'Active',
        'assignedRepId': DemoSeed.repId,
        'assignedRepName': DemoSeed.repName,
        'salesOrg': salesOrg ?? DemoSeed.salesOrg,
        'distributionChannel':
            distributionChannel ?? DemoSeed.distributionChannel,
        'division': division ?? DemoSeed.division,
        'customerGroup': depotGroup,
        'priceGroup': priceGroup,
        'paymentTermCode': paymentTerm,
        'outletType': 'Retailer',
        'contacts': [
          if (ownerName.isNotEmpty)
            {
              'id': '$id-contact-1',
              'name': ownerName,
              'position': 'Owner',
              'phone': phone,
              'isPrimary': true,
            },
        ],
        'deleted': false,
      };

  /// The list row: the detail row minus what only the aggregate carries.
  static DataMap summaryOf(DataMap row) => {
        for (final entry in row.entries)
          if (!detailOnlyKeys.contains(entry.key)) entry.key: entry.value,
      };

  /// The portal shape `GET /depots/by-code/{code}` returns.
  static DataMap portalOf(DataMap row) => {
        'id': row['id'],
        'code': row['customerCode'],
        'name': row['shopName'],
        'status': row['status'],
        'canTrade': row['status'] == 'Active',
        'type': row['outletType'],
        'phone': row['phone'],
        'address': {
          'city': row['city'],
          'latitude': row['latitude'],
          'longitude': row['longitude'],
        },
        // A bare decimal on this surface.
        'creditLimit': (row['creditLimit'] as Map?)?['amount'],
        'creditTermDays':
            DemoRegistrationReferences.paymentTermDays(row['paymentTermCode']),
        'assignedSalesRepId': row['assignedRepId'],
        'createdAt': row['createdAt'],
      };

  /// The `{ customer, financial }` body of `…/stop-information`.
  static DataMap stopInformationOf(DataMap row) {
    final limit = _amount(row['creditLimit']);
    final balance = _amount(row['creditBalance']);
    final available = limit - balance < 0 ? 0.0 : limit - balance;
    final contacts = row['contacts'];
    final termCode = row['paymentTermCode'] as String?;
    return {
      'customer': {
        'id': row['id'],
        'code': row['customerCode'],
        'name': row['shopName'],
        'nameKh': row['khName'],
        'contact': contacts is List && contacts.isNotEmpty
            ? (contacts.first as Map)['name']
            : null,
        'phone': row['phone'],
        'address': row['addressLine1'] ?? row['district'],
        'telegram': row['telegram'],
        'outletType': row['outletType'] ?? 'Retailer',
      },
      'financial': {
        'currency': row['currency'] ?? currency,
        'creditLimit': money(limit),
        'creditBalance': money(balance),
        'availableCredit': money(available),
        'creditLimitDate': row['createdAt'],
        'paymentTermCode': termCode,
        'paymentTermLabel':
            DemoRegistrationReferences.paymentTermLabel(termCode),
        'paymentTermDays': DemoRegistrationReferences.paymentTermDays(termCode),
      },
    };
  }

  static DataMap money(double amount) =>
      {'amount': amount, 'currency': currency};

  static String iso(DateTime value) => value.toUtc().toIso8601String();

  static double _amount(Object? raw) =>
      raw is Map ? (raw['amount'] as num?)?.toDouble() ?? 0 : 0;
}
