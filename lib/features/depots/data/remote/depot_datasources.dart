// =============================================================================
// depot_datasources.dart
//
// Split these into two files in your tree:
//   lib/features/depot/data/datasources/depot_remote_datasource.dart
//   lib/features/depot/data/datasources/depot_local_datasource.dart
// =============================================================================

import 'package:dio/dio.dart';

import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/core/logging/debug_trace.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/depots/domain/entities/bp_attachment.dart';
import 'package:steelforce/features/depots/domain/entities/sap_option.dart';

// -----------------------------------------------------------------------------
// REMOTE
// -----------------------------------------------------------------------------

/// Middleware rejected the payload. Retrying is pointless — the rep must fix
/// a field. Distinct from a network error, which IS worth retrying.
class ValidationFailure implements Exception {
  final String message;
  final String? field;
  final String? code;
  const ValidationFailure(this.message, {this.field, this.code});
}

/// The server-owned registration form. `fields` is intentionally a map: the
/// API owns the 46-field SAP schema and can add a field without breaking an
/// already released mobile app.
class DepotRegistrationDraft {
  const DepotRegistrationDraft({
    required this.draftId,
    required this.fields,
    this.status = kDraftStatus,
    this.isEditable = true,
    this.submittedDepotId,
  });

  /// The status a draft carries while the rep can still edit it. Other values
  /// (`Submitted`, `Registered`, `Rejected`, …) mean the form has left the
  /// rep's hands.
  static const String kDraftStatus = 'Draft';

  final String draftId;
  final Map<String, dynamic> fields;

  /// Server lifecycle state. Kept as the raw string rather than an enum: the
  /// server may add a status before this app ships again, and an unrecognised
  /// value must degrade to "not resumable", never throw.
  final String status;

  final bool isEditable;

  /// Set once the draft has become a real depot.
  final String? submittedDepotId;

  /// Whether this draft should be reopened rather than replaced by a new one.
  ///
  /// Both conditions are checked on purpose. `status` is the documented
  /// contract, and `isEditable` is the server's own verdict — if they ever
  /// disagree, the safe reading is the restrictive one, because resuming a
  /// draft the server considers closed would send the rep's edits into a
  /// record that can no longer accept them.
  bool get isResumable =>
      isEditable && status.toLowerCase() == kDraftStatus.toLowerCase();

  factory DepotRegistrationDraft.fromJson(Map<String, dynamic> json) {
    final fields = json['fields'];
    return DepotRegistrationDraft(
      draftId: json['draftId'] as String? ?? '',
      fields: fields is Map<String, dynamic>
          ? fields
          : fields is Map
              ? fields.cast<String, dynamic>()
              : const {},
      // Defaults describe a freshly created draft, which is what `POST /draft`
      // returns and what older responses that omit these keys mean.
      status: json['status'] as String? ?? kDraftStatus,
      isEditable: json['isEditable'] as bool? ?? true,
      submittedDepotId: json['submittedDepotId'] as String?,
    );
  }
}

/// Flat reference catalogues returned by `/references`. Sales employees are
/// deliberately absent unless queried with `search`, per MobileDepotApi.
class DepotReferenceCatalogue {
  const DepotReferenceCatalogue(this.values);

  /// The raw `data` object — `{ catalogues: { … }, synchronisedAt: … }`.
  ///
  /// Kept as a map on purpose: the ERP owns these catalogues and the reference
  /// sync can add one without this app being redeployed. A typed field per
  /// catalogue would make a new one invisible until the next release.
  final Map<String, dynamic> values;

  factory DepotReferenceCatalogue.fromJson(Map<String, dynamic> json) =>
      DepotReferenceCatalogue(json);

  /// Catalogue name → options, e.g. `PaymentTerm` → 28 entries.
  ///
  /// Names are the server's (`SalesOrg`, `DistributionChannel`, `Division`,
  /// `DepotGroup`, `PriceGroup`, `PaymentTerm`, `ShippingCondition`,
  /// `SalesOffice`, `SalesGroup`).
  Map<String, List<SapOption>> get catalogues {
    final raw = values['catalogues'];
    if (raw is! Map) return const {};
    final result = <String, List<SapOption>>{};
    for (final entry in raw.entries) {
      final rows = entry.value;
      if (rows is! List) continue;
      final options = <SapOption>[];
      for (final row in rows) {
        if (row is! Map) continue;
        final code = row['code']?.toString();
        if (code == null || code.isEmpty) continue;
        options.add(SapOption(code, row['name']?.toString() ?? code));
      }
      if (options.isNotEmpty) result[entry.key.toString()] = options;
    }
    return result;
  }

