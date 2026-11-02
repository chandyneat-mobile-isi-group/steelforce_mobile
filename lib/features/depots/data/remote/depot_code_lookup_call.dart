import 'package:dio/dio.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/depots/data/models/portal_depot_mapper.dart';
import 'package:steelforce/features/depots/domain/entities/depot_code_lookup.dart';

/// `GET /depots/by-code/{code}` — whether a code names a depot the
/// platform or SAP knows. Kept apart from the list calls in
/// `ApiDepotRemoteDataSource`, which delegates here.
Future<DepotCodeLookup> lookupDepotByCode(Dio client, String code) async {
  try {
    final res = await client.get<dynamic>(
      '${ApiEndpoints.depotsByCodeEndpoint}/$code',
      // 404 and 502 are answers, not transport failures, so they must reach
      // the branching below instead of being thrown as DioExceptions.
      options: Options(
        validateStatus: (status) =>
            status != null && (status == 200 || status == 404 || status == 502),
      ),
    );

    switch (res.statusCode) {
      case 200:
        // The portal envelope: `{ data, meta }`. `ApiEnvelope` insists on a
        // `success`-shaped body and would reject this.
        final depot = PortalDepotMapper.fromEnvelope(res.data);
        return depot == null ? const DepotCodeAbsent() : DepotCodeFound(depot);

      case 404:
        // `Depot.NotFoundByCode` — neither the platform nor SAP has it.
        // The only outcome where offering to register the shop is safe.
        return const DepotCodeAbsent();

      default:
        // 502: the ERP could not be reached. The depot may well exist, so
        // this must never be presented as "not found" — a registration
        // offered here creates a duplicate business partner in SAP.
        return const DepotCodeUnavailable();
    }
  } on DioException catch (e) {
    throw ApiException(ApiError.fromDio(e));
  }
}
