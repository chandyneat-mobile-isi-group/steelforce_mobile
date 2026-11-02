// TODO(release-gate): demo-only data source; must never be registered in a release mobile build (USE_MOCK_DATA=false).
import 'package:steelforce/features/depots/data/models/depot_contact_model.dart';
import 'package:steelforce/features/depots/data/models/depot_model.dart';
import 'package:steelforce/features/depots/data/remote/mock_depot_fixtures.dart';
import 'package:steelforce/features/depots/domain/entities/depot_list_kind.dart';
import 'package:steelforce/features/depots/domain/entities/depot_profile.dart';
import 'package:steelforce/features/depots/domain/entities/depot_sales_area.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';

/// The demo backend's starting depot book.
///
/// `DPT-DEMO-001` … `008` are the trading depots the demo visit plans point
/// at — keep the ids and order stable. `N01` (a Non-BP outlet) and `P01` (a
/// registration awaiting approval) exist so every Depots tab has a row.
abstract final class MockDepotSeed {
  static const List<_Seed> _seeds = [
    _Seed('DPT-DEMO-001', 'Mekong Steel Supply', 'ហាងដែកមេគង្គ', 'Chea Dara',
        '101', 'Russey Keo', 'National Road 5', '45', 11.6020, 104.9010,
        group: '01',
        channel: 'Distributor',
        term: 'Z002',
        money: (25000, 8200),
        visitDaysAgo: 6,
        orders: (42, 186400)),
    _Seed('DPT-DEMO-002', 'Angkor Building Materials', 'សម្ភារសំណង់អង្គរ',
        'Lim Sophea', '102', 'Sen Sok', 'Street 1986', '12B', 11.5900, 104.8650,
        group: '01',
        channel: 'Distributor',
        term: 'Z002',
        money: (18000, 4100),
        visitDaysAgo: 9,
        orders: (31, 122750)),
    _Seed('DPT-DEMO-003', 'Golden Roof Hardware', 'ហាងដំបូលមាស', 'Heng Vuthy',
        '103', 'Chbar Ampov', 'National Road 1', '88', 11.5480, 104.9450,
        group: '02',
        channel: 'Retail',
        term: 'Z001',
        money: (6000, 1250),
        visitDaysAgo: 3,
        orders: (27, 48300)),
    _Seed('DPT-DEMO-004', 'Sovann Iron Works', 'រោងដែកសុវណ្ណ', 'Sok Pisey',
        '104', 'Mean Chey', 'Street 371', '7', 11.5300, 104.9100,
        group: '03',
        channel: 'Direct Sales',
        term: 'Z003',
        money: (30000, 17600),
        visitDaysAgo: 14,
        orders: (19, 210900)),
    _Seed(
        'DPT-DEMO-005',
        'Riverside Construction Depot',
        'ឃ្លាំងសំណង់មាត់ទន្លេ',
        'Kim Rathana',
        '105',
        'Chroy Changvar',
        'National Road 6A',
        '210',
        11.5950,
        104.9250,
        group: '01',
        channel: 'Distributor',
        term: 'Z004',
        money: (22000, 9900),
        visitDaysAgo: 2,
        orders: (36, 154200)),
    _Seed(
        'DPT-DEMO-006',
        'Bayon Steel & Pipe',
        'ដែក និងបំពង់បាយ័ន',
        'Meas Sovann',
        '106',
        'Toul Kork',
        'Street 289',
        '56',
        11.5750,
        104.8950,
        group: '02',
        channel: 'Retail',
        term: 'Z002',
        money: (9000, 2300),
        visitDaysAgo: 5,
        orders: (24, 67800)),
    _Seed('DPT-DEMO-007', 'Prey Veng Road Hardware', 'ហាងគ្រឿងដែកផ្លូវព្រៃវែង',
        'Tep Bopha', '107', 'Dangkao', 'Street 201R', '19', 11.5100, 104.8800,
        group: '02',
        channel: 'Retail',
        term: 'Z001',
        money: (4000, 600),
        visitDaysAgo: 21,
        orders: (12, 21400)),
    _Seed(
        'DPT-DEMO-008',
        'Lotus Metal Trading',
        'ពាណិជ្ជកម្មលោហៈឈូក',
        'Ouk Sreyneang',
        '108',
        'Por Senchey',
        'Veng Sreng Boulevard',
        '330',
        11.5550,
        104.8300,
        group: '04',
        channel: 'Direct Sales',
        term: 'Z003',
        money: (40000, 12500),
        visitDaysAgo: 11,
        orders: (15, 238600)),
    _Seed(
        'DPT-DEMO-N01',
        'Tuol Sangke Hardware Stall',
        'តូបគ្រឿងដែកទួលសង្កែ',
        'Pich Chanthy',
        '109',
        'Russey Keo',
        'Street 70',
        '3',
        11.5980,
        104.9060,
        group: '02',
        channel: 'Retail',
        term: 'Z001',
        visitDaysAgo: 30,
        type: DepotTypes.nonDepot),
    _Seed(
        'DPT-DEMO-P01',
        'Kampot Rebar Corner',
        'ហាងដែកសរសៃកំពត',
        'Nhem Sokunthea',
        '110',
        'Dangkao',
        'Street 217',
        '64',
        11.5150,
        104.8720,
        group: '03',
        channel: 'Retail',
        term: 'Z001',
        type: DepotTypes.draft,
        status: DepotStatus.pendingApproval),
  ];

