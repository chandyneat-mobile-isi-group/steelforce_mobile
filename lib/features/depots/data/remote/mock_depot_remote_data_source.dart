// TODO(release-gate): demo-only data source; must never be registered in a release mobile build (USE_MOCK_DATA=false).
import 'package:steelforce/core/network/api/api_defaults.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/mock_latency.dart';
import 'package:steelforce/features/depots/data/models/depot_contact_model.dart';
import 'package:steelforce/features/depots/data/models/depot_model.dart';
import 'package:steelforce/features/depots/data/remote/depot_remote_data_source.dart';
import 'package:steelforce/features/depots/data/remote/depot_sync_page.dart';
import 'package:steelforce/features/depots/data/remote/mock_depot_backend.dart';
import 'package:steelforce/features/depots/data/remote/mock_depot_fixtures.dart';
import 'package:steelforce/features/depots/domain/entities/depot_code_lookup.dart';
import 'package:steelforce/features/depots/domain/entities/depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/depot_list_kind.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';
import 'package:steelforce/features/depots/domain/entities/portal_depot.dart';

/// `GET /api/v1/mobile/depots` and friends, answered from [MockDepotBackend].
///
/// Pages one-based with a server-clock `syncTimestamp`, answers 404 for an
/// unknown id, and returns new registrations in the next delta — what the
/// sync repository would see from the live server.
class MockDepotRemoteDataSource implements DepotRemoteDataSource {
  const MockDepotRemoteDataSource(this._backend);

  final MockDepotBackend _backend;

  @override
  Future<DepotInitialPage> fetchInitial({
    required int page,
    required int pageSize,
  }) async {
    await MockLatency.tick();
    final (rows, hasMore) = _page(_backend.sorted, page, pageSize);
    return DepotInitialPage(
      items: rows,
      hasMore: hasMore,
      syncTimestamp: _backend.now(),
      pageSize: pageSize,
    );
  }

  @override
  Future<DepotDeltaPage> fetchDelta({
    required DateTime since,
    int page = 1,
    int pageSize = ApiDefaults.maxPageSize,
  }) async {
    await MockLatency.tick();
    final (rows, hasMore) = _page(_backend.changedSince(since), page, pageSize);
    return DepotDeltaPage(
      upserted: rows,
      deletedIds: const [],
      hasMore: hasMore,
      syncTimestamp: _backend.now(),
    );
  }

  @override
  Future<DepotModel> fetchById(String id) async {
    await MockLatency.tick();
    return _backend.find(id) ?? (throw _notFound());
  }

  @override
  Future<DepotModel> create(DepotDraft draft) async {
    if (_backend.hasCode(draft.depotCode)) {
      throw const ApiException(ApiError(
        code: ApiErrorCodes.depotDuplicateCode,
        statusCode: 409,
      ));
    }
    final id = _backend.nextId('demo-depot');
    final stamp = _backend.now();
    return _backend.insert(DepotModel(
      id: id,
      depotCode: draft.depotCode.isEmpty ? id : draft.depotCode,
      shopName: draft.shopName,
      enName: draft.enName ?? draft.shopName,
      khName: draft.khName,
      ownerName: draft.ownerName ?? '',
      phone: draft.phone,
      whatsapp: draft.whatsapp,
      address: draft.addressLine1,
      province: draft.province ?? draft.city,
      district: draft.district ?? '',
      territory: draft.territory ?? MockDepotFixtures.territory,
      latitude: draft.latitude ?? 0,
      longitude: draft.longitude ?? 0,
      creditLimit: draft.creditLimit ?? 0,
      currency: MockDepotFixtures.currency,
      // Field registrations land in Draft until someone activates them.
      status: DepotStatus.draft,
      assignedRepId: MockDepotFixtures.repId,
      assignedRepName: MockDepotFixtures.repName,
      updatedAt: stamp,
      createdAt: stamp,
      depotType: DepotTypes.draft,
      createdBy: MockDepotFixtures.repCode,
      contacts: [
        for (final (i, c) in draft.contacts.indexed)
          DepotContactModel(
            id: '$id-contact-${i + 1}',
            name: c.name,
            role: c.position ?? '',
            phone: c.phone,
          ),
      ],
    ));
  }

  @override
  Future<DepotCodeLookup> lookupByCode(String code) async {
    await MockLatency.tick();
    final depot = _backend.find(code.trim());
    if (depot == null || depot.depotCode != code.trim()) {
      return const DepotCodeAbsent();
    }
    final term = depot.salesAreas?.firstOrNull?.creditTermDays;
    return DepotCodeFound(PortalDepot(
      id: depot.id,
      code: depot.depotCode,
      name: depot.shopName,
      status: depot.status.apiValue,
      canTrade: depot.status.canTrade,
      type: depot.depotType,
      phone: depot.phone,
      city: depot.province,
      latitude: depot.latitude,
      longitude: depot.longitude,
      creditLimit: depot.creditLimit,
      creditTermDays: term,
      assignedSalesRepId: depot.assignedRepId,
      createdAt: depot.createdAt,
    ));
  }

  /// One page of [rows]; the size is clamped, not rejected, like the server.
  static (List<DepotModel>, bool) _page(
    List<DepotModel> rows,
    int page,
    int pageSize,
  ) {
    final size = pageSize.clamp(1, ApiDefaults.maxPageSize);
    final start = ((page < 1 ? 1 : page) - 1) * size;
    if (start >= rows.length) return (const [], false);
    final end = (start + size).clamp(0, rows.length);
    return (rows.sublist(start, end), end < rows.length);
  }

  static ApiException _notFound() => const ApiException(
        ApiError(code: ApiErrorCodes.depotNotFound, statusCode: 404),
      );
}
