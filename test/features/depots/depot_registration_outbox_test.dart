import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/sync/background/sync_run_context.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/depots/data/local/bp_draft_cache.dart';
import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';
import 'package:steelforce/features/depots/data/models/business_partner_request_model.dart';
import 'package:steelforce/features/depots/data/repositories/depot_registration_outbox_impl.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_request.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_result.dart';
import 'package:steelforce/features/depots/domain/entities/depot_document.dart';
import 'package:steelforce/features/depots/domain/entities/pending_depot_registration.dart';
import 'package:steelforce/features/depots/domain/repositories/business_partner_repository.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_document_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockRegistrations extends Mock implements BusinessPartnerRepository {}

class _MockDocuments extends Mock implements DepotDocumentRepository {}

class _MockDraftCache extends Mock implements BpDraftCache {}

class _MockLogger extends Mock implements AppLogger {}

/// Records copies and deletes instead of touching the filesystem.
class _FakeFiles extends QueuedPhotoFiles {
  final kept = <String>[];
  final deleted = <String>[];

  @override
  Future<String> keep(String sourcePath, {required String fileName}) async {
    final path = '/kept/$fileName';
    kept.add(path);
    return path;
  }

  @override
  void delete(String path) => deleted.add(path);
}

BusinessPartnerRequest _request({String name = 'Toul Kork Yard'}) =>
    BusinessPartnerRequestModel.fromJson({
      'Name1': name,
      'SalesOrg': '0002',
      'DistributionChannel': '10',
      'Division': '10',
      'Country': 'KH',
      'PersonnelNumber': '1001',
    });

const _accepted = BusinessPartnerResult(
  localId: 'depot-1',
  status: BpSubmissionStatus.pendingHq,
);

