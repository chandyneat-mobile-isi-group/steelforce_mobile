import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/daos/depot_registration_queue_dao.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/core/utils/uuid.dart';
import 'package:steelforce/features/depots/data/local/bp_draft_cache.dart';
import 'package:steelforce/features/depots/data/local/queued_photo_files.dart';
import 'package:steelforce/features/depots/data/mappers/bp_draft_json_mapper.dart';
import 'package:steelforce/features/depots/data/mappers/pending_depot_registration_mapper.dart';
import 'package:steelforce/features/depots/data/models/business_partner_request_model.dart';
import 'package:steelforce/features/depots/data/models/queued_photo.dart';
import 'package:steelforce/features/depots/data/repositories/outbox/queued_photo_uploader.dart';
import 'package:steelforce/features/depots/data/repositories/outbox/registration_drain.dart';
import 'package:steelforce/features/depots/data/repositories/outbox/registration_send_policy.dart';
import 'package:steelforce/features/depots/domain/entities/bp_attachment.dart';
import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_request.dart';
import 'package:steelforce/features/depots/domain/entities/pending_depot_registration.dart';
import 'package:steelforce/features/depots/domain/repositories/business_partner_repository.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_document_repository.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_registration_outbox.dart';

// Kept importable from here: tests and DI substitute it through this file.
export 'package:steelforce/features/depots/data/local/queued_photo_files.dart';

/// Drift-backed [DepotRegistrationOutbox]. See the interface for the policy.
///
/// This class takes registrations in and serves the rep's actions on them.
/// Sending is [RegistrationDrain]; photographs are [QueuedPhotoUploader]; the
/// retry rules are [RegistrationSendPolicy].
class DepotRegistrationOutboxImpl implements DepotRegistrationOutbox {
  DepotRegistrationOutboxImpl({
    required DepotRegistrationQueueDao dao,
    required BusinessPartnerRepository registrations,
    required DepotDocumentRepository documents,
    required BpDraftCache draftCache,
    required AppLogger logger,
    QueuedPhotoFiles files = const QueuedPhotoFiles(),
    void Function()? onEnqueued,
    DateTime Function()? clock,
    this.sendSpacing = defaultSendSpacing,
    Future<void> Function(Duration)? pause,
  })  : _dao = dao,
        _registrations = registrations,
        _documents = documents,
        _draftCache = draftCache,
        _logger = logger,
        _files = files,
        _onEnqueued = onEnqueued,
        _clock = clock ?? (() => DateTime.now().toUtc()),
        _pause = pause ?? ((d) => Future<void>.delayed(d));

  final DepotRegistrationQueueDao _dao;
  final BusinessPartnerRepository _registrations;
  final DepotDocumentRepository _documents;
  final BpDraftCache _draftCache;
  final AppLogger _logger;
  final QueuedPhotoFiles _files;

  /// Tells the sync engine there is something to send. A callback because the
  /// engine lives in `core/sync` and is wired in DI.
  final void Function()? _onEnqueued;
  final DateTime Function() _clock;
  final Future<void> Function(Duration) _pause;

  late final RegistrationDrain _drain = RegistrationDrain(
    dao: _dao,
    registrations: _registrations,
    photos: QueuedPhotoUploader(
      dao: _dao,
      documents: _documents,
      files: _files,
      logger: _logger,
      clock: _clock,
    ),
    logger: _logger,
    clock: _clock,
    pause: _pause,
    sendSpacing: sendSpacing,
  );

  /// The gap left between two registrations in one drain.
  ///
  /// A rep who registered a day's worth of shops offline reconnects with all
  /// of them queued. Each one is a synchronous SAP write, so they go one at a
  /// time, oldest first, with this breathing space between them rather than
  /// as a burst the gateway answers with 503s.
  final Duration sendSpacing;
  static const Duration defaultSendSpacing = Duration(seconds: 2);

  // The limits live with the policy; repeated here so callers keep one name.
  static const int maxGatewayAttempts =
      RegistrationSendPolicy.maxGatewayAttempts;
  static const int maxPhotoAttempts = RegistrationSendPolicy.maxPhotoAttempts;
  static const Duration staleClaim = RegistrationSendPolicy.staleClaim;
  static const Duration staleUploadClaim =
      RegistrationSendPolicy.staleUploadClaim;
  static const String reasonOffline = RegistrationSendPolicy.reasonOffline;
  static const String reasonSignedOut = RegistrationSendPolicy.reasonSignedOut;
  static const String reasonServerBusy =
      RegistrationSendPolicy.reasonServerBusy;

  /// States the rep may discard from: everything except a row a drain has
  /// claimed and is using.
  static final Set<String> discardable = {
    DepotRegistrationQueueStatus.queued.name,
    DepotRegistrationQueueStatus.photosPending.name,
    DepotRegistrationQueueStatus.needsReview.name,
    DepotRegistrationQueueStatus.rejected.name,
  };

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
    BpDepotDraft? draftSnapshot,
  }) async {
    // Encoded before the first await: the wizard's draft is mutable, and the
    // snapshot must be the form as it was when the rep submitted.
    final draftJson =
        draftSnapshot == null ? null : jsonEncode(bpDraftToJson(draftSnapshot));
    final id = Uuid.v4();
    try {
      final kept = <QueuedPhoto>[];
      for (final photo in photos) {
        try {
          final path = await _files.keep(
            photo.filePath,
            fileName:
                '${id}_${photo.type.name}${QueuedPhoto.extensionOf(photo.filePath)}',
          );
          kept.add(QueuedPhoto(photo.type, path, photo.capturedAt));
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
          payload: jsonEncode(
            BusinessPartnerRequestModel.fromEntity(request).toJson(),
          ),
          draftJson: Value(draftJson),
          attachments: Value(QueuedPhoto.encode(kept)),
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

  @override
  Future<void> drain() => _drain.run();

  // ---------------------------------------------------------------------
  // Rep actions
  // ---------------------------------------------------------------------

  @override
  Stream<List<PendingDepotRegistration>> watchAll() => _dao
      .watchAll()
      .map((rows) => [for (final r in rows) pendingRegistrationFromRow(r)]);

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
      for (final p in QueuedPhoto.decode(row.attachments)) {
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
      final draft = bpDraftFromJson(
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
          for (final p in QueuedPhoto.decode(row.attachments))
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
}
