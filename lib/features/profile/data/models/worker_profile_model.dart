import 'package:steelforce/core/network/api/server_url.dart';
import 'package:steelforce/features/authentication/domain/entities/auth_profile.dart';
import 'package:steelforce/features/profile/domain/entities/worker_profile.dart';

/// [WorkerProfile] built from `GET /api/v1/mobile/auth/profile`'s auth record.
///
/// There is no second JSON parser here: [AuthProfileModel] parses the mobile
/// profile response and also handles the related auth profile/cache shapes.
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
    super.salesOrgCode,
    super.salesOrgName,
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
        salesOrgCode: _blankToNull(p.salesOrgCode),
        salesOrgName: _blankToNull(p.salesOrgName),
      );

  static String? _blankToNull(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();
}
