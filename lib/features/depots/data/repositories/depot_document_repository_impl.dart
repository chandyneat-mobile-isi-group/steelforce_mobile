import 'dart:io';

import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/logging/debug_trace.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/remote/depot_document_remote_data_source.dart';
import 'package:steelforce/features/depots/domain/entities/depot_document.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_document_repository.dart';

/// Console tracer, sharing the registration channel so a submit and its
/// evidence uploads read as one sequence.
const _trace = DebugTrace('registration');

class DepotDocumentRepositoryImpl implements DepotDocumentRepository {
  const DepotDocumentRepositoryImpl({
    required DepotDocumentRemoteDataSource remote,
    required AppLogger logger,
  })  : _remote = remote,
        _logger = logger;

  final DepotDocumentRemoteDataSource _remote;
  final AppLogger _logger;

  @override
  ResultFuture<DepotDocumentsState> fetch(String depotId) async {
    try {
      return Success(await _remote.fetch(depotId));
    } on ApiException catch (e) {
      _logger.error('depots.documents.fetch.failed', fields: {
        'errorCode': e.error.code,
        'status': e.error.statusCode,
        'correlationId': e.error.correlationId,
      });
      return Failed(ServerFailure(
        message: e.error.message ?? 'Could not load the depot documents.',
        statusCode: e.error.statusCode,
      ));
    } on ServerException catch (e) {
      return Failed(
          ServerFailure(message: e.message, statusCode: e.statusCode));
    }
  }

  @override
  ResultFuture<DepotDocumentUploadOutcome> uploadAll({
    required String depotId,
    required List<PendingDepotDocument> documents,
    void Function(int completed, int total)? onProgress,
  }) async {
    var completed = 0;
    final uploaded = <DepotDocumentType>[];
    final failed = <DepotDocumentType>[];
    final rejected = <DepotDocumentType>[];

    for (final pending in documents) {
      final file = File(pending.filePath);

      // The camera file can be gone by the time this runs — a share sheet, a
      // cache sweep, an OS cleanup. Nothing to retry, so it is a rejection.
      if (!file.existsSync()) {
        _logger.warning('depots.documents.upload.fileMissing',
            fields: {'slot': pending.type.code});
        rejected.add(pending.type);
        onProgress?.call(++completed, documents.length);
        continue;
      }

      try {
        await _remote.upload(
          depotId: depotId,
          type: pending.type,
          file: file,
          capturedAt: pending.capturedAt,
        );
        uploaded.add(pending.type);
        _trace.ok('photo', 'sent', {'slot': pending.type.code});
      } on ApiException catch (e) {
        final status = e.error.statusCode ?? 0;
        // A 4xx will fail identically forever — the wrong file kind for the
        // slot, a mismatched content type, over 10 MB. Retrying it only spends
        // a rep's connection, so it is surfaced rather than queued.
        final permanent = status >= 400 && status < 500;
        (permanent ? rejected : failed).add(pending.type);

        _trace.fail('photo', permanent ? 'rejected' : 'will retry', {
          'slot': pending.type.code,
          'status': status,
          'code': e.error.code
        });
        _logger.error('depots.documents.upload.failed', fields: {
          // The slot, never the file path or the depot's details.
          'slot': pending.type.code,
          'errorCode': e.error.code,
          'status': status,
          'permanent': permanent,
          'correlationId': e.error.correlationId,
        });
      } on ServerException catch (_) {
        // Raised locally for a file the slot cannot accept — same class as a
        // 4xx: it will not start working on a retry.
        rejected.add(pending.type);
      } on Object catch (e) {
        // A dropped connection or a filesystem error. Worth another attempt.
        _logger.warning('depots.documents.upload.transient', fields: {
          'slot': pending.type.code,
          'errorType': '${e.runtimeType}'
        });
        failed.add(pending.type);
      }
      // Ticked whatever the outcome: a rejected photo is still one fewer for
      // the rep to wait on, and a bar that stalls on a failure reads as a hang.
      onProgress?.call(++completed, documents.length);
    }

    _logger.info('depots.documents.upload.done', fields: {
      'uploaded': uploaded.length,
      'failed': failed.length,
      'rejected': rejected.length,
    });

    // Always a Success: the depot already exists, and reporting failure here
    // would invite a caller to treat the registration itself as failed.
    return Success(DepotDocumentUploadOutcome(
      uploaded: uploaded,
      failed: failed,
      rejected: rejected,
    ));
  }

  @override
  ResultFuture<void> delete({
    required String depotId,
    required String documentId,
  }) async {
    try {
      await _remote.delete(depotId: depotId, documentId: documentId);
      return const Success(null);
    } on ApiException catch (e) {
      _logger.error('depots.documents.delete.failed', fields: {
        'errorCode': e.error.code,
        'status': e.error.statusCode,
      });
      return Failed(ServerFailure(
        message: e.error.message ?? 'Could not remove the document.',
        statusCode: e.error.statusCode,
      ));
    }
  }
}
