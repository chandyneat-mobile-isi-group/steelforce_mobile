// TODO(release-gate): demo-only data source; must never be registered in a release mobile build (USE_MOCK_DATA=false).
import 'package:steelforce/features/depots/data/datasources/business_partner_remote_data_source.dart';
import 'package:steelforce/features/depots/data/models/business_partner_request_model.dart';
import 'package:steelforce/features/depots/data/models/business_partner_response_model.dart';
import 'package:steelforce/features/depots/data/remote/mock_depot_backend.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_result.dart';

/// `POST /api/v1/mobile/depots/business-partner`, answered as the middleware
/// does for a field registration: accepted and parked for HQ approval, with a
/// platform id and no SAP number yet.
///
/// A dry run (`Commit: false`) answers the same way without keeping anything.
/// Nothing reaches a server and no SAP number is ever invented.
class MockBusinessPartnerRemoteDataSource
    implements BusinessPartnerRemoteDataSource {
  const MockBusinessPartnerRemoteDataSource(this._backend);

  final MockDepotBackend _backend;

  static const Duration _writeLatency = Duration(milliseconds: 800);

  @override
  Future<BusinessPartnerResponseModel> createBusinessPartner(
    BusinessPartnerRequestModel request,
  ) async {
    await Future<void>.delayed(_writeLatency);
    final localId = request.commit
        ? _backend.nextId('demo-bp')
        : 'demo-dry-run-${_backend.now().millisecondsSinceEpoch}';
    return BusinessPartnerResponseModel(
      localId: localId,
      status: BpSubmissionStatus.pendingHq,
    );
  }
}
