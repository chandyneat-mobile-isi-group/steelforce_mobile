import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:steelforce/features/depots/data/mappers/bp_draft_json_mapper.dart';
import 'package:steelforce/core/database/hive/local_cache.dart';
import 'package:steelforce/features/depots/data/local/bp_draft_cache.dart';
import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';

/// The registration draft holds customer PII, so it lives in an AES-encrypted
/// Hive box, and a plaintext copy left by an older build is moved across and
/// erased.
///
/// Real Hive boxes on a temp directory rather than fakes: "the bytes on disk
/// are not readable" is the property under test, and only a real box can
/// show it.
const _key = 'bp_registration_draft';

void main() {
  late Directory dir;
  late Box<dynamic> secure;
  late Box<dynamic> plain;
  late BpDraftCache cache;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('bp_draft_cache_test');
    Hive.init(dir.path);
    secure = await Hive.openBox<dynamic>(
      'secure',
      encryptionCipher: HiveAesCipher(Hive.generateSecureKey()),
    );
    plain = await Hive.openBox<dynamic>('plain');
    cache = BpDraftCache(
      LocalCache(secure),
      legacyPlaintext: LocalCache(plain),
    );
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  BpDepotDraft draft() => BpDepotDraft(
        nameEn: 'Sok Heng Hardware',
        mobilePhone: '012345678',
      );

  /// Writes a draft the way an older build did — to the plain box.
  Future<void> seedLegacy(BpDepotDraft d) =>
      LocalCache(plain).set(_key, jsonEncode(bpDraftToJson(d)));

  bool fileContains(String boxName, String needle) {
    final file = File('${dir.path}/$boxName.hive');
    final bytes = file.readAsBytesSync();
    return latin1.decode(bytes, allowInvalid: true).contains(needle);
  }

  test('a written draft round-trips from the encrypted box', () async {
    await cache.write(draft());

    final back = await cache.read();
    expect(back?.nameEn, 'Sok Heng Hardware');
    expect(back?.mobilePhone, '012345678');
    expect(cache.hasDraft, isTrue);
  });

  test('a written draft never touches the plaintext box', () async {
    await cache.write(draft());

    expect(plain.containsKey(_key), isFalse);
    expect(secure.containsKey(_key), isTrue);
  });

  test('PII is not readable in the encrypted box file', () async {
    await cache.write(draft());
    await secure.flush();

    expect(fileContains('secure', 'Sok Heng'), isFalse);
    expect(fileContains('secure', '012345678'), isFalse);
  });

  test('sanity: the same PII IS readable in a plain box file', () async {
    // Proves the check above can fail — otherwise it would prove nothing.
    await seedLegacy(draft());
    await plain.flush();

    expect(fileContains('plain', 'Sok Heng'), isTrue);
  });

  group('migrating a plaintext draft from an older build', () {
    test('moves it into the encrypted box and erases the plaintext copy',
        () async {
      await seedLegacy(draft());

      await cache.migrateLegacyPlaintext();

      expect(plain.containsKey(_key), isFalse);
      expect((await cache.read())?.nameEn, 'Sok Heng Hardware');
    });

    test('read() migrates on its own, so nothing is served from plaintext',
        () async {
      await seedLegacy(draft());

      final back = await cache.read();

      expect(back?.nameEn, 'Sok Heng Hardware');
      expect(plain.containsKey(_key), isFalse);
    });

    test('a newer encrypted draft wins; the plaintext one is still erased',
        () async {
      await cache.write(BpDepotDraft(nameEn: 'Newer Shop'));
      await seedLegacy(draft());

      await cache.migrateLegacyPlaintext();

      expect((await cache.read())?.nameEn, 'Newer Shop');
      expect(plain.containsKey(_key), isFalse);
    });

    test('an unreadable plaintext entry is erased, not kept', () async {
      // Not the LocalCache envelope — `get` throws on it.
      await plain.put(_key, 'not json {');

      await cache.migrateLegacyPlaintext();

      expect(plain.containsKey(_key), isFalse);
      expect(await cache.read(), isNull);
    });

    test('is a no-op, and does not throw, when there is nothing to move',
        () async {
      await cache.migrateLegacyPlaintext();

      expect(await cache.read(), isNull);
      expect(cache.hasDraft, isFalse);
    });

    test('is a no-op without a legacy store', () async {
      final noLegacy = BpDraftCache(LocalCache(secure));
      await noLegacy.migrateLegacyPlaintext();
      expect(await noLegacy.read(), isNull);
    });
  });

  test('clear() removes the draft from both boxes', () async {
    await cache.write(draft());
    await seedLegacy(draft());

    await cache.clear();

    expect(secure.containsKey(_key), isFalse);
    expect(plain.containsKey(_key), isFalse);
    expect(cache.hasDraft, isFalse);
  });
}
