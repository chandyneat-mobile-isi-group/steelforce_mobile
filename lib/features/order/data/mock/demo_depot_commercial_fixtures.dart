import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/mock/isi_demo_catalog.dart';

/// A standing on-invoice agreement between ISI and one demo depot.
class DemoAgreement {
  const DemoAgreement({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.percent,
  });

  final String id;
  final String categoryId;
  final String categoryName;
  final double percent;
}

/// The commercial terms the demo backend holds per depot: standing
/// agreements, incentives, promotions and the rep's discount authority.
///
/// TODO(release-gate): demo-only, selected only when `DataSourceMode.useMocks`.
///
/// Keyed by the shared [DemoSeed] depots so the depot opened from a route is
/// the one whose quotation lines carry these agreement rows. Every depot holds
/// one or two agreements; the figures are fictitious.
abstract final class DemoDepotCommercial {
  /// The pickup allowance a `Pickup` quotation earns on every line.
  static const double pickupPercent = 1.0;

  /// The manual discount a sales rep may give without escalation.
  static const double repAuthorityPercent = 3.0;

  /// The most a line may be discounted in total — agreement, pickup and
  /// manual together. Above it the backend refuses rather than trims.
  static const double lineCapPercent = 7.0;

  static const List<(String, String, double)> _rotating = [
    (IsiDemoCatalog.coldFormCategoryId, 'Cold Formed Sections', 2.0),
    (IsiDemoCatalog.giPipeCategoryId, 'Galvanized Pipes', 1.0),
    (IsiDemoCatalog.steelSheetCategoryId, 'GI Steel Sheet', 1.25),
  ];

  static List<DemoAgreement> agreementsFor(String depotId) {
    final i = _depotIndex(depotId);
    final rotating = _rotating[i % _rotating.length];
    return [
      if (i.isEven)
        DemoAgreement(
          id: 'agr-$i-palm',
          categoryId: IsiDemoCatalog.palmProfileCategoryId,
          categoryName: 'Palm Profile Roofing',
          percent: 1.5,
        ),
      DemoAgreement(
        id: 'agr-$i-${i % _rotating.length}',
        categoryId: rotating.$1,
        categoryName: rotating.$2,
        percent: rotating.$3,
      ),
    ];
  }

  static DemoAgreement? agreementFor(String depotId, String categoryId) {
    for (final a in agreementsFor(depotId)) {
      if (a.categoryId == categoryId) return a;
    }
    return null;
  }

  static List<DataMap> agreementsJson(String depotId) {
    final now = DateTime.now();
    return [
      for (final a in agreementsFor(depotId))
        {
          'id': a.id,
          'category': a.categoryName,
          'percent': a.percent,
          'kind': 'onInvoice',
          'status': 'Active',
          'effectiveFrom': DateTime(now.year, 1, 1).toIso8601String(),
          'endsOn': DateTime(now.year, 12, 31).toIso8601String(),
          'customers': depotName(depotId),
        },
    ];
  }

  static DataMap authorityJson() => {
        'level': 1,
        'roleName': 'Sales Representative',
        'maxManualDiscountPercent': repAuthorityPercent,
        'lineDiscountCapPercent': lineCapPercent,
        'currency': 'US3',
        'suggestedChips': [0.5, 1.0, 1.5, 2.0, 2.5, 3.0],
      };

  /// The quotation builder's incentive groups, in `PromoGroup` wire shape.
  static List<DataMap> incentivesJson(String depotId) {
    final now = DateTime.now();
    final i = _depotIndex(depotId);
    String inDays(int d) =>
        DateTime(now.year, now.month, now.day + d).toIso8601String();
    return [
      {
        'groupId': 'depot_discount',
        'promos': [
          for (final a in agreementsFor(depotId))
            {
              'id': a.id,
              'title': 'On-Invoice Discount — ${a.categoryName}',
              'kind': 'onInvoice',
              'value': {'type': 'percent', 'percent': a.percent},
              'status': 'active',
              'endsOn': DateTime(now.year, 12, 31).toIso8601String(),
              'category': a.categoryName,
              'customers': depotName(depotId),
            },
        ],
      },
      {
        'groupId': 'cod_pickup',
        'promos': [
          {
            'id': 'pickup-$i',
            'title': 'Pickup Allowance',
            'summary': 'Collected from the ISI yard by the depot.',
            'kind': 'paymentTerm',
            'value': {'type': 'percent', 'percent': pickupPercent},
            'status': 'active',
            'endsOn': inDays(45),
            'requires': ['pickup'],
            'customers': 'All Depots',
          },
        ],
      },
      {
        'groupId': 'depot_requests',
        'promos': [
          {
            'id': 'req-$i',
            'code': 'DR-${now.year}-${(310 + i).toString().padLeft(4, '0')}',
            'title': 'Depot request — project volume',
            'kind': 'depotRequest',
            'value': {'type': 'percent', 'percent': 1.5},
            'status': i.isEven ? 'approved' : 'pending',
            'endsOn': inDays(20 + i),
            'customers': depotName(depotId),
          },
        ],
      },
      {
        'groupId': 'free_goods',
        'promos': [
          {
            'id': 'fg-palm',
            'title': 'Palm Roofing Free Goods',
            'summary': 'Volume incentive on Palm profile sheets.',
            'kind': 'buyXGetY',
            'value': {'type': 'buyGet', 'buy': 300, 'get': 15, 'unit': 'M'},
            'status': 'active',
            'endsOn': inDays(6),
            'category': 'Palm Profile Roofing',
            'customers': 'All Depots',
          },
        ],
      },
    ];
  }

  /// The outlet promotions list: every incentive the depot holds, flat.
  static List<DataMap> promotionsJson(String depotId) => [
        for (final group in incentivesJson(depotId))
          ...(group['promos'] as List).cast<DataMap>(),
      ];

  static String depotName(String depotId) =>
      DemoSeed.depotById(depotId)?.name ?? 'Depot $depotId';

  /// The depot's position in [DemoSeed.depots]; a depot created during the
  /// demo is placed by a stable hash so it still gets terms.
  static int _depotIndex(String depotId) {
    final depots = DemoSeed.depots;
    for (var i = 0; i < depots.length; i++) {
      if (depots[i].id == depotId || depots[i].code == depotId) return i;
    }
    return depotId.codeUnits.fold<int>(0, (h, c) => (h + c) % 997) %
        depots.length;
  }
}
