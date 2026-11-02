// TODO(release-gate): demo-only data source; must never be registered in a release mobile build (USE_MOCK_DATA=false).
import 'dart:io' show File;

import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/mock_latency.dart';
import 'package:steelforce/features/depots/data/remote/depot_document_remote_data_source.dart';
import 'package:steelforce/features/depots/data/remote/mock_depot_backend.dart';
import 'package:steelforce/features/depots/domain/entities/depot_document.dart';

/// `/api/v1/mobile/depots/{depotId}/documents`, answered from
/// [MockDepotBackend].
///
/// One live document per slot, replaced on re-upload; the checklist
/// (`missingRequired`, `isComplete`) is worked out the way the server does,
/// treating VAT as not required. Only [File.path] is read — never the file
/// itself — so nothing here touches the filesystem.
class MockDepotDocumentRemoteDataSource
    implements DepotDocumentRemoteDataSource {
  const MockDepotDocumentRemoteDataSource(this._backend);

  final MockDepotBackend _backend;

  static const Duration _writeLatency = Duration(milliseconds: 400);

  @override
  Future<DepotDocument> upload({
    required String depotId,
    required DepotDocumentType type,
    required File file,
    DateTime? capturedAt,
  }) async {
    await Future<void>.delayed(_writeLatency);
    if (_backend.find(depotId) == null && _backend.draft(depotId) == null) {
      throw const ApiException(
          ApiError(code: ApiErrorCodes.depotNotFound, statusCode: 404));
    }
    final path = file.path;
    final isPdf = path.toLowerCase().endsWith('.pdf');
    if (isPdf && !type.acceptsPdf) {
      // Mirrors the live client's local check, which never sends this.
      throw const ServerException(
        message: 'A PDF can only be attached to the patent/tax or VAT slot.',
      );
    }

    final id = _backend.nextId('demo-doc');
    final document = DepotDocument(
      id: id,
      type: type,
      fileName: path.split(RegExp(r'[/\\]')).last,
      contentType: isPdf ? 'application/pdf' : 'image/jpeg',
      url: path,
      publicUrl: type.isPubliclyVisible ? path : null,
      isPubliclyVisible: type.isPubliclyVisible,
      capturedAt: capturedAt,
      uploadedAt: _backend.now(),
    );
    _backend.documentsOf(depotId)[type] = document;
    return document;
  }

  @override
  Future<DepotDocumentsState> fetch(String depotId) async {
    await MockLatency.tick();
    final byType = Map.of(_backend.documentsOf(depotId));
    final missing = {
      for (final type in DepotDocumentType.values)
        if (type.isRequiredFor(isVatRegistered: false) &&
            !byType.containsKey(type))
          type,
    };
    return DepotDocumentsState(
      byType: byType,
      missingRequired: missing,
      isComplete: missing.isEmpty,
    );
  }

  @override
  Future<void> delete({
    required String depotId,
    required String documentId,
  }) async {
    await Future<void>.delayed(_writeLatency);
    _backend
        .documentsOf(depotId)
        .removeWhere((_, document) => document.id == documentId);
  }
}
