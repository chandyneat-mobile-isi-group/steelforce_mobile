import 'package:steelforce/features/depots/data/remote/master_data_remote_data_source.dart';
import 'package:steelforce/features/depots/domain/entities/master_data_item.dart';
import 'package:steelforce/features/depots/domain/entities/master_data_type.dart';

/// Stands in for `/api/CustHelper/*` until `core/network/sap_client.dart` exists.
///
/// Values follow the shapes in `SapAPI_Technical_Document_v1_BP.docx` §4.2 (SAP
/// numeric org codes, `Z*` config codes) so the UI is exercised against
/// realistic data. They are **not** real SAP values — see ADR-009.
// TODO(release-gate): replace with the SAP-backed implementation once
// core/network/sap_client.dart is built. Must not ship in a release build.
class MockMasterDataRemoteDataSource implements MasterDataRemoteDataSource {
  const MockMasterDataRemoteDataSource();

  @override
  Future<List<MasterDataItem>> fetch(MasterDataType type) async {
    // Mimic a realistic LAN round-trip so loading and shimmer states are
    // actually observable during development.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return _fixtures[type] ?? const <MasterDataItem>[];
  }

  static const Map<MasterDataType, List<MasterDataItem>> _fixtures = {
    MasterDataType.salesOrg: [
      MasterDataItem(code: '1000', name: 'Sales Org Cambodia'),
      MasterDataItem(code: '2000', name: 'Sales Org Export'),
      MasterDataItem(code: '3000', name: 'Sales Org Project'),
    ],
    MasterDataType.distributionChannel: [
      MasterDataItem(code: '10', name: 'Direct Sales'),
      MasterDataItem(code: '20', name: 'Distributor'),
      MasterDataItem(code: '30', name: 'Retail'),
    ],
    MasterDataType.salesOffice: [
      MasterDataItem(code: 'PP01', name: 'Phnom Penh Head Office'),
      MasterDataItem(code: 'SR01', name: 'Siem Reap Branch'),
      MasterDataItem(code: 'SHV1', name: 'Sihanoukville Branch'),
      MasterDataItem(code: 'BTB1', name: 'Battambang Branch'),
    ],
    MasterDataType.salesGroup: [
      MasterDataItem(code: 'G01', name: 'Structural Steel'),
      MasterDataItem(code: 'G02', name: 'Roofing & Cladding'),
      MasterDataItem(code: 'G03', name: 'Reinforcement Bar'),
      MasterDataItem(code: 'G04', name: 'Project Accounts'),
    ],
    MasterDataType.depotGroup: [
      MasterDataItem(code: '01', name: 'Wholesale'),
      MasterDataItem(code: '02', name: 'Retail Shop'),
      MasterDataItem(code: '03', name: 'Contractor'),
      MasterDataItem(code: '04', name: 'Government Project'),
    ],
    MasterDataType.salesEmployee: [
      MasterDataItem(code: 'E1001', name: 'Sokha Novel'),
      MasterDataItem(code: 'E1002', name: 'Dara Chan'),
      MasterDataItem(code: 'E1003', name: 'Bopha Lim'),
      MasterDataItem(code: 'E1004', name: 'Vichea Sok'),
    ],
    MasterDataType.paymentTerm: [
      MasterDataItem(code: 'Z001', name: 'Immediate payment'),
      MasterDataItem(code: 'Z002', name: 'Net 30 days'),
      MasterDataItem(code: 'Z003', name: 'Net 60 days'),
      MasterDataItem(code: 'Z004', name: '50% deposit, balance on delivery'),
    ],
    MasterDataType.shippingCondition: [
      MasterDataItem(code: '01', name: 'Standard delivery'),
      MasterDataItem(code: '02', name: 'Express delivery'),
      MasterDataItem(code: '03', name: 'Depot pickup'),
    ],
    MasterDataType.priceGroup: [
      MasterDataItem(code: 'P1', name: 'Standard pricing'),
      MasterDataItem(code: 'P2', name: 'Volume discount'),
      MasterDataItem(code: 'P3', name: 'Project pricing'),
    ],
  };
}
