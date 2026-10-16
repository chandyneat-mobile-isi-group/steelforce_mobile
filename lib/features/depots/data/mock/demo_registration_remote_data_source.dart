/// The registration routes of `bp.DepotRemoteDataSource`, answered in memory.
///
/// Only `GET /references` is on the live path today — the server-draft routes
/// were retired in favour of the single business-partner write — but the
/// interface still carries them, so they are implemented statefully rather
/// than left to throw: a draft created here can be updated, listed, submitted
/// and deleted for the rest of the session.
///
/// TODO(release-gate): demo-only, selected only when DataSourceMode.useMocks.
library;

import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_directory.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_fixtures.dart';
import 'package:steelforce/features/depots/data/mock/demo_registration_references.dart';
import 'package:steelforce/features/depots/data/remote/depot_datasources.dart';

class DemoRegistrationRemoteDataSource implements DepotRemoteDataSource {
  DemoRegistrationRemoteDataSource(this._network, this._directory);

  final DemoNetwork _network;
  final DemoDepotDirectory _directory;
  final Map<String, DataMap> _drafts = {};
  int _draftSequence = 0;

  @override
  Future<DepotReferenceCatalogue> fetchRegistrationReferences({
    Iterable<String>? kinds,
    String? search,
    bool includeInactive = false,
  }) async {
    await _network.roundTrip();
    final data = DemoRegistrationReferences.data(_directory.now());
    final wanted = kinds?.toSet();
    if (wanted != null && wanted.isNotEmpty) {
      final all = data['catalogues'] as DataMap;
      data['catalogues'] = {
        for (final entry in all.entries)
          if (wanted.contains(entry.key)) entry.key: entry.value,
      };
    }
    return DepotReferenceCatalogue.fromJson(_unwrap(data));
  }

  @override
  Future<DepotRegistrationDraft> createRegistrationDraft() async {
    await _network.roundTrip();
    final id = 'demo-draft-${(++_draftSequence).toString().padLeft(3, '0')}';
    _drafts[id] = {
      'draftId': id,
      'fields': <String, dynamic>{},
      'status': DepotRegistrationDraft.kDraftStatus,
      'isEditable': true,
    };
    return _parse(_drafts[id]!);
  }

  @override
  Future<DepotRegistrationDraft?> fetchActiveRegistrationDraft() async {
    await _network.roundTrip();
    for (final draft in _drafts.values.toList().reversed) {
      final parsed = _parse(draft);
      if (parsed.isResumable) return parsed;
    }
    // The live route answers 404 here, which the real source maps to null.
    return null;
  }

  @override
  Future<DepotRegistrationDraft> updateRegistrationDraft({
    required String draftId,
    required Map<String, dynamic> changedFields,
  }) async {
    await _network.roundTrip();
    final draft = _editable(draftId);
    draft['fields'] = {...draft['fields'] as DataMap, ...changedFields};
    return _parse(draft);
  }

  @override
  Future<CreateBpResponse> submitRegistrationDraft(String draftId) async {
    await _network.roundTrip();
    final draft = _editable(draftId);
    final fields = draft['fields'] as DataMap;
    final code = _directory.nextPartnerNumber();
    final id = _directory.nextId();
    _directory.insert(_depotRow(id: id, code: code, fields: fields));
    draft
      ..['status'] = 'Submitted'
      ..['isEditable'] = false
      ..['submittedDepotId'] = id;
    return CreateBpResponse.fromJson(_unwrap({
      'customerCode': code,
      'sapStatus': 'CREATED',
      'customerId': id,
    }));
  }

  @override
  Future<List<DepotRegistrationDraft>> fetchRegistrationDrafts() async {
    await _network.roundTrip();
    return _drafts.values.map(_parse).toList();
  }

  @override
  Future<DepotRegistrationDraft> fetchRegistrationDraft(String draftId) async {
    await _network.roundTrip();
    return _parse(_existing(draftId));
  }

  @override
  Future<void> deleteRegistrationDraft(String draftId) async {
    await _network.roundTrip();
    _existing(draftId);
    _drafts.remove(draftId);
  }

  @override
  Future<CreateBpResponse> createBusinessPartner(
    Map<String, dynamic> payload,
  ) async {
    await _network.roundTrip();
    final code = _directory.nextPartnerNumber();
    final id = _directory.nextId();
    _directory.insert(_depotRow(id: id, code: code, fields: payload));
    return CreateBpResponse.fromJson(_unwrap({
      'customerCode': code,
      'sapStatus': 'CREATED',
      'customerId': id,
    }));
  }

  @override
  Future<String> uploadAttachment({
    required String localId,
    required String kind,
    required String filePath,
  }) async {
    await _network.roundTrip();
    // A non-network scheme: nothing in a demo build may try to fetch it.
    return 'demo://depots/$localId/attachments/$kind';
  }

  DataMap _existing(String draftId) {
    final draft = _drafts[draftId];
    // The live source turns a 4xx into a ValidationFailure; 404 is one.
    if (draft == null) {
      throw const ValidationFailure('Draft not found.', code: 'Draft.NotFound');
    }
    return draft;
  }

  DataMap _editable(String draftId) {
    final draft = _existing(draftId);
    if (draft['isEditable'] != true) {
      throw const ValidationFailure(
        'This registration has already been submitted.',
        code: 'Draft.NotEditable',
      );
    }
    return draft;
  }

  /// The SAP field names the draft form uses, onto a registered depot row.
  static DataMap _depotRow({
    required String id,
    required String code,
    required DataMap fields,
  }) {
    String read(List<String> keys) {
      for (final key in keys) {
        final value = fields[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    return DemoDepotFixtures.registered(
      id: id,
      code: code,
      name: read(['Name1', 'name1', 'shopName']),
      nameKm: read(['Name3', 'name3']),
      ownerName: read(['CoName', 'coName', 'Name2', 'name2']),
      phone: read(['MobilePhone', 'Telephone', 'phone']),
      street: read(['Street', 'street']),
      district: read(['District', 'district']),
      city: read(['City', 'city']),
      latitude: double.tryParse(read(['Latitude', 'latitude'])),
      longitude: double.tryParse(read(['Longitude', 'longitude'])),
      depotGroup: read(['DepotGroup', 'CustomerGroup']),
      paymentTerm: read(['PaymentTerms', 'paymentTerms']),
    );
  }

  static DepotRegistrationDraft _parse(DataMap draft) =>
      DepotRegistrationDraft.fromJson(_unwrap(draft));

  /// Through the real envelope parser, as `_data(response)` does live.
  static DataMap _unwrap(DataMap data) =>
      ApiEnvelope.fromBody({'success': true, 'data': data}).data;
}
