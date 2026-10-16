import 'package:drift/drift.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/daos/depot_registration_queue_dao.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/features/depots/data/local/queued_photo_files.dart';
import 'package:steelforce/features/depots/data/models/queued_photo.dart';
import 'package:steelforce/features/depots/data/repositories/outbox/registration_send_policy.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_document_repository.dart';

/// Files the photographs of a registration SAP has already accepted, and
/// retires the queue row once nothing is left to send.
class QueuedPhotoUploader {
  QueuedPhotoUploader({
    required DepotRegistrationQueueDao dao,
    required DepotDocumentRepository documents,
    required QueuedPhotoFiles files,
    required AppLogger logger,
    required DateTime Function() clock,
  })  : _dao = dao,
        _documents = documents,
        _files = files,
        _logger = logger,
        _clock = clock;

  final DepotRegistrationQueueDao _dao;
  final DepotDocumentRepository _documents;
  final QueuedPhotoFiles _files;
  final AppLogger _logger;
  final DateTime Function() _clock;

  /// One upload round for [row], which the caller has claimed as
  /// `uploadingPhotos`. Always leaves the row in a resting state.
  Future<void> upload(DepotRegistrationQueueRow row) async {
    final photos = QueuedPhoto.decode(row.attachments);
    final depotId = row.depotId;
    if (photos.isEmpty || depotId == null || depotId.isEmpty) {
      await finish(row.id, photos);
      return;
    }

    DepotDocumentUploadOutcome outcome;
    try {
      final result = await _documents.uploadAll(
        depotId: depotId,
        documents: [
          for (final p in photos)
            PendingDepotDocument(
              type: p.type,
              filePath: p.path,
              capturedAt: p.capturedAt,
            ),
        ],
      );
      outcome = result.when(
        success: (o) => o,
        failure: (_) => DepotDocumentUploadOutcome(
          failed: [for (final p in photos) p.type],
        ),
      );
    } catch (e) {
      // `uploadAll` is contracted not to throw, but a throw here would strand
      // the row in `uploadingPhotos`. Counted as a failed round instead, so
      // the transition below is always persisted and the cap always applies.
      _logger.warning(
        'depots.outbox.photos_threw',
        fields: {'reason': e.runtimeType.toString()},
      );
      outcome = DepotDocumentUploadOutcome(
        failed: [for (final p in photos) p.type],
      );
    }

    // A 4xx (wrong type, over 10 MB) fails identically forever, so it is
    // dropped rather than retried; the depot's checklist still shows the gap.
    if (outcome.rejected.isNotEmpty) {
      _logger.warning(
        'depots.outbox.photos_rejected',
        fields: {'count': outcome.rejected.length},
      );
    }
    final retry = outcome.failed.toSet();
    final remaining = photos.where((p) => retry.contains(p.type)).toList();
    for (final p in photos) {
      if (!retry.contains(p.type)) _files.delete(p.path);
    }

    if (remaining.isEmpty) {
      await _dao.remove(row.id);
      _logger.info('depots.outbox.done');
      return;
    }
    final attempts = row.attempts + 1;
    if (attempts >= RegistrationSendPolicy.maxPhotoAttempts) {
      // The depot is registered; only evidence is missing, and the server's
      // checklist keeps HQ approval blocked until it is filed from the
      // depot's detail screen. Holding the row any longer would only keep the
      // rep from signing out.
      _logger.warning(
        'depots.outbox.photos_abandoned',
        fields: {'count': remaining.length},
      );
      await finish(row.id, remaining);
      return;
    }
    await _dao.patch(
      row.id,
      DepotRegistrationQueueCompanion(
        status: const Value('photosPending'),
        attachments: Value(QueuedPhoto.encode(remaining)),
        attempts: Value(attempts),
        nextAttemptAt:
            Value(_clock().add(RegistrationSendPolicy.backoff(attempts))),
      ),
    );
  }

  /// Deletes the kept files of [photos] and the row itself.
  Future<void> finish(String id, List<QueuedPhoto> photos) async {
    for (final p in photos) {
      _files.delete(p.path);
    }
    await _dao.remove(id);
  }
}
