import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/authentication/data/mock/demo_auth_remote_data_source.dart';
import 'package:steelforce/features/authentication/data/models/auth_profile_model.dart';
import 'package:steelforce/features/profile/data/datasources/auth_backed_profile_data_source.dart';
import 'package:steelforce/features/profile/data/mock/demo_profile_data_source.dart';
import 'package:steelforce/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:steelforce/features/profile/domain/entities/profile_update.dart';

import 'profile_test_doubles.dart';

void main() {
  late DemoNetwork network;
  late MockAuthLocalDataSource local;
  late DemoProfileDataSource source;

  setUpAll(registerProfileFallbacks);

  setUp(() {
    network = DemoNetwork();
    local = MockAuthLocalDataSource();
    when(() => local.cacheProfile(any())).thenAnswer((_) async {});
    when(() => local.readProfile()).thenAnswer((_) async => null);
    source = DemoProfileDataSource(
      network: network,
      remote: DemoAuthRemoteDataSource(network, translate: (key) => key),
      local: local,
      encodeAvatar: (bytes) async => bytes,
    );
  });

  test('fetches the demo rep and refreshes the session cache', () async {
    final profile = await source.fetchProfile();
    expect(profile.fullName, DemoSeed.repName);
    expect(profile.employeeCode, DemoSeed.repPersonnelNo);
    expect(profile.khmerName, DemoSeed.repNameKm);
    expect(profile.lineManagerName, DemoSeed.managerName);
    expect(profile.avatarUrl, isNull);
    verify(() => local.cacheProfile(any())).called(1);
  });

  test('offline falls back to the cached profile, as live does', () async {
    final cached = AuthProfileModel.fromJson(
      DemoAuthRemoteDataSource.demoProfileJson(),
    );
    when(() => local.readProfile()).thenAnswer((_) async => cached);
    network.setOnline(false);

    final profile = await source.fetchProfile();
    expect(profile.fullName, DemoSeed.repName);
    verifyNever(() => local.cacheProfile(any()));
  });

  test('offline with nothing cached is a network error', () async {
    network.setOnline(false);
    await expectLater(
      source.fetchProfile(),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', ApiErrorCodes.network)),
    );
  });

  test('a photo update is accepted online and refused offline', () async {
    final update = ProfileUpdate(avatarBytes: Uint8List.fromList([1, 2, 3]));
    final saved = await source.updateProfile(update);
    expect(saved.fullName, DemoSeed.repName);

    network.setOnline(false);
    final repository = ProfileRepositoryImpl(remoteDataSource: source);
    final result = await repository.updateProfile(update);
    expect((result as Failed).failure, isA<NetworkFailure>());
  });

  test('an unreadable picture fails before the round trip', () async {
    final unreadable = DemoProfileDataSource(
      network: network,
      remote: DemoAuthRemoteDataSource(network, translate: (key) => key),
      local: local,
      encodeAvatar: (_) async => throw const FormatException('not an image'),
    );
    await expectLater(
      unreadable.updateProfile(
        ProfileUpdate(avatarBytes: Uint8List.fromList([0])),
      ),
      throwsA(isA<AvatarUnreadableException>()),
    );
  });

  test('change password re-verifies the current one', () async {
    await expectLater(
      source.changePassword(currentPassword: 'wrong', newPassword: 'New12345'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', ApiErrorCodes.invalidCredentials)),
    );
    await source.changePassword(
      currentPassword: DemoSeed.signInPassword,
      newPassword: 'New12345',
    );
  });

  test('logout is a local no-op, owned by AuthBloc', () async {
    network.setOnline(false);
    await source.logout();
  });
}
