import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/authentication/data/datasources/auth_local_data_source.dart';
import 'package:steelforce/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:steelforce/features/authentication/data/models/auth_profile_model.dart';
import 'package:steelforce/features/authentication/domain/entities/auth_profile.dart';
import 'package:steelforce/features/profile/data/avatar_image_encoder.dart';
import 'package:steelforce/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:steelforce/features/profile/data/models/worker_profile_model.dart';
import 'package:steelforce/features/profile/domain/entities/profile_update.dart';

/// Thrown when a picked picture cannot be decoded, before any upload.
class AvatarUnreadableException implements Exception {
  const AvatarUnreadableException();
}

/// The signed-in employee's profile, sourced from the auth layer.
///
/// Reads come from `GET /mobile/auth/profile` ([ApiEndpoints.myProfileEndpoint]),
/// with the session cache as the offline fallback. Writes go to
/// [ApiEndpoints.avatarEndpoint] — the picture is the only thing a rep may
/// change — which answers with a profile payload, so a save replaces the cache
/// and the session from the response instead of re-fetching.
class AuthBackedProfileDataSource implements ProfileRemoteDataSource {
  AuthBackedProfileDataSource({
    required AuthRemoteDataSource remote,
    required AuthLocalDataSource local,
    required Dio client,
    required SessionManager session,
    required String apiBaseUrl,
    required AppLogger logger,
    Future<Uint8List> Function(Uint8List bytes)? encodeAvatar,
  })  : _remote = remote,
        _local = local,
        _client = client,
        _session = session,
        _apiBaseUrl = apiBaseUrl,
        _logger = logger,
        _encodeAvatar = encodeAvatar ?? AvatarImageEncoder.encode;

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;

  /// The authenticated client — carries the bearer token.
  final Dio _client;
  final SessionManager _session;
  final String _apiBaseUrl;
  final AppLogger _logger;
  final Future<Uint8List> Function(Uint8List bytes) _encodeAvatar;

  /// Fresh from `/mobile/auth/profile`, falling back to the cached session
  /// when the call fails.
  ///
  /// The fallback is the point: a rep opening their profile in a warehouse
  /// with no signal should see who they are, not an error. The cached copy was
  /// written at sign-in and is the same shape, so the screen renders
  /// identically — it is simply not re-verified.
  @override
  Future<WorkerProfileModel> fetchProfile() async {
    try {
      final profile = await _getProfile();
      await _local.cacheProfile(profile);
      _logger.debug('profile.loaded', fields: {'source': 'remote'});
      return _toWorker(profile);
    } on ApiException catch (e) {
      final cached = await _local.readProfile();
      if (cached == null) rethrow;

      _logger.warning('profile.loaded', fields: {
        'source': 'cache',
        'errorCode': e.error.code,
      });
      return _toWorker(cached);
    }
  }

  Future<AuthProfileModel> _getProfile() async {
    try {
      final res = await _client.get<DataMap>(ApiEndpoints.myProfileEndpoint);
      return AuthProfileModel.fromJson(ApiEnvelope.fromBody(res.data).data);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  /// Uploads a new photo (`POST`, field `file`) or removes the current one
  /// (`DELETE`) at [ApiEndpoints.profilePhotoEndpoint]. The rest of the
  /// profile is read-only to the rep.
  ///
  /// The photo route answers with the photo only, so the profile is read
  /// again afterwards: that is where the fresh signed `profilePhotoUrl` comes
  /// from, and it keeps the cache and the shell header in step.
  ///
  /// Online only, deliberately not queued: the server owns this record and the
  /// request carries a picture.
  @override
  Future<WorkerProfileModel> updateProfile(ProfileUpdate update) async {
    final uploaded = update.avatarBytes;
    final FormData? form;
    if (uploaded != null) {
      final Uint8List jpeg;
      try {
        jpeg = await _encodeAvatar(uploaded);
      } on FormatException {
        throw const AvatarUnreadableException();
      }
      form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          jpeg,
          filename: 'avatar.jpg',
          // Stated, never inferred: the server rejects a file whose name,
          // content type and content disagree.
          contentType: DioMediaType('image', 'jpeg'),
        ),
      });
    } else {
      form = null;
    }

    try {
      if (form != null) {
        await _client.post<void>(ApiEndpoints.profilePhotoEndpoint, data: form);
      } else if (update.removeAvatar) {
        await _client.delete<void>(ApiEndpoints.profilePhotoEndpoint);
      }
    } on DioException catch (e) {
      final error = ApiError.fromDio(e);
      _logger.error('profile.photo.failed', fields: {
        'status': error.statusCode,
        'errorCode': error.code,
        'correlationId': error.correlationId,
      });
      throw ApiException(error);
    }
    _logger.info('profile.photo.saved', fields: {
      'uploaded': form != null,
      'removed': update.removeAvatar,
    });

    // The photo is saved. A profile read that fails now must not report the
    // save as failed — show the cached profile, and the next read picks up
    // the new photo.
    final AuthProfileModel profile;
    try {
      profile = await _getProfile();
    } on ApiException {
      final cached = await _local.readProfile();
      if (cached == null) rethrow;
      return _toWorker(cached);
    }

    try {
      await _local.cacheProfile(profile);
    } on CacheException {
      _logger.warning('profile.update.cacheFailed');
    }
    // So the shell header shows the new picture straight away.
    _session.updateUser(profile.toUser());
    return _toWorker(profile);
  }

  /// Real password change. The server re-verifies [currentPassword] even
  /// though the caller is authenticated — that is what stops a borrowed
  /// unlocked handset becoming a permanent account takeover.
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _remote.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

  /// Sign-out is owned by `AuthBloc`, which clears the token store, every
  /// session-scoped store, and restarts the app.
  ///
  /// [ProfileScreen] already dispatches `LogoutRequested` after this returns,
  /// so revoking here as well would end the session twice — the second call
  /// presenting a refresh token the first one already retired, which reuse
  /// detection reads as theft.
  @override
  Future<void> logout() async {
    _logger.debug('profile.logout.delegated');
  }

  WorkerProfileModel _toWorker(AuthProfile p) =>
      WorkerProfileModel.fromAuthProfile(p, apiBaseUrl: _apiBaseUrl);
}