  /// When the platform last refreshed these from the ERP. Show it when the copy
  /// is stale rather than implying the codes are current.
  DateTime? get synchronisedAt {
    final raw = values['synchronisedAt'];
    return raw is String ? DateTime.tryParse(raw)?.toUtc() : null;
  }

  /// Options for [catalogue], or an empty list when the server did not send it.
  ///
  /// Empty rather than null so a caller can fall back with `isEmpty ? … : …`
  /// without a null check on every dropdown.
  List<SapOption> optionsFor(String catalogue) =>
      catalogues[catalogue] ?? const [];

  bool get isEmpty => catalogues.isEmpty;
}

class CreateBpResponse {
  /// Null when HQ approval is still pending — SAP has not assigned a number yet.
  final String? depotCode;
  final String status; // PENDING_HQ | CREATED | REJECTED
  final String localId;

  const CreateBpResponse({
    required this.status,
    required this.localId,
    this.depotCode,
  });

  factory CreateBpResponse.fromJson(Map<String, dynamic> j) => CreateBpResponse(
        // Wire keys keep SAP's "customer" (ADR-0007); only the field names
        // moved to "depot".
        depotCode: (j['customerCode'] ?? j['customer_code']) as String?,
        status: (j['sapStatus'] ?? j['status']) as String? ?? 'PENDING_HQ',
        localId: (j['customerId'] ?? j['local_id']) as String? ?? '',
      );
}

abstract class DepotRemoteDataSource {
  /// The SAP reference catalogues.
  ///
  /// [includeInactive] adds retired codes to the response. **Leave it false
  /// for the registration form.** A retired code renders in the dropdown
  /// exactly like a live one, and a rep who picks it gets the registration
  /// rejected on the SAP push with no way to see why. It exists for reading
  /// *existing* records, whose stored codes may since have been retired — the
  /// detail screen needs the name for a code the rep can no longer choose.
  Future<DepotReferenceCatalogue> fetchRegistrationReferences({
    Iterable<String>? kinds,
    String? search,
    bool includeInactive = false,
  });
  Future<DepotRegistrationDraft> createRegistrationDraft();

  /// The rep's current registration form, or null when they have none open.
  ///
  /// Null covers three genuinely different situations that the caller treats
  /// identically — no draft has ever been started, the last one was submitted,
  /// or this server does not expose the endpoint yet (404). In all three the
  /// right next move is to create a fresh draft.
  Future<DepotRegistrationDraft?> fetchActiveRegistrationDraft();

  Future<DepotRegistrationDraft> updateRegistrationDraft({
    required String draftId,
    required Map<String, dynamic> changedFields,
  });
  Future<CreateBpResponse> submitRegistrationDraft(String draftId);
  Future<List<DepotRegistrationDraft>> fetchRegistrationDrafts();
  Future<DepotRegistrationDraft> fetchRegistrationDraft(String draftId);
  Future<void> deleteRegistrationDraft(String draftId);

  /// Compatibility route for older clients. New UI should use the server-draft
  /// lifecycle above so a killed handset can resume a partially completed form.
  Future<CreateBpResponse> createBusinessPartner(Map<String, dynamic> payload);

  Future<String> uploadAttachment({
    required String localId,
    required String kind,
    required String filePath,
  });
}

/// Console tracer for the registration HTTP calls. Debug builds only.
const _trace = DebugTrace('registration');

class DepotRemoteDataSourceImpl implements DepotRemoteDataSource {
  final Dio _dio;
  const DepotRemoteDataSourceImpl(this._dio);

