import 'package:dio/dio.dart';
import 'package:steelforce/core/network/api/api_defaults.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/models/depot_api_mapper.dart';
import 'package:steelforce/features/depots/data/models/depot_model.dart';
import 'package:steelforce/features/depots/data/remote/depot_remote_data_source.dart';
import 'package:steelforce/features/depots/data/models/portal_depot_mapper.dart';
import 'package:steelforce/features/depots/domain/entities/depot_code_lookup.dart';
import 'package:steelforce/features/depots/domain/entities/depot_draft.dart';
import 'package:steelforce/features/depots/data/remote/depot_sync_page.dart';

/// `GET /api/v1/mobile/depots` — the real thing.
///
/// Both list calls read the same envelope: the rows live at
/// `data.customers` and the paging plus sync bookkeeping at `metadata`.
///
/// The path says `depots`, every payload key says `customer`. That is ADR-0007,
/// not an oversight — the routes moved, the SAP-derived contract did not.
class ApiDepotRemoteDataSource implements DepotRemoteDataSource {
  const ApiDepotRemoteDataSource(this._client);

  final Dio _client;

  @override
  Future<DepotInitialPage> fetchInitial({
    required int page,
    required int pageSize,
  }) async {
    final envelope = await _list({
      // The API is one-based. The sync repository counts from 1 to match;
      // sending 0 would silently be treated as 1 and re-fetch the first page.
      'pageNumber': page,
      'pageSize': pageSize,
      // A stable order matters across pages: without it the server is free to
      // return rows in a different order per page and a paged run can both
      // miss and duplicate records.
      'sort': 'updatedAt',
    });

    final meta = envelope.metadata;
    return DepotInitialPage(
      // `customers`, not `depots` — the route moved to /mobile/depots, the
      // payload key did not (ADR-0007). The route feed made the same mistake
      // and silently returned zero stops until it was corrected.
      items:
          envelope.list('customers').map(DepotApiMapper.fromSummary).toList(),
      hasMore: meta?.hasNextPage ?? false,
      syncTimestamp: meta?.syncTimestamp,
      // Read back rather than echoed: `pageSize` is clamped to 200, not
      // rejected, so what was asked for is not necessarily what was used.
      pageSize: meta?.pageSize,
    );
  }

  @override
  Future<DepotDeltaPage> fetchDelta({
    required DateTime since,
    int page = 1,
    int pageSize = ApiDefaults.maxPageSize,
  }) async {
    final envelope = await _list({
      // Always the server's own previous `syncTimestamp`, never a device
      // clock. A `modifiedSince` more than five minutes ahead of server time
      // is rejected outright.
      'modifiedSince': since.toUtc().toIso8601String(),
      'pageNumber': page,
      'pageSize': pageSize,
      // `includeDeleted` is implied by `modifiedSince`, but stating it keeps
      // the intent obvious: this call *must* return tombstones.
      'includeDeleted': true,
      'sort': 'updatedAt',
    });

    final rows =
        envelope.list('customers').map(DepotApiMapper.fromSummary).toList();

    // Split once, here, so the repository never has to remember to check the
    // flag — dropping tombstones on the floor leaves deleted shops on the
    // phone forever.
    final upserted = <DepotModel>[];
    final deletedIds = <String>[];
    for (final row in rows) {
      if (row.deleted) {
        deletedIds.add(row.id);
      } else {
        upserted.add(row);
      }
    }

    final meta = envelope.metadata;
    return DepotDeltaPage(
      upserted: upserted,
      deletedIds: deletedIds,
      hasMore: meta?.hasNextPage ?? false,
      syncTimestamp: meta?.syncTimestamp,
    );
  }

  @override
  Future<DepotModel> fetchById(String id) async {
    try {
      final res =
          await _client.get<DataMap>('${ApiEndpoints.depotsEndpoint}/$id');
      final envelope = ApiEnvelope.fromBody(res.data);

      // Wrapped one level deeper than the list: `data.customer`, not `data`.
      // The key keeps SAP's noun even though the route says depot (ADR-0007).
      final depot = envelope.object('customer');
      if (depot == null) {
        throw const ServerException(
            message: 'The depot response was missing its payload.');
      }
      return DepotApiMapper.fromDetail(depot);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<DepotCodeLookup> lookupByCode(String code) async {
    try {
      final res = await _client.get<dynamic>(
        '${ApiEndpoints.depotsByCodeEndpoint}/$code',
        // 404 and 502 are answers, not transport failures, so they must reach
        // the branching below instead of being thrown as DioExceptions.
        options: Options(
          validateStatus: (status) =>
              status != null &&
              (status == 200 || status == 404 || status == 502),
        ),
      );

      switch (res.statusCode) {
        case 200:
          // The portal envelope: `{ data, meta }`. `ApiEnvelope` insists on a
          // `success`-shaped body and would reject this.
          final depot = PortalDepotMapper.fromEnvelope(res.data);
          return depot == null
              ? const DepotCodeAbsent()
              : DepotCodeFound(depot);

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

  @override
  Future<DepotModel> create(DepotDraft draft) async {
    try {
      final res = await _client.post<DataMap>(
        ApiEndpoints.depotsEndpoint,
        data: draft.toJson(),
      );
      final envelope = ApiEnvelope.fromBody(res.data);

      // 201 returns the created depot with a `Location` header. The body is
      // wrapped the same way the detail route is, but fall back to the flatter
      // shape rather than losing a depot the server has already committed —
      // the row exists either way, and failing here would leave the rep
      // believing the shop was never registered.
      final created = envelope.object('customer') ?? envelope.data;
      return DepotApiMapper.fromDetail(created);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  Future<ApiEnvelope> _list(DataMap query) async {
    try {
      final res = await _client.get<DataMap>(
        ApiEndpoints.depotsEndpoint,
        queryParameters: query,
      );
      return ApiEnvelope.fromBody(res.data);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }
}
