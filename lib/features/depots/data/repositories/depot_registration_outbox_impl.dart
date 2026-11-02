import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/daos/depot_registration_queue_dao.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/sync/background/sync_run_context.dart';
import 'package:steelforce/core/platform/storage/captured_media_store.dart'
    as media;
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/core/utils/uuid.dart';
import 'package:steelforce/features/depots/data/local/bp_draft_cache.dart';
import 'package:steelforce/features/depots/data/models/bp_depot_form_data.dart';
import 'package:steelforce/features/depots/data/models/business_partner_request_model.dart';
import 'package:steelforce/features/depots/data/repositories/depot_draft_outbox_route.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_request.dart';
import 'package:steelforce/features/depots/domain/entities/depot_document.dart';
import 'package:steelforce/features/depots/domain/entities/pending_depot_registration.dart';
import 'package:steelforce/features/depots/domain/repositories/business_partner_repository.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_document_repository.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_registration_outbox.dart';

/// Copies and deletes the photographs a queued registration holds. A seam so
/// tests need no filesystem; production uses `captured_media_store`.
class QueuedPhotoFiles {
  const QueuedPhotoFiles();

  /// Moves a captured file somewhere the OS will not clear before the replay.
  ///
  /// The picker writes to a cache directory that iOS and Android may empty at
  /// any time, and a queued registration can wait hours for a connection. On
  /// web there is no directory and the `blob:` reference is returned as-is —
  /// it lives as long as the tab (ADR-010).
  Future<String> keep(String sourcePath, {required String fileName}) async {
    final dir = await media.appMediaDirectory(_folder);
    if (dir == null) return sourcePath;
    return media.copyCapturedFile(
      sourcePath,
      targetDirectory: dir,
      fileName: fileName,
    );
  }

  void delete(String path) => media.deleteCapturedFile(path);

  static const _folder = 'depot_registration_queue';
}

/// Drift-backed [DepotRegistrationOutbox]. See the interface for the policy.
class DepotRegistrationOutboxImpl implements DepotRegistrationOutbox {
  DepotRegistrationOutboxImpl({
    required DepotRegistrationQueueDao dao,
    required BusinessPartnerRepository registrations,
    required DepotDocumentRepository documents,
    required BpDraftCache draftCache,
    required AppLogger logger,
    DepotDraftOutboxRoute? drafts,
    QueuedPhotoFiles files = const QueuedPhotoFiles(),
    void Function()? onEnqueued,
    DateTime Function()? clock,
    this.sendSpacing = defaultSendSpacing,
    this.replaysToLegacyRoute = false,
    Future<void> Function(Duration)? pause,
  })  : _dao = dao,
        _registrations = registrations,
        _documents = documents,
        _draftCache = draftCache,
        _logger = logger,
        _drafts = drafts,
        _files = files,
        _onEnqueued = onEnqueued,
        _clock = clock ?? (() => DateTime.now().toUtc()),
        _pause = pause ?? ((d) => Future<void>.delayed(d));

  final DepotRegistrationQueueDao _dao;
  final BusinessPartnerRepository _registrations;
  final DepotDocumentRepository _documents;
  final BpDraftCache _draftCache;
  final AppLogger _logger;

  /// Replays wizard registrations queued by [enqueueDraft]. Null only in
  /// tests of the legacy route; such a row then goes to the rep.
  final DepotDraftOutboxRoute? _drafts;
  final QueuedPhotoFiles _files;

  /// Tells the sync engine there is something to send. A callback because the
  /// engine lives in `core/sync` and is wired in DI.
  final void Function()? _onEnqueued;
  final DateTime Function() _clock;
  final Future<void> Function(Duration) _pause;

  /// The gap left between two registrations in one drain.
  ///
  /// A rep who registered a day's worth of shops offline reconnects with all
  /// of them queued. Each one is a synchronous SAP write, so they go one at a
  /// time, oldest first, with this breathing space between them rather than
  /// as a burst the gateway answers with 503s.
  final Duration sendSpacing;
  static const Duration defaultSendSpacing = Duration(seconds: 2);

  /// Off in the app: `POST /mobile/depots/business-partner` is retired, and
  /// the wizard now saves to `/api/v1/depot-drafts`. A row an earlier build
  /// queued is handed back to the rep instead of replayed — it keeps its form
  /// snapshot, so "reopen as draft" sends it through the new route. On only
  /// in the outbox's own tests, which still cover the replay machinery.
  final bool replaysToLegacyRoute;

