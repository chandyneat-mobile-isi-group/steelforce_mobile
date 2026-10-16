import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/daos/depot_registration_queue_dao.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/sync/background/sync_run_context.dart';
import 'package:steelforce/features/depots/data/models/business_partner_request_model.dart';
import 'package:steelforce/features/depots/data/models/queued_photo.dart';
import 'package:steelforce/features/depots/data/repositories/outbox/queued_photo_uploader.dart';
import 'package:steelforce/features/depots/data/repositories/outbox/registration_send_policy.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_request.dart';
import 'package:steelforce/features/depots/domain/entities/pending_depot_registration.dart';
import 'package:steelforce/features/depots/domain/repositories/business_partner_repository.dart';

/// Sends queued registrations to SAP, oldest first, and moves each row through
/// its states. The policy it applies is described on
/// `DepotRegistrationOutbox`; the retry rules are [RegistrationSendPolicy].
class RegistrationDrain {
  RegistrationDrain({
    required DepotRegistrationQueueDao dao,
    required BusinessPartnerRepository registrations,
    required QueuedPhotoUploader photos,
    required AppLogger logger,
    required DateTime Function() clock,
    required Future<void> Function(Duration) pause,
    required this.sendSpacing,
  })  : _dao = dao,
        _registrations = registrations,
        _photos = photos,
        _logger = logger,
        _clock = clock,
        _pause = pause;

  final DepotRegistrationQueueDao _dao;
  final BusinessPartnerRepository _registrations;
  final QueuedPhotoUploader _photos;
  final AppLogger _logger;
  final DateTime Function() _clock;
  final Future<void> Function(Duration) _pause;

  /// The gap left between two registrations in one drain.
  final Duration sendSpacing;

  bool _draining = false;

  Future<void> run() async {
    // One drain per isolate. Across isolates the per-row claim does the work.
    if (_draining) return;
    _draining = true;
    try {
      final run = _DrainRun();
      // Oldest first (`createdAt`), so registrations reach SAP in the order
      // the rep made them.
      for (final row in await _dao.all()) {
        final keepGoing = await _step(row, run);
        if (!keepGoing) break;
      }
    } catch (e, stack) {
      _logger.error('depots.outbox.drain_failed', error: e, stackTrace: stack);
    } finally {
      _draining = false;
    }
  }

  /// Advances one row. Returns false when the drain should stop — the network
  /// is gone, the session is, or the server is turning requests away, and
  /// every following row would fail the same way.
  ///
  /// Registrations keep their order: once one has to wait (backing off, held
  /// by another drain, or no time left in a background run), the ones behind
  /// it wait too, rather than overtaking it. Rows waiting on the rep
  /// (`needsReview`, `rejected`) never hold the line — they could wait for
  /// days — and photo uploads for depots already registered carry on.
  Future<bool> _step(DepotRegistrationQueueRow row, _DrainRun run) async {
    final now = _clock();
    switch (DepotRegistrationQueueStatus.parse(row.status)) {
      case DepotRegistrationQueueStatus.queued:
        if (run.postsHeld) return true;
        final due = row.nextAttemptAt;
        if (due != null && due.isAfter(now)) {
          run.postsHeld = true;
          return true;
        }
        final gap = run.sentAny ? sendSpacing : Duration.zero;
        // Not enough time left for the gap and a full request: the OS would
        // end the run mid-send, losing the answer and parking a sendable row
        // for review. Left for a run with time, or the app itself.
        if (!SyncRunContext.hasTimeFor(SyncRunContext.longestRequest + gap)) {
          run.postsHeld = true;
          return true;
        }
        if (gap > Duration.zero) await _pause(gap);
        if (!await _dao.claim(
          row.id,
          from: row.status,
          to: DepotRegistrationQueueStatus.sending.name,
          at: _clock(),
        )) {
          // Discarded by the rep during the pause: nothing to wait for.
          // Otherwise another drain is sending it, and sends the rest after.
          if (await _dao.byId(row.id) != null) run.postsHeld = true;
          return true;
        }
        run.sentAny = true;
        return _send(row);

      case DepotRegistrationQueueStatus.photosPending:
        final due = row.nextAttemptAt;
        if (due != null && due.isAfter(now)) return true;
        if (!await _dao.claim(
          row.id,
          from: row.status,
          to: DepotRegistrationQueueStatus.uploadingPhotos.name,
          at: now,
        )) {
          return true;
        }
        await _photos.upload(row);
        return true;

      case DepotRegistrationQueueStatus.sending:
        // Left mid-request by a process that died, or still on the wire in
        // another isolate. Only the first is touched — and it goes to the rep,
        // never back to the queue, because SAP may already hold it.
        if (_isStale(row, now)) {
          _logger.warning('depots.outbox.stranded_send');
          await _dao.patch(
            row.id,
            const DepotRegistrationQueueCompanion(
              status: Value('needsReview'),
              lastMessage: Value(null),
            ),
          );
        } else {
          // Still on the wire elsewhere: the rows behind it wait their turn.
          run.postsHeld = true;
        }
        return true;

      case DepotRegistrationQueueStatus.uploadingPhotos:
        // The depot exists, so a stranded upload is safe to resume.
        if (_isStale(row, now,
            after: RegistrationSendPolicy.staleUploadClaim)) {
          await _dao.patch(
            row.id,
            const DepotRegistrationQueueCompanion(
              status: Value('photosPending'),
            ),
          );
        }
        return true;

      case DepotRegistrationQueueStatus.needsReview:
      case DepotRegistrationQueueStatus.rejected:
        return true; // waiting on the rep
    }
  }