  @override
  Future<DepotReferenceCatalogue> fetchRegistrationReferences({
    Iterable<String>? kinds,
    String? search,
    bool includeInactive = false,
  }) async {
    final query = <String, dynamic>{
      if (kinds != null && kinds.isNotEmpty) 'kinds': kinds.join(','),
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      // Sent only when true. Omitting it leaves the server on its own default
      // rather than this client asserting one, which matters if that default
      // ever changes.
      if (includeInactive) 'includeInactive': 'true',
    };
    _trace.send('http', 'GET references', {
      'kinds': kinds?.join(',') ?? 'all',
      'search': search?.trim().isEmpty ?? true ? null : 'yes',
      'inactive': DebugTrace.yesNo(includeInactive),
    });
    final response = await _get(
      '${ApiEndpoints.depotsEndpoint}/references',
      queryParameters: query,
    );
    return DepotReferenceCatalogue.fromJson(_data(response));
  }

  @override
  Future<DepotRegistrationDraft> createRegistrationDraft() async {
    _trace.send('http', 'POST draft');
    final response = await _post('${ApiEndpoints.depotsEndpoint}/draft');
    final draft = DepotRegistrationDraft.fromJson(_data(response));
    _trace.ok('http', 'POST draft → 200',
        {'id': DebugTrace.id(draft.draftId), 'fields': draft.fields.length});
    return draft;
  }

  @override
  Future<DepotRegistrationDraft?> fetchActiveRegistrationDraft() async {
    _trace.send('http', 'GET draft/active');

    final Response<dynamic> response;
    try {
      response = await _dio.get('${ApiEndpoints.depotsEndpoint}/draft/active');
    } on DioException catch (error) {
      final apiError = ApiError.fromDio(error);
      // 404 is "you have no open form", not a failure. It is also what a
      // server that has not deployed this endpoint yet answers, so treating it
      // as absence keeps the app working against both.
      if (apiError.statusCode == 404) {
        _trace.step('http', 'GET draft/active → 404 none');
        return null;
      }
      throw _translate(error, apiError);
    }

    // Read the envelope defensively rather than through `_data`: a server with
    // no active draft may answer 200 with `"data": null`, and ApiEnvelope
    // treats a missing payload as a malformed response.
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    if (data is! Map) {
      _trace.step('http', 'GET draft/active → 200 empty');
      return null;
    }

    final draft = DepotRegistrationDraft.fromJson(data.cast<String, dynamic>());
    if (draft.draftId.isEmpty) {
      _trace.warn('http', 'GET draft/active → 200 but no draft id');
      return null;
    }

    _trace.ok('http', 'GET draft/active → 200', {
      'id': DebugTrace.id(draft.draftId),
      'status': draft.status,
      'resumable': DebugTrace.yesNo(draft.isResumable),
      'fields': draft.fields.length,
    });
    return draft;
  }

  @override
  Future<DepotRegistrationDraft> updateRegistrationDraft({
    required String draftId,
    required Map<String, dynamic> changedFields,
  }) async {
    _trace.send('http', 'POST update', {
      'id': DebugTrace.id(draftId),
      // Field names only, never their values.
      'patch': DebugTrace.names(changedFields.keys),
    });
    final response = await _post('${ApiEndpoints.depotsEndpoint}/update',
        // `fields` is intentional: update is a patch, and the server must be
        // able to distinguish an omitted field from one explicitly set to ''.
        data: {'draftId': draftId, 'fields': changedFields});
    final draft = DepotRegistrationDraft.fromJson(_data(response));
    _trace.ok('http', 'POST update → 200', {'fields': draft.fields.length});
    return draft;
  }

  @override
  Future<CreateBpResponse> submitRegistrationDraft(String draftId) async {
    _trace.send('http', 'POST submit', {'id': DebugTrace.id(draftId)});
    final response = await _post('${ApiEndpoints.depotsEndpoint}/submit',
        data: {'draftId': draftId});
    final result = CreateBpResponse.fromJson(_data(response));
    _trace.ok('http', 'POST submit → 200', {
      'depot': DebugTrace.id(result.localId),
      'sap': result.status,
    });
    return result;
  }

  @override
  Future<List<DepotRegistrationDraft>> fetchRegistrationDrafts() async {
    _trace.send('http', 'GET drafts');
    final response = await _get('${ApiEndpoints.depotsEndpoint}/drafts');
    final data = _data(response);
    final drafts = data['drafts'] ?? data['items'] ?? data;
    if (drafts is! List) return const [];
    final result = drafts
        .whereType<Map>()
        .map((draft) =>
            DepotRegistrationDraft.fromJson(draft.cast<String, dynamic>()))
        .toList();
    _trace.ok('http', 'GET drafts → 200', {'count': result.length});
    return result;
  }

