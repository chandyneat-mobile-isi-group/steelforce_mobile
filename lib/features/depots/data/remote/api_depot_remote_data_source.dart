import 'dart:math';

import 'package:dio/dio.dart';
import 'package:steelforce/features/depots/data/remote/depot_supplier_namer.dart';
import 'package:steelforce/core/network/api/api_defaults.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/models/depot_api_mapper.dart';
import 'package:steelforce/features/depots/data/models/depot_model.dart';
import 'package:steelforce/features/depots/data/remote/depot_remote_data_source.dart';
import 'package:steelforce/features/depots/domain/entities/depot_code_lookup.dart';
import 'package:steelforce/features/depots/domain/entities/depot_draft.dart';
import 'package:steelforce/features/depots/data/remote/depot_code_lookup_call.dart';
import 'package:steelforce/features/depots/data/remote/depot_list_envelope.dart';
import 'package:steelforce/features/depots/data/remote/depot_sync_page.dart';

/// `GET /api/v1/mobile/depots` — the real thing.
///
/// Both list calls read the same envelope: the rows live at `data.items`, with
/// `page`/`pageSize`/`totalRecords`/`totalPages` beside them. The older
/// contract (`data.customers` + a `metadata` block) is still read, so a
/// backend on either version keeps syncing.
class ApiDepotRemoteDataSource implements DepotRemoteDataSource {
  ApiDepotRemoteDataSource(this._client, {DepotSupplierNamer? suppliers})
      : _suppliers = suppliers;

  final Dio _client;

  final DepotSupplierNamer? _suppliers; // Detail sends suppliers as codes.

  /// Set once the server has answered in the grouped shape, which has no
  /// delta: every later "changes since" pull asks for the whole book.
  bool _wholeBookOnly = false;

  static const _maxPageSize = 100; // the list's own 1-100 limit

  @override
  Future<DepotInitialPage> fetchInitial({
    required int page,
    required int pageSize,
  }) async {
    final envelope = await _list({
      // The API is one-based. The sync repository counts from 1 to match;
      // sending 0 would silently be treated as 1 and re-fetch the first page.
      'page': page,
      'pageSize': pageSize,
      // A stable order matters across pages: without it the server is free to
      // return rows in a different order per page and a paged run can both
      // miss and duplicate records.
      'sort': 'updatedAt',
    });

    if (envelope.isGroupedDepotList) _wholeBookOnly = true;
    final meta = envelope.metadata;
    final rows = envelope.depotRows, items = identifiableDepots(rows);
    final skipped = rows.length - items.length;
    return DepotInitialPage(
      items: items,
      hasMore: envelope.hasMoreDepots(page, rows),
      syncTimestamp: meta?.syncTimestamp,
      // Read back: `pageSize` is clamped, not rejected.
      pageSize: meta?.pageSize ?? (envelope.data['pageSize'] as num?)?.toInt(),
      // Rows left out: not the whole book, so nothing is dropped as stale.
      completeIds: skipped == 0 ? envelope.completeIds(items) : null,
      skippedWithoutId: skipped,
    );
  }

  @override
  Future<DepotDeltaPage> fetchDelta({
    required DateTime since,
    int page = 1,
    int pageSize = ApiDefaults.maxPageSize,
  }) async {
    if (_wholeBookOnly) return _wholeBookAsDelta(page, pageSize);
    final envelope = await _list({
      // Always the server's own previous `syncTimestamp`, never a device
      // clock. A `modifiedSince` more than five minutes ahead of server time
      // is rejected outright.
      'modifiedSince': since.toUtc().toIso8601String(),
      'page': page,
      'pageSize': pageSize,
      // `includeDeleted` is implied by `modifiedSince`, but stating it keeps
      // the intent obvious: this call *must* return tombstones.
      'includeDeleted': true,
      'sort': 'updatedAt',
    });

    // The grouped answer carries no `syncTimestamp` and no paging, so a
    // filtered one cannot be told from the whole book. Taken as a delta it
    // never re-sends drafts made before the last pull — the Waiting for
    // Approval tab stays empty — and taken as the whole book it would drop
    // every row it left out. Ask for the whole book instead.
    if (envelope.isGroupedDepotList) return _wholeBookAsDelta(page, pageSize);

    final raw = envelope.depotRows, rows = identifiableDepots(raw);
    final skipped = raw.length - rows.length;

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
      hasMore: envelope.hasMoreDepots(page, raw),
      syncTimestamp: meta?.syncTimestamp,
      completeIds: skipped == 0 ? envelope.completeIds(upserted) : null,
      skippedWithoutId: skipped,
    );
  }

  Future<DepotDeltaPage> _wholeBookAsDelta(int page, int pageSize) async {
    final full = await fetchInitial(page: page, pageSize: pageSize);
    return DepotDeltaPage(
      upserted: full.items,
      deletedIds: const [],
      hasMore: full.hasMore,
      syncTimestamp: full.syncTimestamp,
      completeIds: full.completeIds,
      skippedWithoutId: full.skippedWithoutId,
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
      // The outlet shape (`depotId`, `profile`, …) comes as `data` itself.
      final depot = envelope.object('customer') ??
          (envelope.data.containsKey('depotId') ? envelope.data : null);
      if (depot == null) {
        throw const ServerException(
            message: 'The depot response was missing its payload.');
      }
      return DepotApiMapper.fromDetail(await _suppliers?.name(depot) ?? depot);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<DepotCodeLookup> lookupByCode(String code) =>
      lookupDepotByCode(_client, code);

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
        queryParameters: {
          ...query,
          'pageSize': min(query['pageSize'] as int, _maxPageSize),
        },
      );
      return ApiEnvelope.fromBody(res.data);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }
}
