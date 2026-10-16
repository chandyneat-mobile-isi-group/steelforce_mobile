import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/features/depots/data/remote/depot_datasources.dart';
import 'package:steelforce/features/depots/data/datasources/business_partner_remote_data_source.dart';
import 'package:steelforce/features/depots/data/local/bp_draft_cache.dart';
import 'package:steelforce/features/depots/data/local/depot_reference_cache.dart';
import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';
import 'package:steelforce/features/depots/data/repositories/business_partner_repository_impl.dart';

/// End-to-end proof that the **live** `GET /mobile/depots/references`
/// response reaches the registration dropdowns.
///
/// The payload below is the one captured from the running API, unedited. The
/// question this answers is not "does the parser work" but "does the depot
/// group the server actually sends end up as the options the rep picks from" —
/// which spans the endpoint path, the envelope, the catalogue map and the
/// resolver.
/// Caches that hold nothing, so every call takes the network path this file is
/// about. Hand-written rather than mocked: `readFresh` returning null is the
/// whole behaviour, and a stubbed mock would say it less clearly.
class _EmptyReferenceCache extends Fake implements DepotReferenceCache {
  @override
  DepotReferenceCatalogue? readFresh({bool includeInactive = false}) => null;

  @override
  DepotReferenceCatalogue? readStale({bool includeInactive = false}) => null;

  @override
  DateTime? cachedAt({bool includeInactive = false}) => null;

  @override
  Future<void> write(DepotReferenceCatalogue catalogue,
      {bool includeInactive = false}) async {}

  @override
  Future<void> clear() async {}
}

/// The draft store is untouched by a reference load.
class _UnusedDraftCache extends Fake implements BpDraftCache {
  @override
  Future<BpDepotDraft?> read() async => null;

  @override
  Future<void> write(BpDepotDraft draft) async {}

  @override
  Future<void> clear() async {}
}

/// Never called on this path; the repository requires one to construct.
/// Never called on this path; `Fake` throws loudly if that ever changes.
class _UnusedBpRemote extends Fake implements BusinessPartnerRemoteDataSource {}

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? stream,
      Future<void>? cancelFuture) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Verbatim from the running API.
const String _liveResponse = '''
{
  "success": true,
  "message": "ទាញយកទិន្នន័យយោងអតិថិជនបានជោគជ័យ។",
  "data": {
    "catalogues": {
      "DepotGroup": [
        {"code":"01","name":"End-User"},{"code":"02","name":"Local Builder"},
        {"code":"03","name":"Craftsman"},{"code":"04","name":"PIPE Maker"},
        {"code":"05","name":"Contractor"},{"code":"06","name":"Developer"},
        {"code":"07","name":"Distributor"},{"code":"08","name":"Exporter"}
      ],
      "DistributionChannel": [
        {"code":"10","name":"End-User"},{"code":"20","name":"Local Builder"},
        {"code":"99","name":"Internal"}
      ],
      "Division": [{"code":"10","name":"ISI Steel"},{"code":"99","name":"Internal"}],
      "PaymentTerm": [
        {"code":"BL30","name":"LC after BL date 30days"},
        {"code":"T030","name":"30 days due net"}
      ],
      "PriceGroup": [{"code":"11","name":"End-User"},{"code":"51","name":"Contractor"}],
      "SalesGroup": [{"code":"010","name":"Channel Sales"}],
      "SalesOffice": [{"code":"0009","name":"Siem Riep"}],
      "SalesOrg": [{"code":"0001","name":"Phnom Penh (ISI)"}],
      "ShippingCondition": [{"code":"01","name":"ISI Services"}]
    },
    "synchronisedAt": "2026-08-31T02:02:29.719615+00:00"
  },
  "metadata": null,
  "traceId": "0HNO6VOPB3OJP:00000004"
}
''';

void main() {
  late _ScriptedAdapter adapter;
  late BusinessPartnerRepositoryImpl repository;

  setUp(() {
    adapter = _ScriptedAdapter((o) async => ResponseBody.fromString(
          _liveResponse,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ));
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    // No cache: this exercises the network path, which is what a first form
    // open on a fresh install does.
    repository = BusinessPartnerRepositoryImpl(
      remote: _UnusedBpRemote(),
      references: DepotRemoteDataSourceImpl(dio),
      referenceCache: _EmptyReferenceCache(),
      draftCache: _UnusedDraftCache(),
    );
  });

  test('it calls the documented references endpoint', () async {
    await repository.loadReferenceOptions();

    expect(adapter.requests.single.path,
        '${ApiEndpoints.depotsEndpoint}/references');
  });

  test('DepotGroup reaches the dropdown, all eight, in order', () async {
    final options = await repository.loadReferenceOptions();

    expect(options.isFromErp, isTrue,
        reason: 'a live response must not silently fall back to the '
            'built-in list');
    expect(options.depotGroup.map((o) => o.code).toList(), [
      '01',
      '02',
      '03',
      '04',
      '05',
      '06',
      '07',
      '08',
    ]);
    expect(options.depotGroup.map((o) => o.labelEn).toList(), [
      'End-User',
      'Local Builder',
      'Craftsman',
      'PIPE Maker',
      'Contractor',
      'Developer',
      'Distributor',
      'Exporter',
    ]);
  });

  test('the rep sees names, and the code still goes on the wire', () async {
    final options = await repository.loadReferenceOptions();
    final contractor = options.depotGroup.firstWhere((o) => o.code == '05');

    // The dropdown renders labelEn (showCode defaults to false); the value
    // bound to the item — and submitted — is the code.
    expect(contractor.labelEn, 'Contractor');
    expect(contractor.code, '05');
  });

  test('every catalogue the server sent is bound to its dropdown', () async {
    final options = await repository.loadReferenceOptions();

    expect(options.depotGroup, hasLength(8));
    expect(options.distributionChannel, hasLength(3));
    expect(options.division, hasLength(2));
    expect(options.paymentTerm, hasLength(2));
    expect(options.priceGroup, hasLength(2));
    expect(options.salesGroup, hasLength(1));
    expect(options.salesOffice, hasLength(1));
    expect(options.salesOrg, hasLength(1));
    expect(options.shippingCondition, hasLength(1));
  });

  test('price group is derived from the served pairing, by name', () async {
    final options = await repository.loadReferenceOptions();

    // 05 Contractor → 51 Contractor, matched across the two served catalogues.
    expect(options.priceGroupFor('05'), '51');
    expect(options.priceGroupFor('01'), '11');
  });

  test('synchronisedAt is read, so staleness can be shown', () async {
    final options = await repository.loadReferenceOptions();

    // The server sends microsecond precision (…719615); parsed as UTC and
    // kept verbatim rather than rounded.
    expect(
        options.synchronisedAt, DateTime.parse('2026-08-31T02:02:29.719615Z'));
    expect(options.synchronisedAt!.isUtc, isTrue);
  });
}
