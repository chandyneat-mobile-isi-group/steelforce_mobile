/// `POST /api/v1/mobile/depots/business-partner`, answered in memory.
///
/// A committed registration is assigned the next SAP business-partner number
/// and written to [DemoDepotDirectory], so it reaches the depot book on the
/// next delta sync. A dry run (`Commit: false`) validates and stores nothing,
/// as the middleware does.
///
/// TODO(release-gate): demo-only, selected only when DataSourceMode.useMocks.
library;

import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/datasources/business_partner_remote_data_source.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_directory.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_fixtures.dart';
import 'package:steelforce/features/depots/data/models/business_partner_request_model.dart';
import 'package:steelforce/features/depots/data/models/business_partner_response_model.dart';

class DemoBusinessPartnerRemoteDataSource
    implements BusinessPartnerRemoteDataSource {
  const DemoBusinessPartnerRemoteDataSource(this._network, this._directory);

  final DemoNetwork _network;
  final DemoDepotDirectory _directory;

  @override
  Future<BusinessPartnerResponseModel> createBusinessPartner(
    BusinessPartnerRequestModel request,
  ) async {
    try {
      await _network.roundTrip();
    } on ApiException {
      // The live source reports a connection that never opened as a
      // NetworkException — the signal that the outbox may resend without a
      // duplicate check. The repository catches only that type, so the demo's
      // ApiException must not escape in its place.
      throw const NetworkException(
        message: 'No connection. The registration will be sent when you are '
            'back online.',
      );
    }

    if (!request.commit) {
      return BusinessPartnerResponseModel.fromJson(_body({
        'sapStatus': 'SUCCESS',
        'submitToSap': true,
        'Return': [
          {'TYPE': 'S', 'MESSAGE': 'Check completed without errors.'},
        ],
      }));
    }

    // Extending an existing partner keeps its number and adds no new depot.
    final existing = request.depotNumber.trim();
    if (existing.isNotEmpty) {
      final row = _directory.find(existing);
      return BusinessPartnerResponseModel.fromJson(_body({
        'customerCode': existing,
        'customerId': row?['id'] ?? existing,
        'sapStatus': 'CREATED',
        'submitToSap': true,
      }));
    }

    final code = _directory.nextPartnerNumber();
    final id = _directory.nextId();
    _directory.insert(DemoDepotFixtures.registered(
      id: id,
      code: code,
      name: request.name1,
      nameKm: request.name3,
      ownerName: request.coName.isNotEmpty ? request.coName : request.name2,
      phone: request.mobilePhone.isNotEmpty
          ? request.mobilePhone
          : request.telephone,
      street: [request.houseNo, request.street]
          .where((part) => part.isNotEmpty)
          .join(' '),
      district: request.district,
      city: request.city,
      latitude: double.tryParse(request.latitude),
      longitude: double.tryParse(request.longitude),
      depotGroup: request.depotGroup,
      priceGroup: request.priceGroup.isEmpty ? null : request.priceGroup,
      paymentTerm: request.paymentTerms,
      creditLimit: double.tryParse(request.creditLimit) ?? 0,
      salesOrg: request.salesOrg,
      distributionChannel: request.distributionChannel,
      division: request.division,
    ));

    return BusinessPartnerResponseModel.fromJson(_body({
      'customerCode': code,
      'customerId': id,
      'sapStatus': 'CREATED',
      'submitToSap': true,
    }));
  }

  /// The `{ data: … }` body the live endpoint returns; the model unwraps it.
  static DataMap _body(DataMap data) => {'success': true, 'data': data};
}
