import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/secure/database_key_rotator.dart';
import 'package:steelforce/core/database/secure/dynamic_key_store.dart';
import 'package:steelforce/core/database/secure/key_derivation.dart';
import 'package:mocktail/mocktail.dart';

class _MockDeviceKeyStore extends Mock implements DynamicKeyStore {}

/// Records call order and can be told to fail, to prove the safety ordering.
class _FakeRekeyExecutor implements DatabaseRekeyExecutor {
  _FakeRekeyExecutor({this.shouldThrow = false});
  final bool shouldThrow;
  final List<String> rekeyed = [];

  @override
  Future<void> rekey(String rawKeyHex) async {
    if (shouldThrow) throw StateError('rekey failed');
    rekeyed.add(rawKeyHex);
  }
}

void main() {
  const salt = 'e7b4c92a10dcf85b4138e93d9a74fe11';
  final candidate = 'ab' * 32; // 64 hex chars
  const derivation = KeyDerivation();
  final expectedPassphrase =
      derivation.deriveDatabaseKey(salt: salt, deviceKey: candidate);

  late _MockDeviceKeyStore store;

  setUp(() {
    store = _MockDeviceKeyStore();
    when(() => store.newCandidateKey()).thenReturn(candidate);
    when(() => store.replaceDeviceKey(any())).thenAnswer((_) async {});
    when(() => store.currentVersion()).thenAnswer((_) async => 2);
  });

  test('rekeys with the newly derived passphrase, then persists the key',
      () async {
    final executor = _FakeRekeyExecutor();
    final rotator = DatabaseKeyRotator(
      deviceKeyStore: store,
      keyDerivation: derivation,
      executor: executor,
      salt: salt,
    );

    final version = await rotator.rotate();

    expect(executor.rekeyed.single, expectedPassphrase);
    verify(() => store.replaceDeviceKey(candidate)).called(1);
    expect(version, 2);
  });

  test('does NOT persist the new key if rekey fails (old key preserved)',
      () async {
    final executor = _FakeRekeyExecutor(shouldThrow: true);
    final rotator = DatabaseKeyRotator(
      deviceKeyStore: store,
      keyDerivation: derivation,
      executor: executor,
      salt: salt,
    );

    await expectLater(rotator.rotate(), throwsStateError);

    expect(executor.rekeyed, isEmpty);
    verifyNever(() => store.replaceDeviceKey(any()));
  });
}