PendingDepotDocument _photo(DepotDocumentType type) => PendingDepotDocument(
      type: type,
      filePath: '/cache/${type.name}.jpg',
      capturedAt: DateTime.utc(2026, 10, 1, 9),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_request());
    registerFallbackValue(BpDepotDraft());
  });

  late AppDatabase db;
  late _MockRegistrations registrations;
  late _MockDocuments documents;
  late _MockDraftCache draftCache;
  late _FakeFiles files;
  late DateTime now;
  late int wakeUps;
  late List<Duration> pauses;
  late DepotRegistrationOutboxImpl outbox;

  DepotRegistrationOutboxImpl build() => DepotRegistrationOutboxImpl(
        dao: db.depotRegistrationQueueDao,
        registrations: registrations,
        documents: documents,
        draftCache: draftCache,
        logger: _MockLogger(),
        files: files,
        onEnqueued: () => wakeUps++,
        clock: () => now,
        pause: (d) async => pauses.add(d),
      );

  void sendAnswers(Result<BusinessPartnerResult> answer) =>
      when(() => registrations.createBusinessPartner(any()))
          .thenAnswer((_) async => answer);

  Future<List<DepotRegistrationQueueRow>> rows() =>
      db.depotRegistrationQueueDao.all();

  Future<String> enqueue({
    List<PendingDepotDocument> photos = const [],
    bool mayHaveLanded = false,
    BpDepotDraft? draft,
    String name = 'Toul Kork Yard',
  }) async {
    final result = await outbox.enqueue(
      request: _request(name: name),
      depotName: name,
      photos: photos,
      mayHaveLanded: mayHaveLanded,
      draftSnapshot: draft,
    );
    return result.when(success: (id) => id, failure: (f) => fail('$f'));
  }

  Future<void> markRejected(String id) => db.depotRegistrationQueueDao.patch(
      id, const DepotRegistrationQueueCompanion(status: Value('rejected')));

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    registrations = _MockRegistrations();
    documents = _MockDocuments();
    draftCache = _MockDraftCache();
    files = _FakeFiles();
    now = DateTime.utc(2026, 10, 2, 8);
    wakeUps = 0;
    pauses = [];
    outbox = build();
  });

  tearDown(() => db.close());

  group('enqueue', () {
    test('stores the exact payload, keeps the photos, wakes the engine',
        () async {
      await enqueue(photos: [_photo(DepotDocumentType.storefront)]);

      final row = (await rows()).single;
      expect(row.status, 'queued');
      expect(row.payload, contains('"Name1":"Toul Kork Yard"'));
      expect(row.attachments, contains('/kept/'));
      expect(files.kept, hasLength(1));
      expect(wakeUps, 1);
      expect(await outbox.countUnsent(), 1);
    });

    test('an ambiguous failure goes straight to review, not the queue',
        () async {
      await enqueue(mayHaveLanded: true);

      expect((await rows()).single.status, 'needsReview');
      expect(wakeUps, 0, reason: 'nothing to send automatically');
    });

    test('the Sync Center reads back what the rep submitted', () async {
      await outbox.enqueue(
        request: BusinessPartnerRequestModel.fromJson({
          'Name1': 'Toul Kork Yard',
          'Name3': 'ឃ្លាំងទួលគោក',
          'MobilePhone': '012345678',
          'Telephone': '023111222',
          'HouseNo': '12',
          'Street': 'St 271',
          'Latitude': '11.5564',
          'Longitude': '104.9282',
        }),
        depotName: 'Toul Kork Yard',
        photos: [_photo(DepotDocumentType.storefront)],
      );

      final item = (await outbox.watchAll().first).single;
      expect(item.depotNameKh, 'ឃ្លាំងទួលគោក');
      expect(item.phone, '012345678', reason: 'mobile before landline');
      expect(item.address, '12 St 271');
      expect(item.latitude, closeTo(11.5564, 1e-9));
      expect(item.longitude, closeTo(104.9282, 1e-9));
      expect(item.photosOutstanding, 1);
      expect(item.attempts, 0);
    });

    // Rows already on reps' phones are read back by later versions, so the
    // stored photo column is pinned exactly.
    test('the photo column is stored in its pinned format', () async {
      final id = await enqueue(photos: [
        _photo(DepotDocumentType.storefront),
        PendingDepotDocument(
          type: DepotDocumentType.values.last,
          filePath: '/cache/no_extension',
          capturedAt: DateTime.utc(2026, 10, 1, 10),
        ),
      ]);

      final last = DepotDocumentType.values.last.name;
      expect(
        (await rows()).single.attachments,
        '[{"type":"storefront","path":"/kept/${id}_storefront.jpg",'
        '"capturedAt":"2026-10-01T09:00:00.000Z"},'
        '{"type":"$last","path":"/kept/${id}_$last.jpg",'
        '"capturedAt":"2026-10-01T10:00:00.000Z"}]',
      );
    });

    test('an older or damaged photo column skips only the bad entries',
        () async {
      final id = await enqueue();
      Future<void> storeAttachments(String raw) => db.depotRegistrationQueueDao
          .patch(id, DepotRegistrationQueueCompanion(attachments: Value(raw)));

      await storeAttachments(
        '[{"type":"storefront","path":"/a.jpg","capturedAt":"bad"},'
        '{"type":"no_such_type","path":"/b.jpg"},'
        '{"type":"storefront"},'
        '"not a map"]',
      );
      expect((await outbox.watchAll().first).single.photosOutstanding, 1);

      await storeAttachments('not json');
      expect((await outbox.watchAll().first).single.photosOutstanding, 0);
    });

    test('an unreadable stored body still lists the row, without details',
        () async {
      final id = await enqueue();
      await db.customStatement(
        'UPDATE depot_registration_queue SET payload = ? WHERE id = ?',
        ['not json', id],
      );

      final item = (await outbox.watchAll().first).single;
      expect(item.depotName, 'Toul Kork Yard');
      expect(item.phone, isNull);
      expect(item.address, isNull);
      expect(item.latitude, isNull);
    });
  });

  group('drain', () {
    test('a registration with no photos is removed once accepted', () async {
      sendAnswers(const Success(_accepted));
      await enqueue();

      await outbox.drain();

      expect(await rows(), isEmpty);
      verify(() => registrations.createBusinessPartner(any())).called(1);
    });

    test('photos upload against the returned depot id, then the row goes',
        () async {
      sendAnswers(const Success(_accepted));
      when(() => documents.uploadAll(
                depotId: any(named: 'depotId'),
                documents: any(named: 'documents'),
                onProgress: any(named: 'onProgress'),
              ))
          .thenAnswer((_) async => const Success(DepotDocumentUploadOutcome(
              uploaded: [DepotDocumentType.storefront])));
      await enqueue(photos: [_photo(DepotDocumentType.storefront)]);

      await outbox.drain();

      expect(await rows(), isEmpty);
      verify(() => documents.uploadAll(
            depotId: 'depot-1',
            documents: any(named: 'documents'),
            onProgress: any(named: 'onProgress'),
          )).called(1);
      expect(files.deleted, files.kept);
    });

    test('a failed photo stays queued, and only it is resent later', () async {
      sendAnswers(const Success(_accepted));
      final uploads = <List<DepotDocumentType>>[];
      when(() => documents.uploadAll(
            depotId: any(named: 'depotId'),
            documents: any(named: 'documents'),
            onProgress: any(named: 'onProgress'),
          )).thenAnswer((inv) async {
        final docs =
            inv.namedArguments[#documents] as List<PendingDepotDocument>;
        uploads.add([for (final d in docs) d.type]);
        return Success(uploads.length == 1
            ? const DepotDocumentUploadOutcome(
                uploaded: [DepotDocumentType.storefront],
                failed: [DepotDocumentType.idCard])
            : const DepotDocumentUploadOutcome(
                uploaded: [DepotDocumentType.idCard]));
      });
      await enqueue(photos: [
        _photo(DepotDocumentType.storefront),
        _photo(DepotDocumentType.idCard),
      ]);

      await outbox.drain();
      final row = (await rows()).single;
      expect(row.status, 'photosPending');
      expect(row.nextAttemptAt!.isAfter(now), isTrue);

      // Not due yet: nothing happens.
      await outbox.drain();
      expect(uploads, hasLength(1));

      now = now.add(const Duration(hours: 1));
      await outbox.drain();
      expect(uploads.last, [DepotDocumentType.idCard]);
      expect(await rows(), isEmpty);
      // The registration itself was sent exactly once.
      verify(() => registrations.createBusinessPartner(any())).called(1);
    });

    test('offline: stays queued and stops the drain', () async {
      sendAnswers(const Failed(NetworkFailure()));
      await enqueue();
      await enqueue();

      await outbox.drain();

      expect((await rows()).map((r) => r.status), ['queued', 'queued']);
      verify(() => registrations.createBusinessPartner(any())).called(1);
    });

    test('an expired session stays queued for after sign-in', () async {
      sendAnswers(const Failed(AuthenticationFailure(message: 'expired')));
      await enqueue();

      await outbox.drain();

      expect((await rows()).single.status, 'queued');
    });

    test('a 504 goes to review and is never resent automatically', () async {
      sendAnswers(
          const Failed(ServerFailure(message: 'timeout', statusCode: 504)));
      await enqueue();

      await outbox.drain();
      expect((await rows()).single.status, 'needsReview');

      now = now.add(const Duration(days: 1));
      await outbox.drain();
      verify(() => registrations.createBusinessPartner(any())).called(1);
    });

    test('a gateway 5xx backs off, then goes to review at the cap', () async {
      sendAnswers(
          const Failed(ServerFailure(message: 'bad gw', statusCode: 502)));
      await enqueue();

      await outbox.drain();
      var row = (await rows()).single;
      expect(row.status, 'queued');
      expect(row.nextAttemptAt!.isAfter(now), isTrue);

      // Before it is due: not resent.
      await outbox.drain();
      verify(() => registrations.createBusinessPartner(any())).called(1);

      for (var i = 1; i < DepotRegistrationOutboxImpl.maxGatewayAttempts; i++) {
        now = now.add(const Duration(hours: 1));
        await outbox.drain();
      }
      row = (await rows()).single;
      expect(row.status, 'needsReview');
      expect(row.attempts, DepotRegistrationOutboxImpl.maxGatewayAttempts - 1);
    });

    test('a 500 may have landed: review, never auto-resent', () async {
      sendAnswers(const Failed(
          ServerFailure(message: 'Internal error', statusCode: 500)));
      await enqueue();

      await outbox.drain();
      expect((await rows()).single.status, 'needsReview');

      now = now.add(const Duration(days: 1));
      await outbox.drain();
      verify(() => registrations.createBusinessPartner(any())).called(1);
    });

    test('a 503 is the gateway refusing it: resent with backoff', () async {
      sendAnswers(
          const Failed(ServerFailure(message: 'busy', statusCode: 503)));
      await enqueue();

      await outbox.drain();

      final row = (await rows()).single;
      expect(row.status, 'queued');
      expect(row.nextAttemptAt!.isAfter(now), isTrue);
    });

    test('a short-budget run does not start a registration', () async {
      sendAnswers(const Success(_accepted));
      await enqueue();

      await SyncRunContext.withBudget(
          const Duration(seconds: 25), () => outbox.drain());

      expect((await rows()).single.status, 'queued');
      verifyNever(() => registrations.createBusinessPartner(any()));

      // A run with time sends it.
      await SyncRunContext.withBudget(
          const Duration(minutes: 8), () => outbox.drain());
      expect(await rows(), isEmpty);
    });

    test('photos that never go up are given up on, not held forever', () async {
      sendAnswers(const Success(_accepted));
      when(() => documents.uploadAll(
                depotId: any(named: 'depotId'),
                documents: any(named: 'documents'),
                onProgress: any(named: 'onProgress'),
              ))
          .thenAnswer((_) async => const Success(DepotDocumentUploadOutcome(
              failed: [DepotDocumentType.storefront])));
      await enqueue(photos: [_photo(DepotDocumentType.storefront)]);

      for (var i = 0; i < DepotRegistrationOutboxImpl.maxPhotoAttempts; i++) {
        await outbox.drain();
        now = now.add(const Duration(hours: 2));
      }

      expect(await rows(), isEmpty);
      expect(await outbox.countUnsent(), 0, reason: 'sign-out is free again');
      verify(() => registrations.createBusinessPartner(any())).called(1);
    });

    test('an upload that throws still records a round', () async {
      sendAnswers(const Success(_accepted));
      when(() => documents.uploadAll(
            depotId: any(named: 'depotId'),
            documents: any(named: 'documents'),
            onProgress: any(named: 'onProgress'),
          )).thenThrow(UnsupportedError('no files on web'));
      await enqueue(photos: [_photo(DepotDocumentType.storefront)]);

      await outbox.drain();

      final row = (await rows()).single;
      expect(row.status, 'photosPending', reason: 'not stranded mid-upload');
      expect(row.attempts, 1);
    });

    test('rows waiting on the rep are not counted as sendable', () async {
      await enqueue();
      await enqueue(mayHaveLanded: true);

      expect(await outbox.countUnsent(), 2);
      expect(await outbox.countSendable(), 1);
    });

    test('a SAP refusal is kept with SAP\'s own wording', () async {
      sendAnswers(const Failed(ServerFailure(
          message: 'Payment term T015 not defined', statusCode: 422)));
      await enqueue();

      await outbox.drain();

      final row = (await rows()).single;
      expect(row.status, 'rejected');
      expect(row.lastMessage, 'Payment term T015 not defined');
    });

    test('a row stranded mid-send by a dead process goes to review', () async {
      await enqueue();
      final id = (await rows()).single.id;
      await db.depotRegistrationQueueDao.patch(
          id,
          DepotRegistrationQueueCompanion(
            status: const Value('sending'),
            lastAttemptAt: Value(now.subtract(const Duration(minutes: 10))),
          ));

      await outbox.drain();

      expect((await rows()).single.status, 'needsReview');
      verifyNever(() => registrations.createBusinessPartner(any()));
    });

    test('a row another drain is sending right now is left alone', () async {
      await enqueue();
      final id = (await rows()).single.id;
      await db.depotRegistrationQueueDao.patch(
          id,
          DepotRegistrationQueueCompanion(
            status: const Value('sending'),
            lastAttemptAt: Value(now.subtract(const Duration(seconds: 20))),
          ));

      await outbox.drain();

      expect((await rows()).single.status, 'sending');
    });

    test('two drains at once send a registration exactly once', () async {
      final gate = Completer<void>();
      when(() => registrations.createBusinessPartner(any()))
          .thenAnswer((_) async {
        await gate.future;
        return const Success(_accepted);
      });
      await enqueue();

      // Separate instances, as the foreground engine and the background
      // worker would be: the in-memory guard cannot help, only the claim.
      final other = build();
      final a = outbox.drain();
      final b = other.drain();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gate.complete();
      await Future.wait([a, b]);

      verify(() => registrations.createBusinessPartner(any())).called(1);
      expect(await rows(), isEmpty);
    });
  });

  group('several queued registrations', () {
    /// Queues one registration per name, a minute apart, as a rep working
    /// offline through the day would.
    Future<List<String>> queueInOrder(List<String> names) async {
      final ids = <String>[];
      for (final name in names) {
        ids.add(await enqueue(name: name));
        now = now.add(const Duration(minutes: 1));
      }
      return ids;
    }

    List<String> sentNames() => [
          for (final r
              in verify(() => registrations.createBusinessPartner(captureAny()))
                  .captured)
            (r as BusinessPartnerRequest).name1,
        ];

    test('go oldest first, one at a time, with a gap between them', () async {
      sendAnswers(const Success(_accepted));
      await queueInOrder(['A', 'B', 'C']);

      await outbox.drain();

      expect(sentNames(), ['A', 'B', 'C']);
      expect(pauses, [
        DepotRegistrationOutboxImpl.defaultSendSpacing,
        DepotRegistrationOutboxImpl.defaultSendSpacing,
      ]);
      expect(await rows(), isEmpty);
    });

    test('a single registration is sent without waiting', () async {
      sendAnswers(const Success(_accepted));
      await enqueue();

      await outbox.drain();

      expect(pauses, isEmpty);
      expect(await rows(), isEmpty);
    });

    test('a busy gateway stops the drain instead of taking the next one',
        () async {
      sendAnswers(
          const Failed(ServerFailure(message: 'busy', statusCode: 503)));
      await queueInOrder(['A', 'B', 'C']);

      await outbox.drain();

      expect(sentNames(), ['A']);
      expect(
          (await rows()).map((r) => r.status), ['queued', 'queued', 'queued']);
    });

    test('later registrations do not overtake one that is backing off',
        () async {
      final ids = await queueInOrder(['A', 'B']);
      await db.depotRegistrationQueueDao.patch(
          ids.first,
          DepotRegistrationQueueCompanion(
            attempts: const Value(1),
            nextAttemptAt: Value(now.add(const Duration(minutes: 5))),
          ));
      sendAnswers(const Success(_accepted));

      await outbox.drain();
      verifyNever(() => registrations.createBusinessPartner(any()));

      // Once A is due, both go — A first.
      now = now.add(const Duration(minutes: 6));
      await outbox.drain();
      expect(sentNames(), ['A', 'B']);
    });

    test('a registration another drain is sending holds the ones behind it',
        () async {
      final ids = await queueInOrder(['A', 'B']);
      await db.depotRegistrationQueueDao.patch(
          ids.first,
          DepotRegistrationQueueCompanion(
            status: const Value('sending'),
            lastAttemptAt: Value(now.subtract(const Duration(seconds: 10))),
          ));
      sendAnswers(const Success(_accepted));

      await outbox.drain();

      verifyNever(() => registrations.createBusinessPartner(any()));
      expect((await rows()).last.status, 'queued');
    });

    test('rows waiting on the rep do not hold the line', () async {
      final ids = await queueInOrder(['A', 'B', 'C']);
      await db.depotRegistrationQueueDao.patch(ids[0],
          const DepotRegistrationQueueCompanion(status: Value('needsReview')));
      await markRejected(ids[1]);
      sendAnswers(const Success(_accepted));

      await outbox.drain();

      expect(sentNames(), ['C']);
      expect(pauses, isEmpty);
    });

    test('a refusal does not stop the ones behind it', () async {
      var call = 0;
      when(() => registrations.createBusinessPartner(any())).thenAnswer(
          (_) async => call++ == 0
              ? const Failed(
                  ServerFailure(message: 'term not defined', statusCode: 400))
              : const Success(_accepted));
      await queueInOrder(['A', 'B']);

      await outbox.drain();

      expect(sentNames(), ['A', 'B']);
      expect((await rows()).single.status, 'rejected');
    });

    test('a background run stops before a send it has no time left for',
        () async {
      sendAnswers(const Success(_accepted));
      await queueInOrder(['A', 'B']);

      // Enough for one request, not for the gap and a second one.
      await SyncRunContext.withBudget(
        SyncRunContext.longestRequest + const Duration(seconds: 1),
        () => outbox.drain(),
      );

      expect(sentNames(), ['A']);
      expect((await rows()).single.depotName, 'B');
    });
  });

  group('rep actions', () {
    test('retry returns a reviewed row to the queue', () async {
      final id = await enqueue(mayHaveLanded: true);

      await outbox.retry(id);

      final row = (await rows()).single;
      expect(row.status, 'queued');
      expect(row.attempts, 0);
      expect(wakeUps, 1);
    });

    test('retry does nothing to a SAP refusal', () async {
      sendAnswers(const Failed(ServerFailure(message: 'no', statusCode: 422)));
      final id = await enqueue();
      await outbox.drain();

      await outbox.retry(id);

      expect((await rows()).single.status, 'rejected');
    });

    test('discard leaves a row a drain is sending alone', () async {
      final id = await enqueue();
      await db.depotRegistrationQueueDao.patch(
          id, const DepotRegistrationQueueCompanion(status: Value('sending')));

      await outbox.discard(id);

      expect(await rows(), hasLength(1));
    });

    test('a registered depot cannot be reopened for a second submit', () async {
      when(() => draftCache.read()).thenAnswer((_) async => null);
      final id = await enqueue(draft: BpDepotDraft());
      await db.depotRegistrationQueueDao.patch(
          id,
          const DepotRegistrationQueueCompanion(
              status: Value('photosPending')));

      final result = await outbox.reopenAsDraft(id);

      expect(result, isA<Failed<void>>());
      expect(await rows(), hasLength(1));
      verifyNever(() => draftCache.write(any()));
    });

    test('discard removes the row and its photos', () async {
      final id = await enqueue(photos: [_photo(DepotDocumentType.idCard)]);

      await outbox.discard(id);

      expect(await rows(), isEmpty);
      expect(files.deleted, files.kept);
    });

    test('reopen restores the form with the kept photos', () async {
      when(() => draftCache.read()).thenAnswer((_) async => null);
      when(() => draftCache.write(any())).thenAnswer((_) async {});
      final draft = BpDepotDraft()..nameEn = 'Toul Kork Yard';
      final id = await enqueue(
        photos: [_photo(DepotDocumentType.storefront)],
        draft: draft,
      );
      await markRejected(id);

      final result = await outbox.reopenAsDraft(id);

      expect(result, isA<Success<void>>());
      final written = verify(() => draftCache.write(captureAny()))
          .captured
          .single as BpDepotDraft;
      expect(written.nameEn, 'Toul Kork Yard');
      expect(written.attachments.single.kind, 'outlet_front');
      expect(written.attachments.single.localPath, startsWith('/kept/'));
      expect(await rows(), isEmpty);
      expect(files.deleted, isEmpty, reason: 'the draft owns the photos now');
    });

    test('reopen refuses to overwrite a form already in progress', () async {
      when(() => draftCache.read()).thenAnswer((_) async => BpDepotDraft());
      final id = await enqueue(draft: BpDepotDraft());
      await markRejected(id);

      final result = await outbox.reopenAsDraft(id);

      expect(
        result.when(success: (_) => null, failure: (f) => f.message),
        DepotRegistrationOutboxImpl.draftInProgress,
      );
      expect(await rows(), hasLength(1));
      verifyNever(() => draftCache.write(any()));
    });

    test('the Sync Center sees in-flight states as their resting state',
        () async {
      await enqueue();
      final id = (await rows()).single.id;
      await db.depotRegistrationQueueDao.patch(
          id, const DepotRegistrationQueueCompanion(status: Value('sending')));

      final items = await outbox.watchAll().first;

      expect(items.single.status, DepotRegistrationQueueStatus.queued);
    });
  });
}