  bool _isStale(
    DepotRegistrationQueueRow row,
    DateTime now, {
    Duration after = RegistrationSendPolicy.staleClaim,
  }) {
    final at = row.lastAttemptAt;
    return at == null || now.difference(at) > after;
  }

  Future<bool> _send(DepotRegistrationQueueRow row) async {
    final attempts = row.attempts + 1;
    final BusinessPartnerRequest request;
    try {
      request = BusinessPartnerRequestModel.fromJson(
        Map<String, dynamic>.from(jsonDecode(row.payload) as Map),
      );
    } catch (_) {
      await _toRep(row.id, DepotRegistrationQueueStatus.rejected, null);
      return true;
    }

    final result = await _registrations.createBusinessPartner(request);
    return result.when(
      success: (created) async {
        _logger.info(
          'depots.outbox.sent',
          fields: {
            'pendingApproval': created.isPendingApproval,
            'attempts': attempts,
          },
        );
        final photos = QueuedPhoto.decode(row.attachments);
        final documentId = created.documentId;
        if (photos.isEmpty || documentId.isEmpty) {
          if (photos.isNotEmpty) {
            // Accepted, but with no id to file evidence against. The depot is
            // registered; the photographs can be added from its detail screen.
            _logger.warning(
              'depots.outbox.photos_without_depot_id',
              fields: {'photos': photos.length},
            );
          }
          await _photos.finish(row.id, photos);
          return true;
        }
        await _dao.patch(
          row.id,
          DepotRegistrationQueueCompanion(
            status: const Value('photosPending'),
            depotId: Value(documentId),
            depotNumber: Value(created.depotNumber),
            // From here `attempts` counts photo rounds.
            attempts: const Value(0),
            nextAttemptAt: const Value(null),
            lastMessage: const Value(null),
          ),
        );
        final refreshed = await _dao.byId(row.id);
        if (refreshed != null &&
            await _dao.claim(
              row.id,
              from: DepotRegistrationQueueStatus.photosPending.name,
              to: DepotRegistrationQueueStatus.uploadingPhotos.name,
              at: _clock(),
            )) {
          await _photos.upload(refreshed);
        }
        return true;
      },
      failure: (failure) => _onSendFailure(row, failure, attempts),
    );
  }

  /// Applies [RegistrationSendPolicy.onSendFailure] to the row.
  Future<bool> _onSendFailure(
    DepotRegistrationQueueRow row,
    Failure failure,
    int attempts,
  ) async {
    _logger.warning(
      'depots.outbox.send_failed',
      fields: {
        'failure': failure.runtimeType.toString(),
        if (failure is ServerFailure) 'status': failure.statusCode,
        'attempts': attempts,
      },
    );
    final decision = RegistrationSendPolicy.onSendFailure(failure, attempts);
    switch (decision) {
      case Requeue(:final reason, backOff: true):
        await _requeue(
          row.id,
          attempts: attempts,
          nextAttemptAt: _clock().add(RegistrationSendPolicy.backoff(attempts)),
          reason: reason,
        );
      case Requeue(:final reason):
        await _requeue(
          row.id,
          attempts: row.attempts,
          nextAttemptAt: null,
          reason: reason,
        );
      case HandToRep(:final status, :final message):
        await _toRep(row.id, status, message);
    }
    return !decision.stopsDrain;
  }

  /// Back in the queue. [reason] says why it has not gone yet, for the row
  /// in the Sync Center; null clears it.
  Future<void> _requeue(String id,
          {required int attempts,
          required DateTime? nextAttemptAt,
          String? reason}) =>
      _dao.patch(
          id,
          DepotRegistrationQueueCompanion(
            status: const Value('queued'),
            attempts: Value(attempts),
            nextAttemptAt: Value(nextAttemptAt),
            lastMessage: Value(reason),
          ));

  Future<void> _toRep(
    String id,
    DepotRegistrationQueueStatus status,
    String? message,
  ) =>
      _dao.patch(
        id,
        DepotRegistrationQueueCompanion(
          status: Value(status.name),
          lastMessage: Value(message),
          nextAttemptAt: const Value(null),
        ),
      );
}

/// What one drain has done so far.
class _DrainRun {
  /// A registration has gone out, so the next waits
  /// [RegistrationDrain.sendSpacing].
  bool sentAny = false;

  /// An earlier registration is still waiting; later ones must not overtake it.
  bool postsHeld = false;
}
