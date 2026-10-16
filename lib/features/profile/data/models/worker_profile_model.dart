import 'package:steelforce/core/network/api/server_url.dart';
import 'package:steelforce/features/authentication/domain/entities/auth_profile.dart';
import 'package:steelforce/features/profile/domain/entities/worker_profile.dart';

/// [WorkerProfile] built from the auth layer's record.
///
/// There is no JSON of its own: `GET /auth/me` and `PUT /users/me/profile`
/// both answer with the same `EmployeeProfileResponse`, which
/// `AuthProfileModel` already parses — a second parser for the same payload
/// would be a second place for the two to drift.
class WorkerProfileModel extends WorkerProfile {
  const WorkerProfileModel({
    required super.id,
    required super.fullName,
    required super.employeeCode,
    required super.email,
    required super.phone,
    super.position,
    super.department,
    super.roleLabel,
    super.territoryCode,
    super.depotCode,
    super.language,
    super.timeZone,
    super.avatarUrl,
    super.lastLoginAt,
    super.passwordExpiresAt,
    super.isActive,
    super.khmerName,
    super.lineManagerName,
    super.lineManagerCode,
    super.temporaryPasswordExpiresAt,
    super.avatarThumbnailUrl,
  });

  /// [apiBaseUrl] resolves the server-relative `avatarUrl`
  /// (`/files/avatars/…`) into an address an image widget can load.
  factory WorkerProfileModel.fromAuthProfile(
    AuthProfile p, {
    required String apiBaseUrl,
  }) =>
      WorkerProfileModel(
        id: p.id,
        fullName: p.fullName,
        employeeCode: p.employeeId,
        email: p.email,
        phone: p.phoneNumber ?? '',
        position: _blankToNull(p.position),
        department: _blankToNull(p.department),
        roleLabel: _blankToNull(p.positionOrRoleLabel),
        territoryCode: _blankToNull(p.territoryCode),
        depotCode: _blankToNull(p.depotCode),
        language: _blankToNull(p.language),
        timeZone: _blankToNull(p.timeZone),
        avatarUrl: resolveServerUrl(p.avatarUrl, apiBaseUrl),
        lastLoginAt: p.lastLoginAt,
        passwordExpiresAt: p.passwordExpiresAt,
        // Reaching /auth/me at all requires an unexpired, unrevoked token on
        // a non-disabled account, so a rendered profile is an active one.
        isActive: true,
        khmerName: _blankToNull(p.khmerName),
        lineManagerName: _blankToNull(p.lineManagerName),
        lineManagerCode: _blankToNull(p.lineManagerCode),
        temporaryPasswordExpiresAt:
            p.passwordChangeRequired ? p.temporaryPasswordExpiresAt : null,
        avatarThumbnailUrl: resolveServerUrl(p.avatarThumbnailUrl, apiBaseUrl),
      );

  static String? _blankToNull(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();
}
