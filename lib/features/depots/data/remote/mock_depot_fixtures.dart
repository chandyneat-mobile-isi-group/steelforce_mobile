// TODO(release-gate): demo-only data source; must never be registered in a release mobile build (USE_MOCK_DATA=false).
import 'package:steelforce/features/depots/domain/entities/depot_profile.dart';

/// Identities and codes the demo depot backend shares across its sources.
///
/// The rep and territory match the demo account other features seed, and the
/// sales-area codes are the ones `MockMasterDataRemoteDataSource` serves, so
/// the registration dropdowns and the seeded depots read as one dataset.
/// Everything here is fictional.
abstract final class MockDepotFixtures {
  static const repId = 'demo-rep-001';
  static const repCode = 'DEMO001';
  static const repName = 'Sokha Chan';
  static const territory = 'PP-01';
  static const territoryName = 'Phnom Penh';
  static const province = 'Phnom Penh';
  static const currency = 'USD';

  static const salesOrg = '1000';
  static const salesOrgName = 'Sales Org Cambodia';
  static const division = '10';
  static const divisionName = 'Steel';

  static const DepotSalesEmployee demoRep = DepotSalesEmployee(
    employeeCode: repCode,
    employeeName: repName,
    territoryCode: territory,
    territoryName: territoryName,
    branchCode: 'PP01',
    branchName: 'Phnom Penh Head Office',
    regionCode: 'R01',
    regionName: 'Phnom Penh Region',
  );

  /// Payment term code → (label, net days), as master data names them.
  static const Map<String, (String, int)> paymentTerms = {
    'Z001': ('Immediate payment', 0),
    'Z002': ('Net 30 days', 30),
    'Z003': ('Net 60 days', 60),
    'Z004': ('50% deposit, balance on delivery', 0),
  };

  /// NCDD province codes, as the address step's geo selector sends them.
  static const Map<String, String> provinces = {
    '01': 'Banteay Meanchey',
    '02': 'Battambang',
    '03': 'Kampong Cham',
    '04': 'Kampong Chhnang',
    '05': 'Kampong Speu',
    '06': 'Kampong Thom',
    '07': 'Kampot',
    '08': 'Kandal',
    '09': 'Koh Kong',
    '10': 'Kratie',
    '11': 'Mondul Kiri',
    '12': 'Phnom Penh',
    '13': 'Preah Vihear',
    '14': 'Prey Veng',
    '15': 'Pursat',
    '16': 'Ratanak Kiri',
    '17': 'Siemreap',
    '18': 'Preah Sihanouk',
    '19': 'Stung Treng',
    '20': 'Svay Rieng',
    '21': 'Takeo',
    '22': 'Oddar Meanchey',
    '23': 'Kep',
    '24': 'Pailin',
    '25': 'Tboung Khmum',
  };
}
