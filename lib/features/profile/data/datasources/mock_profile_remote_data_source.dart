// TODO(release-gate): demo-only data source; must never be registered in a release mobile build (USE_MOCK_DATA=false).
import 'dart:convert';
import 'dart:typed_data';

import 'package:steelforce/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:steelforce/features/profile/data/avatar_image_encoder.dart';
import 'package:steelforce/features/profile/data/datasources/auth_backed_profile_data_source.dart';
import 'package:steelforce/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:steelforce/features/profile/data/models/worker_profile_model.dart';
import 'package:steelforce/features/profile/domain/entities/profile_update.dart';

/// [ProfileRemoteDataSource] for the backend-less demo (`USE_MOCK_DATA=true`).
///
/// Reads go through [AuthRemoteDataSource], as the real source's do. In
/// demo mode that is the mock auth source, so the profile screen and the
/// sign-in session describe the same fictional rep.
///
/// A photo change is held in memory for the session, so a re-read shows it.
/// The picked image is re-encoded with the same [AvatarImageEncoder] the
/// upload path uses, and served back as a `data:` URI. That keeps it small
/// and EXIF-free, and an unreadable file fails the way it does live. It is
/// not written to the session cache or the shell header. Both resolve
/// avatar paths against the API host, which a `data:` URI does not survive.
class MockProfileRemoteDataSource implements ProfileRemoteDataSource {
  MockProfileRemoteDataSource({
    required AuthRemoteDataSource auth,
    Future<Uint8List> Function(Uint8List bytes)? encodeAvatar,
  })  : _auth = auth,
        _encodeAvatar = encodeAvatar ?? AvatarImageEncoder.encode;

  final AuthRemoteDataSource _auth;
  final Future<Uint8List> Function(Uint8List bytes) _encodeAvatar;

  String? _avatarDataUri;

  @override
  Future<WorkerProfileModel> fetchProfile() async {
    final profile = await _auth.getProfile();
    // Absolute already, or null: the demo rep has no server-relative avatar
    // path, so no API base URL is needed to resolve one.
    return _withAvatar(
        WorkerProfileModel.fromAuthProfile(profile, apiBaseUrl: ''));
  }

  @override
  Future<WorkerProfileModel> updateProfile(ProfileUpdate update) async {
    final picked = update.avatarBytes;
    if (picked != null) {
      final Uint8List jpeg;
      try {
        jpeg = await _encodeAvatar(picked);
      } on FormatException {
        throw const AvatarUnreadableException();
      }
      _avatarDataUri = 'data:image/jpeg;base64,${base64Encode(jpeg)}';
    } else if (update.removeAvatar) {
      _avatarDataUri = null;
    }
    return fetchProfile();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _auth.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

  /// Sign-out is owned by `AuthBloc`, exactly as in the real source.
  @override
  Future<void> logout() async {}

  WorkerProfileModel _withAvatar(WorkerProfileModel p) {
    final avatar = _avatarDataUri;
    if (avatar == null) return p;
    return WorkerProfileModel(
      id: p.id,
      fullName: p.fullName,
      employeeCode: p.employeeCode,
      email: p.email,
      phone: p.phone,
      position: p.position,
      department: p.department,
      roleLabel: p.roleLabel,
      territoryCode: p.territoryCode,
      depotCode: p.depotCode,
      language: p.language,
      timeZone: p.timeZone,
      avatarUrl: avatar,
      avatarThumbnailUrl: avatar,
      lastLoginAt: p.lastLoginAt,
      passwordExpiresAt: p.passwordExpiresAt,
      isActive: p.isActive,
      khmerName: p.khmerName,
      lineManagerName: p.lineManagerName,
      lineManagerCode: p.lineManagerCode,
      temporaryPasswordExpiresAt: p.temporaryPasswordExpiresAt,
      salesOrgCode: p.salesOrgCode,
      salesOrgName: p.salesOrgName,
    );
  }
}
