import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/authentication/data/datasources/auth_local_data_source.dart';
import 'package:steelforce/features/authentication/data/mock/demo_auth_remote_data_source.dart';
import 'package:steelforce/features/authentication/data/models/auth_profile_model.dart';
import 'package:steelforce/features/authentication/data/models/auth_token_model.dart';
import 'package:steelforce/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:steelforce/features/authentication/domain/entities/auth_profile.dart';
import 'package:steelforce/features/authentication/domain/entities/user_role.dart';

class _MockLocal extends Mock implements AuthLocalDataSource {}

class _MockNetworkInfo extends Mock implements NetworkInfo {}

TypeMatcher<ApiException> _apiError(String code) =>
    isA<ApiException>().having((e) => e.code, 'code', code);

void main() {
  late DemoNetwork network;
  late DemoAuthRemoteDataSource source;

  setUp(() {
    network = DemoNetwork();
    source = DemoAuthRemoteDataSource(network, translate: (key) => key);
  });

  group('login', () {
    test('accepts the demo account as the sign-in field sends it', () async {
      final token = await source.login(
        phoneNumber: '+855${DemoSeed.signInPhone}',
        password: DemoSeed.signInPassword,
      );
      expect(token.isUsable, isTrue);
      expect(token.passwordChangeRequired, isFalse);
    });

    test('matches the number on digits, like the server', () {
      for (final spelling in [
        '123456789',
        ' 0123456789 ',
        '+855 12 345 6789',
        '012-345-6789',
      ]) {
        expect(DemoAuthRemoteDataSource.isDemoPhone(spelling), isTrue,
            reason: spelling);
      }
      expect(DemoAuthRemoteDataSource.isDemoPhone('+855987654321'), isFalse);
    });

    test('a wrong password is the server invalid-credentials error', () async {
      await expectLater(
        source.login(phoneNumber: DemoSeed.signInPhone, password: 'nope1234'),
        throwsA(_apiError(ApiErrorCodes.invalidCredentials).having(
            (e) => e.error.message, 'message', 'auth.invalid_credentials')),
      );
    });

    test('a wrong number is the same error — never says which was wrong',
        () async {
      await expectLater(
        source.login(
            phoneNumber: '+855987654321', password: DemoSeed.signInPassword),
        throwsA(_apiError(ApiErrorCodes.invalidCredentials)),
      );
    });

    test('offline fails as a real dropped connection', () async {
      network.setOnline(false);
      await expectLater(
        source.login(
            phoneNumber: DemoSeed.signInPhone,
            password: DemoSeed.signInPassword),
        throwsA(_apiError(ApiErrorCodes.network)),
      );
    });
  });

  test('profile is a sales rep holding every depot capability', () async {
    final profile = await source.getProfile();
    expect(profile.id, DemoSeed.repId);
    expect(profile.employeeId, DemoSeed.repPersonnelNo);
    expect(profile.fullName, DemoSeed.repName);
    expect(profile.khmerName, DemoSeed.repNameKm);
    expect(profile.roles, {UserRole.salesRep});
    expect(profile.canReadDepots, isTrue);
    expect(profile.canCreateDepots, isTrue);
    expect(profile.canUpdateDepots, isTrue);
    expect(profile.can(Permissions.depotsDelete), isFalse);
    expect(profile.lineManagerName, DemoSeed.managerName);
    expect(profile.flag('offlineSync'), isTrue);
  });

  test('profile survives the secure-storage cache round trip', () async {
    final profile = await source.getProfile();
    final restored = AuthProfileModel.fromJson(profile.toJson());
    expect(restored, profile);
  });

  group('password change', () {
    test('wrong current password is invalid credentials', () async {
      await expectLater(
        source.changePassword(
            currentPassword: 'wrong', newPassword: 'NewPass123'),
        throwsA(_apiError(ApiErrorCodes.invalidCredentials)),
      );
    });

    test('succeeds, but the demo password stays the published one', () async {
      await source.changePassword(
        currentPassword: DemoSeed.signInPassword,
        newPassword: 'NewPass123',
      );
      final token = await source.login(
          phoneNumber: DemoSeed.signInPhone, password: DemoSeed.signInPassword);
      expect(token.isUsable, isTrue);
      await expectLater(
        source.login(phoneNumber: DemoSeed.signInPhone, password: 'NewPass123'),
        throwsA(_apiError(ApiErrorCodes.invalidCredentials)),
      );
    });
  });

  group('password reset', () {
    test('wrong code is invalid verification code', () async {
      await source.forgotPassword(DemoSeed.signInPhone);
      await expectLater(
        source.verifyResetCode(
            phoneNumber: DemoSeed.signInPhone, otp: '000000'),
        throwsA(_apiError(ApiErrorCodes.invalidVerificationCode)),
      );
    });

    test('the demo code grants a one-time reset with a policy', () async {
      await source.forgotPassword(DemoSeed.signInPhone);
      final grant = await source.verifyResetCode(
          phoneNumber: DemoSeed.signInPhone, otp: DemoSeed.resetCode);
      expect(grant.resetToken, isNotEmpty);
      expect(grant.policy.minLength, greaterThan(0));

      await source.resetPassword(
          resetToken: grant.resetToken, newPassword: 'Reset1234');
      // The reset succeeds, but the demo account keeps its published password.
      final token = await source.login(
          phoneNumber: DemoSeed.signInPhone, password: DemoSeed.signInPassword);
      expect(token.isUsable, isTrue);

      // Spent: the same token cannot reset twice.
      await expectLater(
        source.resetPassword(
            resetToken: grant.resetToken, newPassword: 'Again1234'),
        throwsA(_apiError(ApiErrorCodes.verificationNotFound)),
      );
    });

    test('a reset without a verified code is refused', () async {
      await expectLater(
        source.resetPassword(resetToken: 'forged', newPassword: 'Reset1234'),
        throwsA(_apiError(ApiErrorCodes.verificationNotFound)),
      );
    });
  });

  test('logout and heartbeat succeed online, fail offline', () async {
    await source.logout(refreshToken: 'demo-refresh-token');
    await source.sendHeartbeat(11.5, 104.9, 10, DateTime.utc(2026));
    network.setOnline(false);
    await expectLater(source.logout(refreshToken: 'demo-refresh-token'),
        throwsA(_apiError(ApiErrorCodes.network)));
  });

  group('through the real repository', () {
    late _MockLocal local;
    late AuthRepositoryImpl repository;

    setUpAll(() {
      registerFallbackValue(
          const AuthTokenModel(accessToken: 'a', refreshToken: 'r'));
      registerFallbackValue(AuthProfileModel.fromJson(const {'userId': 'x'}));
    });

    setUp(() {
      local = _MockLocal();
      final info = _MockNetworkInfo();
      when(() => info.isConnected).thenAnswer((_) async => network.isOnline);
      when(() => local.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'))).thenAnswer((_) async {});
      when(() => local.cacheSession(
          token: any(named: 'token'),
          profile: any(named: 'profile'))).thenAnswer((_) async {});
      when(() => local.clear()).thenAnswer((_) async {});
      repository = AuthRepositoryImpl(
        remote: source,
        local: local,
        networkInfo: info,
        logger: const ConsoleAppLogger(verbose: false),
      );
    });

    test('the demo account signs in and caches the session', () async {
      final result = await repository.login(
        identifier: '+855${DemoSeed.signInPhone}',
        password: DemoSeed.signInPassword,
      );
      expect(result, isA<Success<AuthProfile>>());
      verify(() => local.cacheSession(
          token: any(named: 'token'),
          profile: any(named: 'profile'))).called(1);
    });

    test('a wrong password reaches the UI as an authentication failure',
        () async {
      final result = await repository.login(
          identifier: DemoSeed.signInPhone, password: 'wrong-pass');
      final failure = (result as Failed).failure;
      expect(failure, isA<AuthenticationFailure>());
      expect(failure.message, 'auth.invalid_credentials');
    });

    test('offline is the repository network failure', () async {
      network.setOnline(false);
      final result = await repository.login(
          identifier: DemoSeed.signInPhone, password: DemoSeed.signInPassword);
      expect((result as Failed).failure, isA<NetworkFailure>());
    });
  });
}
