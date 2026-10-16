import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/api/server_url.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/profile/data/avatar_image_encoder.dart';
import 'package:steelforce/features/profile/data/datasources/auth_backed_profile_data_source.dart';
import 'package:steelforce/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:steelforce/features/profile/data/models/worker_profile_model.dart';
import 'package:steelforce/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:steelforce/features/profile/domain/entities/profile_failure_codes.dart';
import 'package:steelforce/features/profile/domain/entities/profile_update.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements ProfileRemoteDataSource {}

void main() {
  setUpAll(
      () => registerFallbackValue(const ProfileUpdate(removeAvatar: true)));

  group('ProfileUpdate', () {
    test('nothing set is empty — the server would reject it', () {
      expect(const ProfileUpdate().isEmpty, isTrue);
    });

    test('a new picture or removing it is a change', () {
      expect(ProfileUpdate(avatarBytes: Uint8List(1)).isEmpty, isFalse);
      expect(const ProfileUpdate(removeAvatar: true).isEmpty, isFalse);
    });
  });

  group('resolveServerUrl', () {
    test('joins a relative path to the host, with one slash', () {
      expect(resolveServerUrl('/files/avatars/a', 'https://h.example/'),
          'https://h.example/files/avatars/a');
      expect(resolveServerUrl('/files/avatars/a', 'https://h.example'),
          'https://h.example/files/avatars/a');
    });

    test('leaves an absolute URL alone and keeps null as null', () {
      expect(resolveServerUrl('https://cdn.example/a.jpg', 'https://h'),
          'https://cdn.example/a.jpg');
      expect(resolveServerUrl(null, 'https://h'), isNull);
      expect(resolveServerUrl('  ', 'https://h'), isNull);
    });
  });

  group('AvatarImageEncoder', () {
    Uint8List photo({required int width, required int height}) {
      final image = img.Image(width: width, height: height)
        ..exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(11, 1);
      img.fill(image, color: img.ColorRgb8(200, 30, 30));
      return Uint8List.fromList(img.encodeJpg(image));
    }

    test('the source photo really does carry a GPS tag', () {
      // Guards the next test: it proves nothing if the fixture has no tag.
      final source = img.decodeJpg(photo(width: 40, height: 20))!;
      expect(source.exif.gpsIfd.isEmpty, isFalse);
    });

    test('strips location metadata — the file is served publicly', () {
      final out = AvatarImageEncoder.encodeSync(photo(width: 40, height: 20));

      final decoded = img.decodeJpg(out)!;
      expect(decoded.exif.gpsIfd.isEmpty, isTrue);
      expect(decoded.exif.isEmpty, isTrue);
    });

    test('downscales the long edge to 512, keeping the aspect ratio', () {
      final out =
          AvatarImageEncoder.encodeSync(photo(width: 2000, height: 1000));

      final decoded = img.decodeJpg(out)!;
      expect(decoded.width, 512);
      expect(decoded.height, 256);
      expect(out.length, lessThan(2 * 1024 * 1024));
    });

    test('a small picture is not upscaled', () {
      final decoded = img.decodeJpg(
          AvatarImageEncoder.encodeSync(photo(width: 100, height: 300)))!;
      expect(decoded.width, 100);
      expect(decoded.height, 300);
    });

    test('a PNG comes out as a JPEG', () {
      final png = img.encodePng(img.Image(width: 10, height: 10));
      final out = AvatarImageEncoder.encodeSync(Uint8List.fromList(png));
      expect(img.JpegDecoder().isValidFile(out), isTrue);
    });

    test('bytes that are not an image are a FormatException', () {
      expect(() => AvatarImageEncoder.encodeSync(Uint8List.fromList([1, 2])),
          throwsFormatException);
    });
  });

  group('ProfileRepositoryImpl.updateProfile', () {
    late _MockRemote remote;
    late ProfileRepositoryImpl repository;

    setUp(() {
      remote = _MockRemote();
      repository = ProfileRepositoryImpl(remoteDataSource: remote);
    });

    Failure failureOf(Result<Object?> r) =>
        r.when(success: (_) => fail('expected a failure'), failure: (f) => f);

    test('an empty update never reaches the server', () async {
      final result = await repository.updateProfile(const ProfileUpdate());

      expect((failureOf(result) as ServerFailure).code,
          ApiErrorCodes.profileUpdateEmpty);
      verifyNever(() => remote.updateProfile(any()));
    });

    test('offline is a NetworkFailure, not a server error', () async {
      when(() => remote.updateProfile(any()))
          .thenThrow(const ApiException(ApiError(code: ApiErrorCodes.network)));

      final result = await repository
          .updateProfile(const ProfileUpdate(removeAvatar: true));

      expect(failureOf(result), isA<NetworkFailure>());
    });

    test('the server code survives, so the UI can say what went wrong',
        () async {
      when(() => remote.updateProfile(any())).thenThrow(const ApiException(
          ApiError(code: ApiErrorCodes.avatarTooLarge, statusCode: 400)));

      final result = await repository
          .updateProfile(const ProfileUpdate(removeAvatar: true));

      expect((failureOf(result) as ServerFailure).code,
          ApiErrorCodes.avatarTooLarge);
    });

    test('an unreadable picture has its own code', () async {
      when(() => remote.updateProfile(any()))
          .thenThrow(const AvatarUnreadableException());

      final result = await repository
          .updateProfile(const ProfileUpdate(removeAvatar: true));

      expect((failureOf(result) as ServerFailure).code,
          ProfileFailureCodes.avatarUnreadable);
    });

    test('success returns the saved profile', () async {
      const saved = WorkerProfileModel(
          id: 'u', fullName: 'A B', employeeCode: 'E', email: 'e', phone: '');
      when(() => remote.updateProfile(any())).thenAnswer((_) async => saved);

      final result = await repository
          .updateProfile(const ProfileUpdate(removeAvatar: true));

      expect(result.when(success: (p) => p, failure: (_) => null), saved);
    });
  });
}
