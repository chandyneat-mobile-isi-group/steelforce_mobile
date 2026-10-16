/// The identities every demo data source agrees on.
///
/// Demo data spans features that may not import one another's data layers —
/// a route's stops, a quotation's customer and a visit's check-in all name the
/// same depot. Each feature keeps its own fixtures; this file holds only the
/// shared keys, so a depot opened from a route is the depot that has the
/// quotations.
///
/// Every value is fictitious: invented names, `0xx 000 xxx` phone numbers and
/// coordinates scattered around Phnom Penh. No record here describes a real
/// customer.
///
/// TODO(release-gate): demo-only, referenced only by demo data sources.
abstract final class DemoSeed {
  const DemoSeed._();

  /// Sign-in for the demo account. Accepted only by the demo auth source.
  static const String signInPhone = '123456789';
  static const String signInPassword = '123456789';

  /// Code the demo password-reset flow accepts.
  static const String resetCode = '123456';

  static const String repId = 'demo-rep-0001';
  static const String repPersonnelNo = '90000001';
  static const String repName = 'Demo Sales Rep';
  static const String repNameKm = 'អ្នកលក់សាកល្បង';
  static const String repEmail = 'demo.rep@example.com';
  static const String salesOrg = '1000';
  static const String distributionChannel = '10';
  static const String division = '00';

  static const String managerName = 'Demo Sales Manager';

  /// Today's planned route.
  static const String todayRouteId = 'demo-route-today';

  static const List<DemoDepot> depots = [
    DemoDepot(
      id: 'demo-depot-001',
      code: '1000000101',
      name: 'Mekong Steel Depot',
      nameKm: 'ឃ្លាំងដែកមេគង្គ',
      province: 'Phnom Penh',
      district: 'Chamkar Mon',
      ownerName: 'Sok Dara',
      phone: '012 000 101',
      latitude: 11.5449,
      longitude: 104.9214,
    ),
    DemoDepot(
      id: 'demo-depot-002',
      code: '1000000102',
      name: 'Riverside Building Supply',
      nameKm: 'ហាងសម្ភារៈសំណង់មាត់ទន្លេ',
      province: 'Phnom Penh',
      district: 'Daun Penh',
      ownerName: 'Lim Sophea',
      phone: '012 000 102',
      latitude: 11.5683,
      longitude: 104.9282,
    ),
    DemoDepot(
      id: 'demo-depot-003',
      code: '1000000103',
      name: 'Golden Roof Hardware',
      nameKm: 'ហាងគ្រឿងដែកដំបូលមាស',
      province: 'Phnom Penh',
      district: 'Toul Kork',
      ownerName: 'Heng Vuthy',
      phone: '012 000 103',
      latitude: 11.5795,
      longitude: 104.8979,
    ),
    DemoDepot(
      id: 'demo-depot-004',
      code: '1000000104',
      name: 'Sen Sok Construction Mart',
      nameKm: 'ផ្សារសំណង់សែនសុខ',
      province: 'Phnom Penh',
      district: 'Sen Sok',
      ownerName: 'Meas Rithy',
      phone: '012 000 104',
      latitude: 11.6001,
      longitude: 104.8858,
    ),
    DemoDepot(
      id: 'demo-depot-005',
      code: '1000000105',
      name: 'Chbar Ampov Steel House',
      nameKm: 'ផ្ទះដែកច្បារអំពៅ',
      province: 'Phnom Penh',
      district: 'Chbar Ampov',
      ownerName: 'Chea Bopha',
      phone: '012 000 105',
      latitude: 11.5367,
      longitude: 104.9551,
    ),
    DemoDepot(
      id: 'demo-depot-006',
      code: '1000000106',
      name: 'Kandal Rebar Center',
      nameKm: 'មជ្ឈមណ្ឌលដែកសសៃកណ្ដាល',
      province: 'Kandal',
      district: 'Ta Khmau',
      ownerName: 'Keo Samnang',
      phone: '012 000 106',
      latitude: 11.4826,
      longitude: 104.9455,
    ),
    DemoDepot(
      id: 'demo-depot-007',
      code: '1000000107',
      name: 'Meanchey Metal Works',
      nameKm: 'រោងជាងដែកមានជ័យ',
      province: 'Phnom Penh',
      district: 'Meanchey',
      ownerName: 'Nhem Pisey',
      phone: '012 000 107',
      latitude: 11.5262,
      longitude: 104.9188,
    ),
    DemoDepot(
      id: 'demo-depot-008',
      code: '1000000108',
      name: 'Por Sen Chey Builders Depot',
      nameKm: 'ឃ្លាំងសំណង់ពោធិ៍សែនជ័យ',
      province: 'Phnom Penh',
      district: 'Por Sen Chey',
      ownerName: 'Ros Kosal',
      phone: '012 000 108',
      latitude: 11.5489,
      longitude: 104.8457,
    ),
    DemoDepot(
      id: 'demo-depot-009',
      code: '1000000109',
      name: 'Russey Keo Zinc & Pipe',
      nameKm: 'ហាងស័ង្កសី និងបំពង់ឫស្សីកែវ',
      province: 'Phnom Penh',
      district: 'Russey Keo',
      ownerName: 'Ly Channary',
      phone: '012 000 109',
      latitude: 11.6203,
      longitude: 104.9076,
    ),
    DemoDepot(
      id: 'demo-depot-010',
      code: '1000000110',
      name: 'Takhmao Home Builder',
      nameKm: 'អ្នកសាងសង់ផ្ទះតាខ្មៅ',
      province: 'Kandal',
      district: 'Ta Khmau',
      ownerName: 'Pich Vannak',
      phone: '012 000 110',
      latitude: 11.4733,
      longitude: 104.9391,
    ),
    DemoDepot(
      id: 'demo-depot-011',
      code: '1000000111',
      name: 'Prek Pnov Steel Yard',
      nameKm: 'ទីធ្លាដែកព្រែកព្នៅ',
      province: 'Phnom Penh',
      district: 'Prek Pnov',
      ownerName: 'Sam Rachana',
      phone: '012 000 111',
      latitude: 11.6511,
      longitude: 104.8722,
    ),
    DemoDepot(
      id: 'demo-depot-012',
      code: '1000000112',
      name: 'Dangkao Roofing Supply',
      nameKm: 'ហាងផ្គត់ផ្គង់ដំបូលដង្កោ',
      province: 'Phnom Penh',
      district: 'Dangkao',
      ownerName: 'Tep Sothea',
      phone: '012 000 112',
      latitude: 11.5104,
      longitude: 104.8735,
    ),
  ];

  /// Depots on today's route, in visiting order.
  static List<DemoDepot> get todayStops => depots.sublist(0, 6);

  static DemoDepot? depotById(String id) {
    for (final d in depots) {
      if (d.id == id || d.code == id) return d;
    }
    return null;
  }
}

/// A demo customer depot's shared identity. Feature fixtures add the rest.
class DemoDepot {
  const DemoDepot({
    required this.id,
    required this.code,
    required this.name,
    required this.nameKm,
    required this.province,
    required this.district,
    required this.ownerName,
    required this.phone,
    required this.latitude,
    required this.longitude,
  });

  final String id;

  /// The SAP business-partner number the backend would assign.
  final String code;
  final String name;
  final String nameKm;
  final String province;
  final String district;

  /// The shop's owner and main contact, so every screen names the same person.
  final String ownerName;
  final String phone;
  final double latitude;
  final double longitude;
}
