import 'dart:typed_data';

import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/authentication/data/datasources/auth_local_data_source.dart';
import 'package:steelforce/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:steelforce/features/authentication/domain/entities/auth_profile.dart';
import 'package:steelforce/features/profile/data/avatar_image_encoder.dart';
import 'package:steelforce/features/profile/data/datasources/auth_backed_profile_data_source.dart';
import 'package:steelforce/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:steelforce/features/profile/data/models/worker_profile_model.dart';
import 'package:steelforce/features/profile/domain/entities/profile_update.dart';

/// The profile screen's source in a demo build.
///
/// The live source reads `/mobile/auth/profile` and writes the photo through
/// its own `Dio` client, so it cannot be reused offline. This one reads the
/// demo rep from the (demo) [AuthRemoteDataSource] — one answer to "who is
/// signed in" — and keeps the live source's offline fallback to the session
/// cache, so switching the DEMO badge to offline shows the cached profile
/// exactly as a rep with no signal would see it.
///
/// A picture "upload" is validated and accepted but not displayed: avatars
/// render from a URL only, and a demo build has no server to host one.
///
/// TODO(release-gate): demo-only, selected only when DataSourceMode.useMocks.
/// A live build registers `AuthBackedProfileDataSource` instead.
class DemoProfileDataSource implements ProfileRemoteDataSource {
  DemoProfileDataSource({
    required DemoNetwork network,
    required AuthRemoteDataSource remote,
    required AuthLocalDataSource local,
    Future<Uint8List> Function(Uint8List bytes)? encodeAvatar,
  })  : _network = network,
        _remote = remote,
        _local = local,
        _encodeAvatar = encodeAvatar ?? AvatarImageEncoder.encode;

  final DemoNetwork _network;
  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final Future<Uint8List> Function(Uint8List bytes) _encodeAvatar;

  @override
  Future<WorkerProfileModel> fetchProfile() async {
    try {
      final profile = await _remote.getProfile();
      await _local.cacheProfile(profile);
      return _toWorker(profile);
    } on ApiException {
      final cached = await _local.readProfile();
      if (cached == null) rethrow;
      return _toWorker(cached);
    }
  }

  @override
  Future<WorkerProfileModel> updateProfile(ProfileUpdate update) async {
    final picked = update.avatarBytes;
    if (picked != null) {
      // Decoded for real, so an unreadable picture fails as it would live.
      try {
        await _encodeAvatar(picked);
      } on FormatException {
        throw const AvatarUnreadableException();
      }
    }
    await _network.roundTrip();
    return fetchProfile();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _remote.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

  /// Sign-out is owned by `AuthBloc`, as in the live source.
  @override
  Future<void> logout() async {}

  /// No base URL: the demo profile carries no avatar address to resolve, and
  /// a demo build should not name a real server anywhere.
  WorkerProfileModel _toWorker(AuthProfile p) =>
      WorkerProfileModel.fromAuthProfile(p, apiBaseUrl: '');
}
