import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/hive/local_cache.dart';
import 'package:steelforce/features/depots/data/datasources/business_partner_remote_data_source.dart';
import 'package:steelforce/features/depots/data/local/bp_draft_cache.dart';
import 'package:steelforce/features/depots/data/local/depot_reference_cache.dart';
import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';
import 'package:steelforce/features/depots/data/remote/depot_datasources.dart'
    as legacy;
import 'package:steelforce/features/depots/data/repositories/business_partner_repository_impl.dart';

/// Opening the "add depot" form must resume the rep's unfinished
/// registration rather than starting a new one.
///
/// Why this matters: the form is five steps long and is filled in standing at a
/// shop counter. A rep who backs out, loses signal or has the handset killed
/// must find their typing where they left it.
///
/// This used to run over the server-draft protocol — `POST /draft` for an id,
/// then `openDraft()` probing `/draft/active`. That protocol is gone, and with
/// it the reason these tests drove a real Dio stack. Resume is now local
/// (`loadDraft`), which is where it belonged: the form has to open with no
/// signal at all, and the rep who filled a form in is the rep who finishes it.
///
/// The real [BpDraftCache] is exercised over an in-memory store rather than
/// mocked, because the encode/decode round trip and the discard-on-corruption
/// behaviour are the whole point of these tests.
class _MemoryCache extends Fake implements LocalCache {
  final Map<String, Object?> store = {};

  @override
  T? get<T>(String key) => store[key] as T?;

  @override
  Future<void> set(String key, Object? value, {Duration? ttl}) async {
    store[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    store.remove(key);
  }
}

/// Registration writes and reference loads are untouched by a resume; `Fake`
/// throws loudly if that ever stops being true.
class _UnusedBpRemote extends Fake implements BusinessPartnerRemoteDataSource {}

class _UnusedReferences extends Fake implements legacy.DepotRemoteDataSource {}

class _UnusedReferenceCache extends Fake implements DepotReferenceCache {}

void main() {
  late _MemoryCache store;
  late BusinessPartnerRepositoryImpl repository;

  const key = 'bp_registration_draft';

  setUp(() {
    store = _MemoryCache();
    repository = BusinessPartnerRepositoryImpl(
      remote: _UnusedBpRemote(),
      references: _UnusedReferences(),
      referenceCache: _UnusedReferenceCache(),
      draftCache: BpDraftCache(store),
    );
  });

  /// A half-filled form: the rep got through identity and address and stopped.
  BpDepotDraft halfFilled() => BpDepotDraft(
        nameEn: 'Sok Heng Hardware',
        nameKh: 'ហាង សុខ ហេង',
        cityCode: '12',
        districtCode: '1204',
        mobilePhone: '012345678',
        depotGroup: '02',
      );

  group('an unfinished form is resumed', () {
    test('the saved field values come back so each step can prefill', () async {
      await repository.saveDraft(halfFilled());

      final resumed = await repository.loadDraft();

      expect(resumed, isNotNull);
      expect(resumed!.nameEn, 'Sok Heng Hardware');
      expect(resumed.nameKh, 'ហាង សុខ ហេង');
      expect(resumed.districtCode, '1204');
      expect(resumed.depotGroup, '02');
      expect(resumed.mobilePhone, '012345678');
    });

    test('the latest save wins, so resuming never rewinds the rep', () async {
      await repository.saveDraft(halfFilled());
      await repository.saveDraft(halfFilled()..nameEn = 'Sok Heng Steel');

      expect((await repository.loadDraft())!.nameEn, 'Sok Heng Steel');
    });
  });

  group('no draft open', () {
    test('nothing saved means a blank form, not a failure', () async {
      expect(await repository.loadDraft(), isNull);
    });

    test('an empty entry also means "none"', () async {
      store.store[key] = '';

      expect(await repository.loadDraft(), isNull);
    });
  });

  group('an unreadable draft degrades to a blank form', () {
    // A draft written by an older build can be structurally unreadable. It has
    // to be discarded rather than thrown: a decode error on open would be a
    // crash loop the rep has no way out of, since nothing in the UI resets it.
    test('a corrupt entry returns null and is cleared', () async {
      store.store[key] = 'not json at all';

      expect(await repository.loadDraft(), isNull);
      expect(store.store.containsKey(key), isFalse,
          reason: 'leaving it in place would fail every subsequent open '
              'the same way');
    });

    test('a well-formed but non-map entry is discarded too', () async {
      store.store[key] = jsonEncode([1, 2, 3]);

      expect(await repository.loadDraft(), isNull);
      expect(store.store.containsKey(key), isFalse);
    });
  });

  group('the draft is cleared only once the registration is accepted', () {
    test('clearDraft leaves the next open blank', () async {
      await repository.saveDraft(halfFilled());
      expect(await repository.loadDraft(), isNotNull);

      await repository.clearDraft();

      expect(await repository.loadDraft(), isNull);
    });
  });
}
