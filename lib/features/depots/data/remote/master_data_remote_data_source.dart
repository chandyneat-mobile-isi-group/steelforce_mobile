import 'package:steelforce/features/depots/domain/entities/master_data_item.dart';
import 'package:steelforce/features/depots/domain/entities/master_data_type.dart';

/// The SAP Depot Helper API (`/api/CustHelper/*`) as seen from the app.
///
/// This is the seam ADR-009 decision 4 describes: today the only implementation
/// is [MockMasterDataRemoteDataSource], because `core/network/sap_client.dart` is
/// still a 0-byte stub and `ENGINEERING_STANDARD.md` §2 forbids building on it.
/// When the gateway lands, a real implementation registers here and nothing above
/// this boundary changes.
///
/// Implementations must throw a typed `Failure` from `core/error/failures.dart`
/// — never a raw `DioException` — so presentation never sees transport detail.
abstract interface class MasterDataRemoteDataSource {
  /// Fetches every row for [type]. A SAP 404 means "zero rows", not a server
  /// fault (see the API document §4.4), and must surface as an empty list.
  Future<List<MasterDataItem>> fetch(MasterDataType type);
}
