/// The `GET /mobile/depots/references` body a demo build answers with.
///
/// Shaped like the live payload captured in
/// `test/features/depots/depot_references_live_payload_test.dart`, broadened
/// so every dropdown has a realistic choice. The sales area leads with the
/// `DemoSeed` codes so a registration and the seeded depots share one area.
///
/// Values are illustrative, not the ERP's real configuration.
///
/// TODO(release-gate): demo-only, selected only when DataSourceMode.useMocks.
library;

import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/core/utils/typedefs.dart';

abstract final class DemoRegistrationReferences {
  /// Payment term code → (label, net days).
  static const Map<String, (String, int)> paymentTerms = {
    'TCOD': ('Cash on delivery', 0),
    'TCIA': ('Cash in advance', 0),
    'T015': ('15 days due net', 15),
    'T030': ('30 days due net', 30),
    'T045': ('45 days due net', 45),
    'T060': ('60 days due net', 60),
  };

  static String? paymentTermLabel(Object? code) => paymentTerms[code]?.$1;

  static int? paymentTermDays(Object? code) => paymentTerms[code]?.$2;

  /// Depot groups and the price group that pairs with each, matched by name
  /// the way `SapReferenceOptions.priceGroupFor` resolves them.
  static const List<(String, String, String)> _groups = [
    ('01', '11', 'End-User'),
    ('02', '21', 'Local Builder'),
    ('03', '31', 'Craftsman'),
    ('04', '41', 'PIPE Maker'),
    ('05', '51', 'Contractor'),
    ('06', '61', 'Developer'),
    ('07', '71', 'Distributor'),
  ];

  static DataMap _option(String code, String name) =>
      {'code': code, 'name': name};

  /// The envelope's `data` object, stamped as refreshed at [now].
  static DataMap data(DateTime now) => {
        'catalogues': {
          'PartnerGroup': [
            _option('Z001', 'Local Depot'),
            _option('Z002', 'Export Depot'),
            _option('Z003', 'Group Member Depot'),
          ],
          'SalesOrg': [
            _option(DemoSeed.salesOrg, 'Phnom Penh (ISI)'),
            _option('0003', 'Battambang'),
            _option('0004', 'Sihanoukville'),
            _option('0009', 'Siem Riep'),
          ],
          'DistributionChannel': [
            _option(DemoSeed.distributionChannel, 'End-User'),
            _option('20', 'Local Builder'),
            _option('50', 'Contractor'),
            _option('70', 'Distributor'),
          ],
          'Division': [
            _option(DemoSeed.division, 'ISI Steel'),
            _option('20', 'Mekong Homes'),
          ],
          'DepotGroup': [for (final g in _groups) _option(g.$1, g.$3)],
          'PriceGroup': [for (final g in _groups) _option(g.$2, g.$3)],
          'PaymentTerm': [
            for (final e in paymentTerms.entries) _option(e.key, e.value.$1),
          ],
          'ShippingCondition': [
            _option('01', 'ISI Services'),
            _option('02', 'Depot pickup'),
          ],
          'SalesOffice': [
            _option('0001', 'Phnom Penh'),
            _option('0009', 'Siem Riep'),
          ],
          'SalesGroup': [
            _option('010', 'Channel Sales'),
            _option('020', 'Project Sales'),
          ],
        },
        'synchronisedAt': now.toUtc().toIso8601String(),
      };
}