  /// The seeded book, stamped relative to [now] so it always looks current.
  static List<DepotModel> build(DateTime now) => [
        for (final (i, s) in _seeds.indexed) _build(s, now, index: i),
      ];

  static DepotModel _build(_Seed s, DateTime now, {required int index}) {
    final trading = s.type == DepotTypes.depot;
    final term = MockDepotFixtures.paymentTerms[s.term];
    final phone = '+855 12 000 ${s.phoneSuffix}';
    final (limit, balance) = s.money;
    final (orders, lifetime) = s.orders;
    final visited = s.visitDaysAgo;
    return DepotModel(
      id: s.id,
      sapDepotId: trading ? '${2000100 + index}' : null,
      depotCode: s.id,
      shopName: s.en,
      enName: s.en,
      khName: s.km,
      ownerName: s.owner,
      phone: phone,
      address: '${s.house} ${s.street}, ${s.district}, '
          '${MockDepotFixtures.province}',
      province: MockDepotFixtures.province,
      district: s.district,
      territory: MockDepotFixtures.territory,
      latitude: s.lat,
      longitude: s.lng,
      creditLimit: limit,
      creditBalance: balance,
      currency: MockDepotFixtures.currency,
      status: s.status,
      assignedRepId: MockDepotFixtures.repId,
      assignedRepName: MockDepotFixtures.repName,
      updatedAt: now.subtract(Duration(days: 1 + index)),
      createdAt: now.subtract(Duration(days: 400 - index * 30)),
      lastVisitDate:
          visited == null ? null : now.subtract(Duration(days: visited)),
      lastOrderDate:
          orders == 0 ? null : now.subtract(Duration(days: (visited ?? 0) + 2)),
      lifetimeValue: lifetime,
      totalOrders: orders,
      openOpportunityCount: index % 3,
      salesOrg: MockDepotFixtures.salesOrg,
      division: MockDepotFixtures.division,
      distributionChannel: s.channel,
      depotGroup: s.group,
      priceGroup: 'P1',
      taxNumber: trading ? 'K00${index + 1}-90000${index + 1}' : null,
      depotType: s.type,
      createdBy: trading ? null : MockDepotFixtures.repCode,
      productsPurchased: const ['Rebar', 'Roofing sheet', 'Steel pipe'],
      contacts: [
        DepotContactModel(
          id: '${s.id}-contact-1',
          name: s.owner,
          role: 'Owner',
          phone: phone,
        ),
      ],
      salesEmployees: const [MockDepotFixtures.demoRep],
      profile: DepotProfile(
        outletStatus: trading ? 'Active' : 'New',
        houseNumber: s.house,
        addressLine: s.street,
        primarySupplier: 'ISI Phnom Penh Branch',
        primarySupplierCode: 'BR-PP',
        secondarySupplier: 'ISI Steel Factory',
        secondarySupplierCode: 'FC-01',
        tier: index < 3 ? 'Gold' : 'Silver',
        channel: s.channel,
        coverageType: 'Direct',
        visit: 'Weekly',
        territory: MockDepotFixtures.territory,
      ),
      salesAreas: [
        DepotSalesArea(
          salesOrgCode: MockDepotFixtures.salesOrg,
          salesOrgName: MockDepotFixtures.salesOrgName,
          channelName: s.channel,
          division: MockDepotFixtures.division,
          divisionName: MockDepotFixtures.divisionName,
          paymentTermsCode: s.term,
          paymentTermsName: term?.$1,
          creditLimit: limit,
          creditLimitDate: now.subtract(const Duration(days: 90)),
          creditTermDays: term?.$2,
        ),
      ],
    );
  }
}

/// One seeded depot, positional so the table above stays scannable.
class _Seed {
  const _Seed(
    this.id,
    this.en,
    this.km,
    this.owner,
    this.phoneSuffix,
    this.district,
    this.street,
    this.house,
    this.lat,
    this.lng, {
    required this.group,
    required this.channel,
    required this.term,
    this.money = (0, 0),
    this.visitDaysAgo,
    this.orders = (0, 0),
    this.type = DepotTypes.depot,
    this.status = DepotStatus.active,
  });

  final String id, en, km, owner, phoneSuffix, district, street, house;
  final double lat, lng;
  final String group, channel, term, type;

  /// (credit limit, credit balance).
  final (double, double) money;
  final int? visitDaysAgo;

  /// (total orders, lifetime value).
  final (int, double) orders;
  final DepotStatus status;
}
