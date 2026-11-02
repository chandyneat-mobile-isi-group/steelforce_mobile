// TODO(release-gate): demo-only data source; must never be registered in a release mobile build (USE_MOCK_DATA=false).
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/mock_latency.dart';
import 'package:steelforce/core/utils/money.dart';
import 'package:steelforce/features/depots/data/remote/depot_stop_information_remote_data_source.dart';
import 'package:steelforce/features/depots/data/remote/mock_depot_backend.dart';
import 'package:steelforce/features/depots/domain/entities/depot_list_kind.dart';
import 'package:steelforce/features/depots/domain/entities/depot_stop_information.dart';

/// `GET /api/v1/mobile/depots/{depotId}/stop-information`, built from the
/// depot [MockDepotBackend] holds — so the stop screen and the depot detail
/// always agree, including for a shop registered during the demo.
class MockDepotStopInformationRemoteDataSource
    implements DepotStopInformationRemoteDataSource {
  const MockDepotStopInformationRemoteDataSource(this._backend);

  final MockDepotBackend _backend;

  @override
  Future<DepotStopInformation> fetch(String depotId) async {
    await MockLatency.tick();
    final depot = _backend.find(depotId);
    if (depot == null) {
      // The live route's single answer for "no such outlet" and "not yours".
      throw const ApiException(
          ApiError(code: ApiErrorCodes.depotNotFound, statusCode: 404));
    }
    final area = depot.salesAreas?.firstOrNull;
    final currency = depot.currency;
    return DepotStopInformation(
      outlet: DepotOutletProfile(
        id: depot.id,
        code: depot.depotCode,
        name: depot.shopName,
        nameKh: depot.khName,
        contact: depot.contacts.firstOrNull?.name ?? depot.ownerName,
        phone: depot.phone,
        address: depot.address,
        telegram: depot.profile?.telegram,
        outletType: switch (depot.listKind) {
          DepotListKind.depot => 'Depot',
          DepotListKind.nonBp => 'Non-BP',
          DepotListKind.awaitingApproval => 'New outlet',
        },
      ),
      credit: DepotCreditProfile(
        creditLimit: Money(depot.creditLimit, currency),
        creditBalance: Money(depot.creditBalance, currency),
        availableCredit: Money(depot.availableCredit, currency),
        currency: currency,
        creditLimitDate: area?.creditLimitDate,
        paymentTermCode: area?.paymentTermsCode,
        paymentTermLabel: area?.paymentTermsName,
        paymentTermDays: area?.creditTermDays,
      ),
    );
  }
}