  @override
  Future<DepotRegistrationDraft> fetchRegistrationDraft(String draftId) async {
    _trace.send('http', 'GET draft', {'id': DebugTrace.id(draftId)});
    final response =
        await _get('${ApiEndpoints.depotsEndpoint}/draft/$draftId');
    return DepotRegistrationDraft.fromJson(_data(response));
  }

  @override
  Future<void> deleteRegistrationDraft(String draftId) =>
      _deleteRegistrationDraft(draftId);

  Future<void> _deleteRegistrationDraft(String draftId) async {
    _trace.send('http', 'DELETE draft', {'id': DebugTrace.id(draftId)});
    await _dio.delete<void>('${ApiEndpoints.depotsEndpoint}/draft/$draftId');
    _trace.ok('http', 'DELETE draft → 204');
  }

  @override
  Future<CreateBpResponse> createBusinessPartner(
      Map<String, dynamic> payload) async {
    _trace.send('http', 'POST business-partner (compatibility)');
    final response = await _post(
      '${ApiEndpoints.depotsEndpoint}/business-partner',
      data: payload,
    );
    final result = CreateBpResponse.fromJson(_data(response));
    _trace.ok('http', 'POST business-partner → 200', {
      'depot': DebugTrace.id(result.localId),
      'sap': result.status,
    });
    return result;
  }

  Future<Response<dynamic>> _get(String path,
          {Map<String, dynamic>? queryParameters}) async =>
      _request(() => _dio.get(path, queryParameters: queryParameters));

  Future<Response<dynamic>> _post(String path, {Object? data}) async =>
      _request(() => _dio.post(path, data: data));

  Future<Response<dynamic>> _request(
      Future<Response<dynamic>> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw _translate(error, ApiError.fromDio(error));
    }
  }

  /// Maps a transport failure onto the exception the callers expect.
  ///
  /// Shared with [fetchActiveRegistrationDraft], which cannot go through
  /// [_request] because it has to inspect the status code before the mapping
  /// happens — a 404 there is an answer, not an error.
  Object _translate(DioException error, ApiError apiError) {
    _trace.fail('http', 'request failed', {
      'status': apiError.statusCode,
      'code': apiError.code,
      'correlation': apiError.correlationId,
    });
    final status = apiError.statusCode ?? 0;
    // A 4xx means the rep must change something; retrying the same payload
    // cannot succeed. 5xx and transport errors stay retryable.
    if (status >= 400 && status < 500) {
      return ValidationFailure(
        apiError.message ?? 'Invalid data',
        field: apiError.fieldErrors.keys.firstOrNull,
        code: apiError.code,
      );
    }
    return error;
  }

  Map<String, dynamic> _data(Response<dynamic> response) =>
      ApiEnvelope.fromBody(response.data).data;

  @override
  Future<String> uploadAttachment({
    required String localId,
    required String kind,
    required String filePath,
  }) async {
    final form = FormData.fromMap({
      'local_id': localId,
      'kind': kind,
      'file': await MultipartFile.fromFile(filePath),
    });

    final res = await _dio.post(
      '/api/v1/depots/bp/$localId/attachments',
      data: form,
    );
    return res.data['url'] as String;
  }
}

// -----------------------------------------------------------------------------
// LOCAL
// -----------------------------------------------------------------------------

class PendingSubmission {
  final String localId;
  final Map<String, dynamic> payload;
  final List<BpAttachment> attachments;
  final DateTime queuedAt;
  final int attemptCount;

  const PendingSubmission({
    required this.localId,
    required this.payload,
    required this.attachments,
    required this.queuedAt,
    this.attemptCount = 0,
  });
}

abstract class DepotLocalDataSource {
  // Queue
  Future<String> enqueueSubmission(Map<String, dynamic> payload);
  Future<void> dequeueSubmission(String localId);
  Future<List<PendingSubmission>> pendingSubmissions();
  Future<int> pendingCount();
  Future<void> markSubmitted(String localId, {String? depotCode});
  Future<void> markRejected(String localId, String reason);
  Future<void> markAttachmentUploaded(String localId, String kind, String url);

  // In-progress form
  Future<void> writeDraft(String json);
  Future<String?> readDraft();
  Future<void> clearDraft();
}
