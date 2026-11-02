import 'package:dio/dio.dart';
import 'package:steelforce/features/depots/data/remote/depot_create_debug_log.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/models/registration/depot_draft_attachment_model.dart';
import 'package:steelforce/features/depots/data/models/registration/depot_reference_lists_model.dart';
import 'package:steelforce/features/depots/data/models/registration/new_depot_draft_request.dart';
import 'package:steelforce/features/depots/data/models/registration/saved_depot_draft_model.dart';
import 'package:steelforce/features/depots/data/remote/depot_draft_debug_log.dart';
import 'package:steelforce/features/depots/data/remote/depot_draft_remote_data_source.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_attachment.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_suppliers.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_reference_lists.dart';
import 'package:steelforce/features/depots/domain/entities/registration/evidence_file_rules.dart';
import 'package:steelforce/features/depots/domain/entities/registration/mobile_depot_kind.dart';
import 'package:steelforce/features/depots/domain/entities/registration/new_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/registration/saved_depot_draft.dart';

/// [DepotDraftRemoteDataSource] over the app's authenticated [Dio].
///
/// The bearer token and the one 401 refresh are the auth interceptor's job.
/// Each call prints to the debug console through [DepotDraftDebugLog], with
/// personal fields masked; release builds print nothing.
class ApiDepotDraftRemoteDataSource implements DepotDraftRemoteDataSource {
  const ApiDepotDraftRemoteDataSource(this._client);

  final Dio _client;

  @override
  Future<SavedDepotDraft> createDraft(NewDepotDraft draft) => _guard(() async {
        final body = NewDepotDraftRequest.toJson(draft);
        // One create for both kinds; `depotType` in the body picks.
        final res = await DepotCreateDebugLog.trace(
          path: ApiEndpoints.depotsEndpoint,
          body: body,
          send: () =>
              _client.post<DataMap>(ApiEndpoints.depotsEndpoint, data: body),
        );
        return SavedDepotDraftModel.fromJson(
          ApiEnvelope.fromBody(res.data).data,
          isNew: res.statusCode != 200,
          kind: draft.kind,
        );
      });

  @override
  Future<DepotReferenceLists> fetchReferences() => _guard(() async {
        final res = await _send(
          'GET',
          ApiEndpoints.depotReferencesEndpoint,
          () => _client.get<DataMap>(ApiEndpoints.depotReferencesEndpoint),
        );
        return DepotReferenceListsModel.fromJson(
            ApiEnvelope.fromBody(res.data).data);
      });

  /// `data` here is a bare array, which [ApiEnvelope] (object `data` only)
  /// does not read — so the envelope is unwrapped by hand.
  @override
  Future<List<SupplierOption>> fetchSupplierOptions(DepotSupplierType type) =>
      _guard(() async {
        final path = ApiEndpoints.profileListEndpoint(type.listName);
        final res = await _send('GET', path, () => _client.get<DataMap>(path));
        final body = res.data;
        if (body == null || body['success'] == false) {
          throw const ServerException(message: 'Unreadable profile list.');
        }
        return DepotReferenceListsModel.suppliersFromJson(body['data']);
      });

  @override
  Future<DepotDraftAttachment> uploadEvidence(
    String draftId,
    EvidenceUpload upload, {
    MobileDepotKind kind = MobileDepotKind.depot,
    void Function(int sent, int total)? onProgress,
  }) =>
      _guard(() async {
        final media = EvidenceFileRules.mediaTypeFor(upload.fileName);
        if (media == null) {
          throw const ServerException(message: 'Unsupported evidence type.');
        }
        final form = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            upload.filePath,
            filename: upload.fileName,
            // Stated, never inferred: the server refuses a file whose name,
            // declared type and first bytes disagree.
            contentType: DioMediaType.parse(media),
          ),
          'id': upload.id,
          if (upload.category case final category?)
            'category': category.apiValue,
          if (upload.note?.trim() case final note? when note.isNotEmpty)
            'note': note,
          if (upload.takenAt case final at?)
            'takenAt': at.toUtc().toIso8601String(),
          // Both or neither, as the server requires.
          if (upload.latitude != null && upload.longitude != null) ...{
            'latitude': '${upload.latitude}',
            'longitude': '${upload.longitude}',
          },
        });
        // No Content-Type set by hand: dio writes the multipart boundary.
        final path = _attachmentsPath(draftId, kind);
        final res = await _send(
          'POST',
          path,
          () => _client.post<DataMap>(path,
              data: form, onSendProgress: onProgress),
          // The fields as sent; the file itself only as its type and size.
          body: {
            ...Map.fromEntries(form.fields),
            'file': '<$media, ${form.files.single.value.length} bytes>',
          },
        );
        final attachment = DepotDraftAttachmentModel.fromJson(
            ApiEnvelope.fromBody(res.data).data);
        if (attachment == null) {
          throw const ServerException(message: 'Unreadable upload answer.');
        }
        return attachment;
      });

  @override
  Future<DepotDraftAttachments> fetchAttachments(
    String draftId, {
    MobileDepotKind kind = MobileDepotKind.depot,
  }) =>
      _guard(() async {
        final path = _attachmentsPath(draftId, kind);
        final res = await _send('GET', path, () => _client.get<DataMap>(path));
        return DepotDraftAttachmentModel.listFromJson(
            ApiEnvelope.fromBody(res.data).data);
      });

  /// A depot is created as a depot draft and a non-depot as a non-depot;
  /// each record's files live on its own route.
  static String _attachmentsPath(String id, MobileDepotKind kind) =>
      switch (kind) {
        MobileDepotKind.depot => ApiEndpoints.depotDraftAttachmentsEndpoint(id),
        MobileDepotKind.nonDepot =>
          ApiEndpoints.nonDepotAttachmentsEndpoint(id),
      };

  /// One HTTP call, printed as request, then response or error.
  Future<Response<DataMap>> _send(
    String method,
    String path,
    Future<Response<DataMap>> Function() call, {
    Map<String, dynamic>? params,
    Object? body,
  }) async {
    final url = '${_client.options.baseUrl}$path';
    DepotDraftDebugLog.request(method, url, params: params, body: body);
    try {
      final res = await call();
      DepotDraftDebugLog.response(method, url, res.statusCode, res.data);
      return res;
    } on DioException catch (e, stack) {
      DepotDraftDebugLog.error(
        method,
        url,
        '${e.type.name}: ${e.message ?? '-'}',
        stack,
        status: e.response?.statusCode,
        data: e.response?.data,
      );
      rethrow;
    }
  }

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    } on TypeError catch (e, stack) {
      // A 2xx whose body did not match the contract.
      DepotDraftDebugLog.error('PARSE', '-', e, stack);
      throw ServerException(message: '$e');
    } on FormatException catch (e, stack) {
      DepotDraftDebugLog.error('PARSE', '-', e, stack);
      throw ServerException(message: e.message);
    } on ServerException catch (e, stack) {
      DepotDraftDebugLog.error('PARSE', '-', e.message, stack);
      rethrow;
    }
  }
}