  /// The reason shown on a row handed back for that.
  static const String resendWithNewForm = 'sync_center.depot.resend_new_form';

  /// A gateway 5xx is retried this many times before the row is handed to the
  /// rep. Nothing reached SAP on those, so they are safe — but a server that
  /// fails eight times running needs a human, not a ninth attempt.
  static const int maxGatewayAttempts = 8;

  /// Photo upload rounds before the photographs are given up on. The depot
  /// exists by then, so this costs evidence (refiled from the detail screen),
  /// never a registration.
  static const int maxPhotoAttempts = 10;

  /// The write timeout is 60 s; a row still `sending` after this was left
  /// behind by a process that died mid-request.
  static const Duration staleClaim = Duration(minutes: 3);

  /// Several photographs on a slow link can take far longer than one request,
  /// so an upload claim is given longer before it is presumed dead.
  static const Duration staleUploadClaim = Duration(minutes: 20);

  bool _draining = false;

  /// States the rep may discard from: everything except a row a drain has
  /// claimed and is using.
  static final Set<String> discardable = {
    DepotRegistrationQueueStatus.queued.name,
    DepotRegistrationQueueStatus.photosPending.name,
    DepotRegistrationQueueStatus.needsReview.name,
    DepotRegistrationQueueStatus.rejected.name,
  };

  /// Why a queued row has not gone yet — localization keys, shown on the row.
  static const String reasonOffline = 'sync_center.depot.reason.offline';
  static const String reasonSignedOut = 'sync_center.depot.reason.signed_out';
  static const String reasonServerBusy = 'sync_center.depot.reason.server_busy';

  /// [reopenAsDraft]'s refusal when the wizard already holds a form. A
  /// localization key, resolved by the presentation layer.
  static const String draftInProgress = 'sync_center.depot.draft_in_progress';

  // ---------------------------------------------------------------------
  // Enqueue
  // ---------------------------------------------------------------------

  @override
  ResultFuture<String> enqueue({
    required BusinessPartnerRequest request,
    required String depotName,
    required List<PendingDepotDocument> photos,
    bool mayHaveLanded = false,
    String? message,
    Map<String, dynamic>? draftSnapshot,
  }) =>
      _store(
        payload: jsonEncode(
          BusinessPartnerRequestModel.fromEntity(request).toJson(),
        ),
        depotName: depotName,
        photos: photos,
        mayHaveLanded: mayHaveLanded,
        message: message,
        draftSnapshot: draftSnapshot,
      );

  @override
  ResultFuture<String> enqueueDraft({
    required String clientDraftId,
    required String depotName,
    required Map<String, dynamic> draftSnapshot,
    required List<PendingDepotDocument> photos,
  }) =>
      _store(
        payload: DepotDraftOutboxRoute.payloadFor(clientDraftId),
        depotName: depotName,
        photos: photos,
        draftSnapshot: draftSnapshot,
      );

  ResultFuture<String> _store({
    required String payload,
    required String depotName,
    required List<PendingDepotDocument> photos,
    bool mayHaveLanded = false,
    String? message,
    Map<String, dynamic>? draftSnapshot,
  }) async {
    final id = Uuid.v4();
    try {
      final kept = <_QueuedPhoto>[];
      for (final photo in photos) {
        try {
          final path = await _files.keep(
            photo.filePath,
            fileName: '${id}_${photo.type.name}${_extension(photo.filePath)}',
          );
          kept.add(_QueuedPhoto(photo.type, path, photo.capturedAt));
        } catch (_) {
          // A photograph that cannot be copied is lost either way; losing the
          // registration with it would be worse. The server's own checklist
          // blocks HQ approval until the slot is filled.
          _logger.warning(
            'depots.outbox.photo_not_kept',
            fields: {'type': photo.type.code},
          );
        }
      }

      await _dao.insert(
        DepotRegistrationQueueCompanion.insert(
          id: id,
          depotName: depotName,
          payload: payload,
          draftJson: Value(
            draftSnapshot == null ? null : jsonEncode(draftSnapshot),
          ),
          attachments: Value(_QueuedPhoto.encode(kept)),
          status: mayHaveLanded
              ? DepotRegistrationQueueStatus.needsReview.name
              : DepotRegistrationQueueStatus.queued.name,
          lastMessage: Value(message),
          createdAt: _clock(),
        ),
      );
      _logger.info(
        'depots.outbox.enqueued',
        fields: {'needsReview': mayHaveLanded, 'photos': kept.length},
      );
      if (!mayHaveLanded) _onEnqueued?.call();
      return Success(id);
    } catch (e) {
      return Failed(CacheFailure(message: e.toString()));
    }
  }

