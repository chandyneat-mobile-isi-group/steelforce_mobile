import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/authentication/domain/entities/user.dart';
import 'package:steelforce/features/profile/domain/entities/profile_update.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/authentication/data/models/auth_profile_model.dart';
import 'package:steelforce/features/profile/data/datasources/auth_backed_profile_data_source.dart';
import 'package:mocktail/mocktail.dart';

import 'profile_test_doubles.dart';

/// The profile screen served a hardcoded "Alex Morgan / ISI-2291" to every
/// user, whoever had signed in. It now reads the real session.
class _MockDio extends Mock implements Dio {}

void main() {
  late MockAuthRemoteDataSource remote;
  late MockAuthLocalDataSource local;
  late _MockDio dio;
  late SessionManager session;
  late AuthBackedProfileDataSource source;
  late List<Uint8List> encoded;

  /// A profile payload with every field the screen renders.
  const serverJson = {
    'userId': '019fefd2-1111-4a7f-b0d2-1f9e4c8a2b31',
    'employeeId': 'EMP000202',
    'fullName': 'Sok Dara',
    'email': 'sok.dara@isigroup.com.kh',
    'phoneNumber': '012345678',
    'position': 'Sales Representative',
    'department': 'Sales',
    'roles': ['Sales Representative'],
    'permissions': ['outlets.read', 'visits.create'],
    'territoryCode': 'PP-NORTH',
    'depotCode': 'DEPOT-PP01',
  };
  final serverProfile = AuthProfileModel.fromJson(serverJson);

  /// `GET /mobile/auth/profile` answers [body] inside the standard envelope.
  void answerGet(Map<String, dynamic> body) =>
      when(() => dio.get<Map<String, dynamic>>(ApiEndpoints.myProfileEndpoint))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/'),
                statusCode: 200,
                data: {'success': true, 'data': body},
              ));

  void failGet() =>
      when(() => dio.get<Map<String, dynamic>>(ApiEndpoints.myProfileEndpoint))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionError,
      ));

  setUpAll(registerProfileFallbacks);

  setUp(() {
    remote = MockAuthRemoteDataSource();
    local = MockAuthLocalDataSource();
    dio = _MockDio();
    session = SessionManager()
      ..setUser(
          const User(id: 'u', email: 'e', fullName: 'Old Name', roles: {}));
    encoded = [];
    source = AuthBackedProfileDataSource(
      remote: remote,
      local: local,
      client: dio,
      session: session,
      apiBaseUrl: 'https://api.example.com/',
      logger: const ConsoleAppLogger(verbose: false),
      encodeAvatar: (bytes) async {
        encoded.add(bytes);
        return Uint8List.fromList([0xFF, 0xD8, 0xFF]);
      },
    );
    when(() => local.cacheProfile(any())).thenAnswer((_) async {});
  });

  test('shows the signed-in employee, not a fixture', () async {
    answerGet(serverJson);

    final worker = await source.fetchProfile();

    expect(worker.fullName, 'Sok Dara');
    expect(worker.employeeCode, 'EMP000202');
    expect(worker.email, 'sok.dara@isigroup.com.kh');
    expect(worker.phone, '012345678');
    expect(worker.territoryCode, 'PP-NORTH');
    // `depotCode` on the live wire — it was read as `customerCode` and lost.
    expect(worker.depotCode, 'DEPOT-PP01');
    expect(worker.department, 'Sales');
    // The HR job title, preferred over the coarse role bucket.
    expect(worker.title, 'Sales Representative');
    // Never set: initials, not a stock photograph.
    expect(worker.avatarUrl, isNull);
  });

  test('a fresh profile refreshes the session cache', () async {
    answerGet(serverJson);

    await source.fetchProfile();

    // Otherwise the profile screen and the rest of the app would disagree
    // about who is signed in until the next sign-in.
    verify(() => local.cacheProfile(serverProfile)).called(1);
  });

  test('falls back to the cached profile when the call fails', () async {
    // A rep opening their profile in a warehouse with no signal should see
    // who they are, not an error.
    failGet();
    when(local.readProfile).thenAnswer((_) async => serverProfile);

    final worker = await source.fetchProfile();

    expect(worker.fullName, 'Sok Dara');
    expect(worker.employeeCode, 'EMP000202');
  });

  test('rethrows when offline with nothing cached', () async {
    // Nothing to show and no way to get it — the screen must surface the
    // error rather than render a blank identity.
    failGet();
    when(local.readProfile).thenAnswer((_) async => null);

    await expectLater(source.fetchProfile(), throwsA(isA<ApiException>()));
  });

  test('reads the GET /mobile/auth/profile payload', () async {
    answerGet(const {
      'id': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
      'employeeCode': 'EMP000202',
      'fullName': 'Sok Dara',
      'khmerName': 'សុខ ដារ៉ា',
      'phoneNumber': '+85512345209',
      'email': 'sok.dara@isigroup.com.kh',
      'role': 'Sales Representative',
      'passwordChangeRequired': false,
      'lastLoginAt': '2026-10-07T06:29:03.780Z',
      'lineManager': {
        'id': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
        'empCode': 'EMP000001',
        'englishName': 'Manager',
      },
    });

    final worker = await source.fetchProfile();

    expect(worker.fullName, 'Sok Dara');
    expect(worker.employeeCode, 'EMP000202');
    expect(worker.phone, '+85512345209');
    expect(worker.email, 'sok.dara@isigroup.com.kh');
    // No HR position on this route, so the role names the job.
    expect(worker.title, isNotNull);
    expect(ApiEndpoints.myProfileEndpoint, '/api/v1/mobile/auth/profile');
  });

  test('a relative avatarUrl is resolved against the API host', () async {
    answerGet(const {'userId': 'u', 'avatarUrl': '/files/avatars/abc'});

    final worker = await source.fetchProfile();

    expect(worker.avatarUrl, 'https://api.example.com/files/avatars/abc');
  });

  group('updateProfile — profile photo', () {
    const afterSave = {
      'id': 'u',
      'employeeCode': 'EMP000202',
      'fullName': 'Sok Dara',
      'email': 'sok.dara@isigroup.com.kh',
      'profilePhotoUrl': 'https://files.example/p/full.webp?sig=2',
      'profilePhotoThumbnailUrl': 'https://files.example/p/thumb.webp?sig=2',
    };

    void answerWrite() {
      when(() => dio.post<void>(any(), data: any(named: 'data'))).thenAnswer(
          (_) async => Response(
              requestOptions: RequestOptions(path: '/'), statusCode: 200));
      when(() => dio.delete<void>(any())).thenAnswer((_) async =>
          Response(requestOptions: RequestOptions(path: '/'), statusCode: 204));
    }

    test('a new photo is re-encoded and POSTed as `file`, a stated JPEG',
        () async {
      answerWrite();
      answerGet(afterSave);
      final picked = Uint8List.fromList([1, 2, 3]);

      await source.updateProfile(ProfileUpdate(avatarBytes: picked));

      expect(encoded.single, picked);
      final form = verify(() => dio.post<void>(
            ApiEndpoints.profilePhotoEndpoint,
            data: captureAny(named: 'data'),
          )).captured.single as FormData;
      final file = form.files.single;
      expect(file.key, 'file');
      expect(file.value.filename, 'avatar.jpg');
      expect(file.value.contentType?.mimeType, 'image/jpeg');
      expect(form.fields, isEmpty);
      verifyNever(() => dio.delete<void>(any()));
    });

    test('removing the photo is a DELETE with no upload', () async {
      answerWrite();
      answerGet(afterSave);

      await source.updateProfile(const ProfileUpdate(removeAvatar: true));

      verify(() => dio.delete<void>(ApiEndpoints.profilePhotoEndpoint))
          .called(1);
      verifyNever(() => dio.post<void>(any(), data: any(named: 'data')));
      expect(encoded, isEmpty);
    });

    test('the profile is read again, so the new signed photo shows at once',
        () async {
      answerWrite();
      answerGet(afterSave);

      final worker =
          await source.updateProfile(ProfileUpdate(avatarBytes: Uint8List(3)));

      expect(worker.avatarUrl, 'https://files.example/p/full.webp?sig=2');
      expect(worker.avatarThumbnailUrl,
          'https://files.example/p/thumb.webp?sig=2');
      verify(() => local.cacheProfile(any())).called(1);
      // The shell header reads the session.
      expect(session.currentUser?.avatarUrl,
          'https://files.example/p/full.webp?sig=2');
    });

    test('a failed re-read after a good save still reports success', () async {
      answerWrite();
      failGet();
      when(local.readProfile).thenAnswer((_) async => serverProfile);

      final worker =
          await source.updateProfile(ProfileUpdate(avatarBytes: Uint8List(3)));

      expect(worker.fullName, 'Sok Dara');
    });

    test('a refused upload surfaces as ApiException and changes nothing',
        () async {
      final options = RequestOptions(path: '/');
      when(() => dio.post<void>(any(), data: any(named: 'data')))
          .thenThrow(DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: options, statusCode: 413),
      ));

      await expectLater(
        source.updateProfile(ProfileUpdate(avatarBytes: Uint8List(1))),
        throwsA(isA<ApiException>()
            .having((e) => e.error.statusCode, 'status', 413)),
      );
      verifyNever(() => local.cacheProfile(any()));
      expect(session.currentUser?.fullName, 'Old Name');
    });

    test('an unreadable picture fails before any upload', () async {
      source = AuthBackedProfileDataSource(
        remote: remote,
        local: local,
        client: dio,
        session: session,
        apiBaseUrl: 'https://api.example.com',
        logger: const ConsoleAppLogger(verbose: false),
        encodeAvatar: (_) async => throw const FormatException('not an image'),
      );

      await expectLater(
        source.updateProfile(ProfileUpdate(avatarBytes: Uint8List(4))),
        throwsA(isA<AvatarUnreadableException>()),
      );
      verifyNever(() => dio.post<void>(any(), data: any(named: 'data')));
    });

    test('the photo route is not under /mobile/', () {
      expect(ApiEndpoints.profilePhotoEndpoint, '/api/v1/users/profile-photo');
    });
  });

  test('password change goes to the real endpoint', () async {
    when(() => remote.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        )).thenAnswer((_) async {});

    await source.changePassword(
      currentPassword: 'old-password-1',
      newPassword: 'new-password-long-enough',
    );

    verify(() => remote.changePassword(
          currentPassword: 'old-password-1',
          newPassword: 'new-password-long-enough',
        )).called(1);
  });

  test('logout does not revoke — AuthBloc owns that', () async {
    // ProfileScreen dispatches LogoutRequested after this returns. Revoking
    // here too would end the session twice, the second call presenting a
    // refresh token the first already retired — which reuse detection reads
    // as theft.
    await source.logout();

    verifyNever(() => remote.logout(
          refreshToken: any(named: 'refreshToken'),
          allDevices: any(named: 'allDevices'),
        ));
  });
}
