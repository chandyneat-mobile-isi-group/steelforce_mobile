/// `/api/v1/mobile/depots/{depotId}/documents`, held in memory.
///
/// One live document per slot, as on the server: uploading a slot again
/// replaces it. `missingRequired` and `isComplete` are computed here the way
/// the server computes them, because the repository reads them rather than
/// counting for itself.
///
/// No file leaves the device. The returned URLs use a `demo://` scheme so
/// nothing in a demo build can try to fetch them over the network.
///
/// TODO(release-gate): demo-only, selected only when DataSourceMode.useMocks.
library;

import 'dart:io';

import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/models/depot_document_mapper.dart';
import 'package:steelforce/features/depots/data/remote/depot_document_remote_data_source.dart';
import 'package:steelforce/features/depots/domain/entities/depot_document.dart';

class DemoDepotDocumentRemoteDataSource
    implements DepotDocumentRemoteDataSource {
  DemoDepotDocumentRemoteDataSource(this._network, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DemoNetwork _network;
  final DateTime Function() _clock;

  /// depotId → slot code → document JSON.
  final Map<String, Map<String, DataMap>> _store = {};
  int _sequence = 0;

  @override
  Future<DepotDocument> upload({
    required String depotId,
    required DepotDocumentType type,
    required File file,
    DateTime? capturedAt,
  }) async {
    final contentType = _contentTypeFor(file.path, type);
    await _network.roundTrip();

    final id = 'demo-doc-${(++_sequence).toString().padLeft(4, '0')}';
    final json = <String, dynamic>{
      'id': id,
      'type': type.code,
      'typeDisplay': null,
      'fileName': file.uri.pathSegments.last,
      'contentType': contentType,
      'sizeBytes': file.existsSync() ? file.lengthSync() : null,
      'url': 'demo://depots/$depotId/documents/$id',
      // Mirrors the server: only the storefront slots are ever published.
      'publicUrl': type.isPubliclyVisible ? 'demo://public/$id' : null,
      'isPubliclyVisible': type.isPubliclyVisible,
      'capturedAt': capturedAt?.toUtc().toIso8601String(),
      'uploadedAt': _clock().toUtc().toIso8601String(),
    };
    _store.putIfAbsent(depotId, () => {})[type.code] = json;

    final document = DepotDocumentMapper.fromJson(
      ApiEnvelope.fromBody({'success': true, 'data': json}).data,
    );
    if (document == null) {
      throw const ServerException(
        message: 'The upload response was missing its payload.',
      );
    }
    return document;
  }

  @override
  Future<DepotDocumentsState> fetch(String depotId) async {
    await _network.roundTrip();
    final slots = _store[depotId] ?? const <String, DataMap>{};
    final missing = [
      for (final type in DepotDocumentType.values)
        if (type.isAlwaysRequired && !slots.containsKey(type.code)) type.code,
    ];
    final body = {
      'success': true,
      'data': {
        'documents': slots.values.toList(),
        'missingRequired': missing,
        'isComplete': missing.isEmpty,
      },
    };
    return DepotDocumentMapper.stateFromJson(ApiEnvelope.fromBody(body).data);
  }

  @override
  Future<void> delete({
    required String depotId,
    required String documentId,
  }) async {
    await _network.roundTrip();
    _store[depotId]?.removeWhere((_, doc) => doc['id'] == documentId);
  }

  /// The same pre-flight check the live source makes before spending an
  /// upload: a PDF may only go into a document slot.
  static String _contentTypeFor(String path, DepotDocumentType type) {
    final extension = path.toLowerCase().split('.').last;
    if (extension == 'pdf') {
      if (!type.acceptsPdf) {
        throw const ServerException(
          message: 'A PDF can only be attached to the patent/tax or VAT slot.',
        );
      }
      return 'application/pdf';
    }
    return extension == 'png' ? 'image/png' : 'image/jpeg';
  }
}