  // ---------------------------------------------------------------------
  // Drain
  // ---------------------------------------------------------------------

  @override
  Future<void> drain() async {
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
        await _uploadPhotos(row);
        return true;

      case DepotRegistrationQueueStatus.sending:
        // Left mid-request by a process that died, or still on the wire in
        // another isolate. Only the first is touched — and it goes to the rep,
        // never back to the queue, because SAP may already hold it.
        if (_isStale(row, now) && DepotDraftOutboxRoute.owns(row.payload)) {
          // Idempotent: a resend returns the record if this one did land.
          await _requeue(row.id,
              attempts: row.attempts, nextAttemptAt: null, reason: null);
        } else if (_isStale(row, now)) {
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
        if (_isStale(row, now, after: staleUploadClaim)) {
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
    Duration after = staleClaim,
  }) {
    final at = row.lastAttemptAt;
    return at == null || now.difference(at) > after;
  }

  Future<bool> _send(DepotRegistrationQueueRow row) async {
    if (DepotDraftOutboxRoute.owns(row.payload)) return _sendDraft(row);
    if (!replaysToLegacyRoute) {
      _logger.info('depots.outbox.handed_back_legacy');
      await _toRep(
        row.id,
        DepotRegistrationQueueStatus.rejected,
        resendWithNewForm,
      );
      return true;
    }
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
        final photos = _QueuedPhoto.decode(row.attachments);
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
          await _finish(row.id, photos);
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
          await _uploadPhotos(refreshed);
        }
        return true;
      },
      failure: (failure) => _onSendFailure(row, failure, attempts),
    );
  }

  /// Sends a row queued by [enqueueDraft]. The route is idempotent, so an
  /// unanswered or failed send goes back to the queue rather than to review.
  Future<bool> _sendDraft(DepotRegistrationQueueRow row) async {
    final drafts = _drafts;
    final form = DepotDraftOutboxRoute.formOf(row.draftJson);
    if (drafts == null || form == null) {
      await _toRep(row.id, DepotRegistrationQueueStatus.rejected, null);
      return true;
    }
    final attempts = row.attempts + 1;
    final result = await drafts.send(form);
    return result.when(
      success: (saved) async {
        _logger.info('depots.outbox.draft_sent', fields: {
          'attempts': attempts,
        });
        await _dao.patch(
          row.id,
          DepotRegistrationQueueCompanion(
            status: const Value('photosPending'),
            depotId: Value(saved.id),
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
          await _uploadPhotos(refreshed);
        }
        return true;
      },
      failure: (failure) async {
        _logger.warning('depots.outbox.draft_send_failed', fields: {
          'failure': failure.runtimeType.toString(),
          if (failure is ServerFailure) 'status': failure.statusCode,
          if (failure is DepotDraftRejectedFailure)
            'status': failure.statusCode,
          'attempts': attempts,
        });
        if (failure is NetworkFailure || failure is ServerUnreachableFailure) {
          await _requeue(row.id,
              attempts: row.attempts,
              nextAttemptAt: null,
              reason: reasonOffline);
          return false;
        }
        if (failure is AuthenticationFailure) {
          await _requeue(row.id,
              attempts: row.attempts,
              nextAttemptAt: null,
              reason: reasonSignedOut);
          return false;
        }
        if (DepotDraftOutboxRoute.isBusy(failure)) {
          if (attempts >= maxGatewayAttempts) {
            await _toRep(
                row.id, DepotRegistrationQueueStatus.needsReview, null);
            return true;
          }
          await _requeue(row.id,
              attempts: attempts,
              nextAttemptAt: _backoff(attempts),
              reason: reasonServerBusy);
          return false;
        }
        // Refused (validation, a reused id, forbidden): the rep reopens the
        // form, fixes it, and sends it again from the wizard.
        await _toRep(
          row.id,
          DepotRegistrationQueueStatus.rejected,
          failure.message,
        );
        return true;
      },
    );
  }

  /// Applies the retry policy. See [DepotRegistrationOutbox].
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
    switch (failure) {
      // Never left the handset. Back in the queue untouched, and the drain
      // stops: the rows behind it would fail identically.
      case NetworkFailure():
      case ServerUnreachableFailure():
        await _requeue(row.id,
            attempts: row.attempts, nextAttemptAt: null, reason: reasonOffline);
        return false;

      // The session needs the rep (sign in again). Nothing was sent.
      case AuthenticationFailure():
        await _requeue(row.id,
            attempts: row.attempts,
            nextAttemptAt: null,
            reason: reasonSignedOut);
        return false;

      case ServerFailure(:final statusCode):
        // The gateway refused it before SAP. Safe to resend, with backoff.
        if (isSafeToResendServerError(statusCode)) {
          if (attempts >= maxGatewayAttempts) {
            await _toRep(
              row.id,
              DepotRegistrationQueueStatus.needsReview,
              failure.message,
            );
            return true;
          }
          await _requeue(row.id,
              attempts: attempts,
              nextAttemptAt: _backoff(attempts),
              reason: reasonServerBusy);
          // The gateway is struggling. Sending the next registration straight
          // into it would only add load; everything waits for this backoff.
          return false;
        }
        // Any other 5xx — a 504 (no answer), a 500 (raised after SAP may have
        // written it) — may have landed. The rep checks first.
        if (statusCode != null && statusCode >= 500) {
          await _toRep(row.id, DepotRegistrationQueueStatus.needsReview, null);
          return true;
        }
        // SAP (or the app's own pre-send check) said no.
        await _toRep(
          row.id,
          DepotRegistrationQueueStatus.rejected,
          failure.message,
        );
        return true;

      case CacheFailure():
      case DepotStopInformationUnavailableFailure():
      case AdHocVisitRefusedFailure():
      case DepotDraftRejectedFailure():
        await _toRep(
          row.id,
          DepotRegistrationQueueStatus.rejected,
          failure.message,
        );
        return true;
    }
  }

  Future<void> _uploadPhotos(DepotRegistrationQueueRow row) async {
    final photos = _QueuedPhoto.decode(row.attachments);
    final depotId = row.depotId;
    if (photos.isEmpty || depotId == null || depotId.isEmpty) {
      await _finish(row.id, photos);
      return;
    }

    DepotDocumentUploadOutcome outcome;
    try {
      final documents = [
        for (final p in photos)
          PendingDepotDocument(
            type: p.type,
            filePath: p.path,
            capturedAt: p.capturedAt,
          ),
      ];
      final drafts = _drafts;
      final form = DepotDraftOutboxRoute.formOf(row.draftJson);
      if (DepotDraftOutboxRoute.owns(row.payload) &&
          drafts != null &&
          form != null) {
        outcome = await drafts.upload(depotId, form, documents);
      } else {
        final result = await _documents.uploadAll(
          depotId: depotId,
          documents: documents,
        );
        outcome = result.when(
          success: (o) => o,
          failure: (_) => DepotDocumentUploadOutcome(
            failed: [for (final p in photos) p.type],
          ),
        );
      }
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
    if (attempts >= maxPhotoAttempts) {
      // The depot is registered; only evidence is missing, and the server's
      // checklist keeps HQ approval blocked until it is filed from the
      // depot's detail screen. Holding the row any longer would only keep the
      // rep from signing out.
      _logger.warning(
        'depots.outbox.photos_abandoned',
        fields: {'count': remaining.length},
      );
      await _finish(row.id, remaining);
      return;
    }
    await _dao.patch(
      row.id,
      DepotRegistrationQueueCompanion(
        status: const Value('photosPending'),
        attachments: Value(_QueuedPhoto.encode(remaining)),
        attempts: Value(attempts),
        nextAttemptAt: Value(_backoff(attempts)),
      ),
    );
  }

  Future<void> _finish(String id, List<_QueuedPhoto> photos) async {
    for (final p in photos) {
      _files.delete(p.path);
    }
    await _dao.remove(id);
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

  /// `30 s · 2^(n-1)`, capped at 30 min, plus up to 20% jitter (§4).
  DateTime _backoff(int attempts) {
    final seconds = min(30 * pow(2, max(0, attempts - 1)).toInt(), 1800);
    final jitter = (seconds * 0.2 * Random().nextDouble()).round();
    return _clock().add(Duration(seconds: seconds + jitter));
  }

  // ---------------------------------------------------------------------
  // Rep actions
  // ---------------------------------------------------------------------

  @override
  Stream<List<PendingDepotRegistration>> watchAll() =>
      _dao.watchAll().map((rows) => [for (final r in rows) _toEntity(r)]);

  @override
  Future<int> countUnsent() => _dao.count();

  @override
  Future<void> expedite() => _dao.clearBackoff({
        DepotRegistrationQueueStatus.queued.name,
        DepotRegistrationQueueStatus.photosPending.name,
      });

  @override
  Future<int> countSendable() => _dao.countIn({
        DepotRegistrationQueueStatus.queued.name,
        DepotRegistrationQueueStatus.sending.name,
        DepotRegistrationQueueStatus.photosPending.name,
        DepotRegistrationQueueStatus.uploadingPhotos.name,
      });

  @override
  ResultFuture<void> retry(String id) async {
    try {
      // Atomic, like a drain's claim: only a row still waiting for review
      // moves, so a double tap or a racing drain cannot requeue it twice.
      final moved = await _dao.claim(
        id,
        from: DepotRegistrationQueueStatus.needsReview.name,
        to: DepotRegistrationQueueStatus.queued.name,
        at: _clock(),
      );
      if (!moved) return const Success(null);
      await _dao.patch(
        id,
        const DepotRegistrationQueueCompanion(
          attempts: Value(0),
          nextAttemptAt: Value(null),
          lastMessage: Value(null),
        ),
      );
      _onEnqueued?.call();
      return const Success(null);
    } catch (e) {
      return Failed(CacheFailure(message: e.toString()));
    }
  }

  @override
  ResultFuture<void> discard(String id) async {
    try {
      final row = await _dao.byId(id);
      if (row == null) return const Success(null);
      // Never a row a drain holds right now: its files are being read.
      if (!await _dao.removeIfIn(id, discardable)) return const Success(null);
      _logger.info('depots.outbox.discarded', fields: {'status': row.status});
      for (final p in _QueuedPhoto.decode(row.attachments)) {
        _files.delete(p.path);
      }
      return const Success(null);
    } catch (e) {
      return Failed(CacheFailure(message: e.toString()));
    }
  }

  @override
  ResultFuture<void> reopenAsDraft(String id) async {
    try {
      final row = await _dao.byId(id);
      final raw = row?.draftJson;
      // Only a refusal goes back to the wizard. Reopening anything else —
      // above all a registered depot still uploading photos — would invite a
      // second submit of a shop SAP already holds.
      if (row == null ||
          raw == null ||
          DepotRegistrationQueueStatus.parse(row.status) !=
              DepotRegistrationQueueStatus.rejected) {
        return const Failed(CacheFailure(message: 'No saved form to reopen.'));
      }
      // The wizard holds one draft. Overwriting a form the rep is halfway
      // through would lose it, so they finish or clear that one first.
      if (await _draftCache.read() != null) {
        return const Failed(CacheFailure(message: draftInProgress));
      }
      final draft = BpDepotDraft.fromDraftJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      // Point the form at the kept copies: the originals were in a cache
      // directory and may be gone by now.
      final kinds = {
        for (final e in BpAttachment.kindToDocumentType.entries) e.value: e.key,
      };
      draft.attachments
        ..clear()
        ..addAll([
          for (final p in _QueuedPhoto.decode(row.attachments))
            if (kinds[p.type] != null)
              BpAttachment(
                kind: kinds[p.type]!,
                localPath: p.path,
                capturedAt: p.capturedAt,
              ),
        ]);
      // Row first, guarded: if it stopped being `rejected` meanwhile, nothing
      // is written to the wizard.
      if (!await _dao.removeIfIn(id, {
        DepotRegistrationQueueStatus.rejected.name,
      })) {
        return const Failed(CacheFailure(message: 'No saved form to reopen.'));
      }
      // The files now belong to the draft.
      await _draftCache.write(draft);
      return const Success(null);
    } catch (e) {
      return Failed(CacheFailure(message: e.toString()));
    }
  }

  PendingDepotRegistration _toEntity(DepotRegistrationQueueRow r) {
    if (DepotDraftOutboxRoute.owns(r.payload)) {
      final form = DepotDraftOutboxRoute.formOf(r.draftJson);
      final fix = form?.geoFix;
      return _entity(
        r,
        nameKh: form?.nameKh,
        phone: form?.mobilePhone.trim().nullIfEmpty ??
            form?.telephone.trim().nullIfEmpty,
        address: form == null
            ? null
            : [form.houseNumber.trim(), form.street.trim()]
                .where((p) => p.isNotEmpty)
                .join(' ')
                .nullIfEmpty,
        latitude: fix?.latitude,
        longitude: fix?.longitude,
      );
    }
    final request = _readRequest(r.payload);
    return _entity(
      r,
      nameKh: request?.name3,
      phone: (request?.mobilePhone.trim().nullIfEmpty ??
          request?.telephone.trim().nullIfEmpty),
      address: request == null
          ? null
          : [request.houseNo.trim(), request.street.trim()]
              .where((p) => p.isNotEmpty)
              .join(' ')
              .nullIfEmpty,
      latitude: double.tryParse(request?.latitude ?? ''),
      longitude: double.tryParse(request?.longitude ?? ''),
    );
  }

  PendingDepotRegistration _entity(
    DepotRegistrationQueueRow r, {
    String? nameKh,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
  }) {
    final status = switch (DepotRegistrationQueueStatus.parse(r.status)) {
      DepotRegistrationQueueStatus.sending =>
        DepotRegistrationQueueStatus.queued,
      DepotRegistrationQueueStatus.uploadingPhotos =>
        DepotRegistrationQueueStatus.photosPending,
      final s => s,
    };
    final photos = _QueuedPhoto.decode(r.attachments);
    return PendingDepotRegistration(
      id: r.id,
      depotName: r.depotName,
      status: status,
      createdAt: r.createdAt,
      photosOutstanding: photos.length,
      depotNumber: r.depotNumber,
      message: r.lastMessage,
      canReopen: r.draftJson != null,
      nextAttemptAt: r.nextAttemptAt,
      depotNameKh: nameKh?.trim().nullIfEmpty,
      phone: phone,
      address: address,
      latitude: latitude,
      longitude: longitude,
      attempts: r.attempts,
      lastAttemptAt: r.lastAttemptAt,
      photos: [
        for (final p in photos)
          PendingDepotPhoto(
              type: p.type, path: p.path, capturedAt: p.capturedAt),
      ],
    );
  }

  /// The stored request body, for display only. Tolerant: an unreadable body
  /// shows the row without its details rather than failing the whole list.
  static BusinessPartnerRequestModel? _readRequest(String payload) {
    try {
      final json = jsonDecode(payload);
      if (json is! Map) return null;
      return BusinessPartnerRequestModel.fromJson(
        Map<String, dynamic>.from(json),
      );
    } catch (_) {
      return null;
    }
  }

  static String _extension(String path) {
    final dot = path.lastIndexOf('.');
    final slash = path.lastIndexOf('/');
    return dot > slash && dot >= 0 ? path.substring(dot) : '.jpg';
  }
}

/// What one drain has done so far.
class _DrainRun {
  /// A registration has gone out, so the next waits [sendSpacing].
  bool sentAny = false;

  /// An earlier registration is still waiting; later ones must not overtake it.
  bool postsHeld = false;
}

/// One photograph a queued registration is still holding.
class _QueuedPhoto {
  const _QueuedPhoto(this.type, this.path, this.capturedAt);

  final DepotDocumentType type;
  final String path;
  final DateTime capturedAt;

  static String encode(List<_QueuedPhoto> photos) => jsonEncode([
        for (final p in photos)
          {
            'type': p.type.name,
            'path': p.path,
            'capturedAt': p.capturedAt.toIso8601String(),
          },
      ]);

  /// Tolerant: an unreadable entry is skipped rather than failing the row.
  static List<_QueuedPhoto> decode(String raw) {
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      final out = <_QueuedPhoto>[];
      for (final e in list.whereType<Map>()) {
        final type = DepotDocumentType.values
            .where((t) => t.name == e['type'])
            .firstOrNull;
        final path = e['path'];
        if (type == null || path is! String) continue;
        out.add(
          _QueuedPhoto(
            type,
            path,
            DateTime.tryParse('${e['capturedAt']}') ?? DateTime.now().toUtc(),
          ),
        );
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
