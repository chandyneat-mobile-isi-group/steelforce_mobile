/// `GET /api/v1/mobile/depots` and friends, answered from [DemoDepotDirectory].
///
/// Each response is built as the real envelope and parsed by the same code
/// path [ApiDepotRemoteDataSource] uses, so the sync repository sees exactly
/// what it would see live — including one-based paging, `hasNextPage`, the
/// server-clock `syncTimestamp`, and 404 for an unknown depot.
///
/// TODO(release-gate): demo-only, selected only when DataSourceMode.useMocks.
library;

import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/core/network/api/api_defaults.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_directory.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_fixtures.dart';
import 'package:steelforce/features/depots/data/models/depot_api_mapper.dart';
import 'package:steelforce/features/depots/data/models/depot_model.dart';
import 'package:steelforce/features/depots/data/models/portal_depot_mapper.dart';
import 'package:steelforce/features/depots/data/remote/depot_remote_data_source.dart';
import 'package:steelforce/features/depots/data/remote/depot_sync_page.dart';
import 'package:steelforce/features/depots/domain/entities/depot_code_lookup.dart';
import 'package:steelforce/features/depots/domain/entities/depot_draft.dart';

class DemoDepotRemoteDataSource implements DepotRemoteDataSource {
  const DemoDepotRemoteDataSource(this._network, this._directory);

  final DemoNetwork _network;
  final DemoDepotDirectory _directory;

  /// A code that answers as "the ERP could not be reached" (502), so a
  /// presenter can show why registration is withheld in that case.
  static const String erpUnavailableCode = '9999999999';

  @override
  Future<DepotInitialPage> fetchInitial({
    required int page,
    required int pageSize,
  }) async {
    await _network.roundTrip();
    final envelope = ApiEnvelope.fromBody(
      _listBody(_directory.sorted, page: page, pageSize: pageSize),
    );
    final meta = envelope.metadata;
    return DepotInitialPage(
      items:
          envelope.list('customers').map(DepotApiMapper.fromSummary).toList(),
      hasMore: meta?.hasNextPage ?? false,
      syncTimestamp: meta?.syncTimestamp,
      pageSize: meta?.pageSize,
    );
  }

  @override
  Future<DepotDeltaPage> fetchDelta({
    required DateTime since,
    int page = 1,
    int pageSize = ApiDefaults.maxPageSize,
  }) async {
    await _network.roundTrip();
    // The live server rejects a watermark more than five minutes ahead of its
    // clock; mirrored so the repository's recovery path is reachable.
    if (since.isAfter(_directory.now().add(const Duration(minutes: 5)))) {
      throw const ApiException(ApiError(
        code: ApiErrorCodes.validation,
        statusCode: 400,
        fieldErrors: {
          'parameters.modifiedSince': [
            'modifiedSince is ahead of the server clock.'
          ],
        },
      ));
    }
    final envelope = ApiEnvelope.fromBody(_listBody(
      _directory.changedSince(since),
      page: page,
      pageSize: pageSize,
      isDelta: true,
    ));

    final upserted = <DepotModel>[];
    final deletedIds = <String>[];
    for (final row
        in envelope.list('customers').map(DepotApiMapper.fromSummary)) {
      row.deleted ? deletedIds.add(row.id) : upserted.add(row);
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
    await _network.roundTrip();
    final row = _directory.find(id);
    if (row == null) throw _notFound();
    final envelope = ApiEnvelope.fromBody(_wrap({'customer': row}));
    return DepotApiMapper.fromDetail(envelope.object('customer')!);
  }

  @override
  Future<DepotModel> create(DepotDraft draft) async {
    await _network.roundTrip();
    if (_directory.hasCode(draft.depotCode)) {
      throw const ApiException(ApiError(
        code: ApiErrorCodes.depotDuplicateCode,
        statusCode: 409,
      ));
    }
    final json = draft.toJson();
    final id = _directory.nextId();
    final stored = _directory.insert({
      ...json,
      'id': id,
      'customerCode': draft.depotCode.isEmpty ? id : draft.depotCode,
      'sapCustomerId': null,
      'enName': draft.enName ?? draft.shopName,
      'province': draft.province ?? draft.city,
      'territory': draft.territory ?? '',
      'currency': DemoDepotFixtures.currency,
      'creditLimit': DemoDepotFixtures.money(draft.creditLimit ?? 0),
      'creditBalance': DemoDepotFixtures.money(0),
      // Field registrations land in Draft until someone activates them.
      'status': 'Draft',
      'assignedRepId': DemoSeed.repId,
      'assignedRepName': DemoSeed.repName,
      'contacts': [
        for (final (i, c) in draft.contacts.indexed)
          {...c.toJson(), 'id': '$id-contact-${i + 1}'},
      ],
      'deleted': false,
    });
    final envelope = ApiEnvelope.fromBody(_wrap({'customer': stored}));
    return DepotApiMapper.fromDetail(envelope.object('customer')!);
  }

  @override
  Future<DepotCodeLookup> lookupByCode(String code) async {
    await _network.roundTrip();
    if (code == erpUnavailableCode) return const DepotCodeUnavailable();
    final row = _directory.find(code);
    if (row == null || row['customerCode'] != code) {
      return const DepotCodeAbsent();
    }
    final depot = PortalDepotMapper.fromEnvelope({
      'data': DemoDepotFixtures.portalOf(row),
      'meta': const <String, dynamic>{},
    });
    return depot == null ? const DepotCodeAbsent() : DepotCodeFound(depot);
  }

  /// One page of [rows], in the list envelope the live endpoint returns.
  DataMap _listBody(
    List<DataMap> rows, {
    required int page,
    required int pageSize,
    bool isDelta = false,
  }) {
    // Clamped, not rejected, like the server.
    final size = pageSize.clamp(1, ApiDefaults.maxPageSize);
    final current = page < 1 ? 1 : page;
    final start = (current - 1) * size;
    final slice = start >= rows.length
        ? const <DataMap>[]
        : rows.sublist(start, (start + size).clamp(0, rows.length));
    final totalPages = (rows.length / size).ceil();

    return _wrap(
      {'customers': slice.map(DemoDepotFixtures.summaryOf).toList()},
      metadata: {
        'page': current,
        'pageSize': size,
        'totalRecords': rows.length,
        'totalPages': totalPages,
        'hasNextPage': current < totalPages,
        'hasPreviousPage': current > 1,
        'syncTimestamp': DemoDepotFixtures.iso(_directory.now()),
        'isDeltaSync': isDelta,
      },
    );
  }

  static DataMap _wrap(DataMap data, {DataMap? metadata}) => {
        'success': true,
        'message': 'OK',
        'data': data,
        'metadata': metadata,
        'traceId': 'demo',
      };

  static ApiException _notFound() => const ApiException(
        ApiError(code: ApiErrorCodes.depotNotFound, statusCode: 404),
      );
}
