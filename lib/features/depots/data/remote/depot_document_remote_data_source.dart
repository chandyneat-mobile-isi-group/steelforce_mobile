import 'dart:io';

import 'package:dio/dio.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/depots/data/models/depot_document_mapper.dart';
import 'package:steelforce/features/depots/domain/entities/depot_document.dart';

/// `/api/v1/mobile/depots/{depotId}/documents`.
///
/// `{depotId}` accepts **either** the platform id **or** the depot code
/// (which for a SAP-originated depot is its SAP number). The platform id is
/// what the field flow uses: a shop registered on a market stall has no SAP
/// number yet — an operator pushes it to the ERP hours or days later — and the
/// representative has taken the photographs *now*.
abstract interface class DepotDocumentRemoteDataSource {
  /// Uploads one file into one slot. There is no batch endpoint: a failed
  /// batch tells you nothing about which photograph to retake.
  Future<DepotDocument> upload({
    required String depotId,
    required DepotDocumentType type,
    required File file,
    DateTime? capturedAt,
  });

  Future<DepotDocumentsState> fetch(String depotId);

  Future<void> delete({required String depotId, required String documentId});
}

class ApiDepotDocumentRemoteDataSource
    implements DepotDocumentRemoteDataSource {
  const ApiDepotDocumentRemoteDataSource(this._client);

  final Dio _client;

  /// The server enforces this too; checking first turns a wasted upload on a
  /// 3G link into an immediate, specific message.
  static const int maxBytes = 10 * 1024 * 1024;

  String _path(String depotId) =>
      '${ApiEndpoints.depotsEndpoint}/$depotId/documents';

  @override
  Future<DepotDocument> upload({
    required String depotId,
    required DepotDocumentType type,
    required File file,
    DateTime? capturedAt,
  }) async {
    try {
      final media = _mediaTypeFor(file.path, type);

      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          // Stated, never inferred. The server rejects a Content-Type that
          // disagrees with the extension, which is what catches a PDF renamed
          // to `.jpg` to reach a photo slot.
          contentType: media,
        ),
        'Type': type.code,
        // Photo time, not upload time. A queued upload can reach the server
        // hours after the visit; without this the record is dated to whenever
        // the connection came back.
        if (capturedAt != null)
          'CapturedAt': capturedAt.toUtc().toIso8601String(),
      });

      final res = await _client.post<dynamic>(_path(depotId), data: form);
      final document = DepotDocumentMapper.fromJson(
        ApiEnvelope.fromBody(res.data).data,
      );
      if (document == null) {
        throw const ServerException(
          message: 'The upload response was missing its payload.',
        );
      }
      return document;
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<DepotDocumentsState> fetch(String depotId) async {
    try {
      final res = await _client.get<dynamic>(_path(depotId));
      return DepotDocumentMapper.stateFromJson(
        ApiEnvelope.fromBody(res.data).data,
      );
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<void> delete({
    required String depotId,
    required String documentId,
  }) async {
    try {
      await _client.delete<void>('${_path(depotId)}/$documentId');
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  /// The media type for [path], constrained by what [type] accepts.
  ///
  /// A PDF reaching a photo slot is rejected here rather than on the wire — the
  /// server answers `Depot.DocumentExtensionNotAllowed`, and a rep on a
  /// market connection should not spend the upload to learn that.
  static DioMediaType _mediaTypeFor(String path, DepotDocumentType type) {
    final extension = path.toLowerCase().split('.').last;

    if (extension == 'pdf') {
      if (!type.acceptsPdf) {
        throw const ServerException(
          message: 'A PDF can only be attached to the patent/tax or VAT slot.',
        );
      }
      return DioMediaType('application', 'pdf');
    }

    return switch (extension) {
      'png' => DioMediaType('image', 'png'),
      // The camera writes .jpg; anything else has already been rejected above
      // or is a JPEG under another spelling.
      _ => DioMediaType('image', 'jpeg'),
    };
  }
}
