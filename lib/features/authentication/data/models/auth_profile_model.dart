import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/authentication/domain/entities/auth_profile.dart';
import 'package:steelforce/features/authentication/domain/entities/user_role.dart';

/// Deserialises the `data` payload of `GET /auth/me`, and re-serialises it for
/// the secure-storage cache so a cold start can render the shell offline.
class AuthProfileModel extends AuthProfile {
  const AuthProfileModel({
    required super.id,
    required super.employeeId,
    required super.email,
    required super.fullName,
    super.roles,
    super.permissions,
    super.featureFlags,
    super.territoryCode,
    super.depotCode,
    super.language,
    super.timeZone,
    super.theme,
    super.passwordExpiresAt,
    super.company,
    super.avatarUrl,
    super.phoneNumber,
    super.position,
    super.department,
    super.lastLoginAt,
    super.passwordChangeRequired,
    super.khmerName,
    super.temporaryPasswordExpiresAt,
    super.lineManagerName,
    super.lineManagerCode,
    super.avatarThumbnailUrl,
  });

  /// [json] is the **unwrapped** payload — pass `envelope.data`, not the whole
  /// response body.
  factory AuthProfileModel.fromJson(DataMap json) => AuthProfileModel(
        // The live API sends `userId`; `id` is accepted as a fallback because
        // the wrapped envelope examples in the guide use it. Reading only
        // `id` left every profile with an empty identifier.
        id: (json['userId'] ?? json['id'] ?? json['user_id'])?.toString() ?? '',
        // `/auth/me` sends `empCode`; `/mobile/auth/profile` `employeeCode`.
        employeeId: (json['employeeId'] ??
                    json['empCode'] ??
                    json['employeeCode'] ??
                    json['employee_id'])
                ?.toString() ??
            '',
        email: json['email'] as String? ?? '',
        // `/auth/me` sends `englishName`.
        fullName: (json['fullName'] ??
                json['englishName'] ??
                json['full_name'] ??
                json['name']) as String? ??
            '',
        // `/mobile/auth/profile` sends one `role` display name; `/auth/me`
        // sends no role at all, only `isAdmin`.
        roles: _roles(json['roles'] ??
            (json['role'] is String
                ? [json['role']]
                : (json['isAdmin'] == true ? ['admin'] : null))),
        permissions: _stringSet(json['permissions']),
        // An absent map means "no flags", which `flag()` then reads as off.
        featureFlags: _flags(json['featureFlags'] ?? json['feature_flags']),
        territoryCode: json['territoryCode'] as String?,
        // The live API sends `depotCode`; `customerCode` is the pre-rename
        // spelling, and what profiles cached by older builds carry.
        depotCode: (json['depotCode'] ?? json['customerCode']) as String?,
        language: json['language'] as String?,
        timeZone: json['timeZone'] as String?,
        theme: json['theme'] as String?,
        passwordExpiresAt: parseUtc(json['passwordExpiresAt']),
        company: json['company'] as String?,
        // `/mobile/auth/profile` sends `profilePhotoUrl` — a signed URL that
        // loads without a token until it expires.
        avatarUrl: (json['avatarUrl'] ??
            json['profilePhotoUrl'] ??
            json['avatar_url']) as String?,
        avatarThumbnailUrl: (json['avatarThumbnailUrl'] ??
            json['profilePhotoThumbnailUrl']) as String?,
        phoneNumber: (json['phoneNumber'] ??
            json['phone_number'] ??
            json['phone']) as String?,
        // The mobile profile has no HR job title, only the `role` display
        // name ("Sales Representative") — the best label for the job there is.
        position: (json['position'] ?? json['role']) as String?,
        department: json['department'] as String?,
        lastLoginAt: parseUtc(json['lastLoginAt']),
        passwordChangeRequired: json['passwordChangeRequired'] == true,
        khmerName: json['khmerName'] as String?,
        temporaryPasswordExpiresAt:
            parseUtc(json['temporaryPasswordExpiresAt']),
        lineManagerName: _lineManager(json, 'englishName'),
        lineManagerCode: _lineManager(json, 'empCode'),
      );

  static String? _lineManager(DataMap json, String key) {
    final manager = json['lineManager'];
    if (manager is! Map) return null;
    final value = manager[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  /// The same profile with [passwordChangeRequired] replaced — set from the
  /// login response, cleared once the rep has chosen their own password.
  AuthProfileModel copyWithPasswordChangeRequired(bool value) =>
      AuthProfileModel(
        id: id,
        employeeId: employeeId,
        email: email,
        fullName: fullName,
        roles: roles,
        permissions: permissions,
        featureFlags: featureFlags,
        territoryCode: territoryCode,
        depotCode: depotCode,
        language: language,
        timeZone: timeZone,
        theme: theme,
        passwordExpiresAt: passwordExpiresAt,
        company: company,
        avatarUrl: avatarUrl,
        phoneNumber: phoneNumber,
        position: position,
        department: department,
        lastLoginAt: lastLoginAt,
        passwordChangeRequired: value,
        khmerName: khmerName,
        lineManagerName: lineManagerName,
        lineManagerCode: lineManagerCode,
        avatarThumbnailUrl: avatarThumbnailUrl,
        // Meaningless once the rep has chosen their own password.
        temporaryPasswordExpiresAt: value ? temporaryPasswordExpiresAt : null,
      );

  DataMap toJson() => {
        'id': id,
        'employeeId': employeeId,
        'email': email,
        'fullName': fullName,
        'roles': roles.map((e) => e.name).toList(),
        'permissions': permissions.toList(),
        'featureFlags': featureFlags,
        'territoryCode': territoryCode,
        'depotCode': depotCode,
        'language': language,
        'timeZone': timeZone,
        'theme': theme,
        'passwordExpiresAt': passwordExpiresAt?.toIso8601String(),
        'company': company,
        'avatarUrl': avatarUrl,
        'avatarThumbnailUrl': avatarThumbnailUrl,
        'phoneNumber': phoneNumber,
        'position': position,
        'department': department,
        'lastLoginAt': lastLoginAt?.toIso8601String(),
        'passwordChangeRequired': passwordChangeRequired,
        'khmerName': khmerName,
        'temporaryPasswordExpiresAt':
            temporaryPasswordExpiresAt?.toIso8601String(),
        if (lineManagerName != null || lineManagerCode != null)
          'lineManager': {
            'englishName': lineManagerName,
            'empCode': lineManagerCode,
          },
      };

  /// Roles arrive as **human-readable display names**, not enum identifiers:
  /// the live API sends `"Sales Representative"`, not `salesRep`.
  ///
  /// So matching is done on a normalised form — lowercased with every
  /// non-alphanumeric character removed — plus an explicit alias table for the
  /// names that are not merely a spacing or casing variant. Stripping only
  /// underscores was not enough: `"Sales Representative"` kept its space,
  /// matched nothing, and a sales representative signed in holding **no roles
  /// at all**, silently hiding every role-gated action in the app.
  ///
  /// An unrecognised role is dropped rather than thrown on — a server may add
  /// one this build has never heard of, and the app degrades to the permission
  /// set, which is the authoritative half anyway.
  static Set<UserRole> _roles(Object? raw) {
    if (raw is! List) return const {};
    return raw
        .map((e) => _roleAliases[_normaliseRole('$e')])
        .whereType<UserRole>()
        .toSet();
  }

  static String _normaliseRole(String raw) =>
      raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Keyed by [_normaliseRole] output. Enum names are registered automatically
  /// so a future `UserRole` value works without touching this table; the
  /// entries below cover the display names the server actually sends.
  static final Map<String, UserRole> _roleAliases = {
    for (final role in UserRole.values) _normaliseRole(role.name): role,
    'salesrepresentative': UserRole.salesRep,
    'salesrep': UserRole.salesRep,
    'sales': UserRole.salesRep,
    'salesmanager': UserRole.manager,
    'manager': UserRole.manager,
    'administrator': UserRole.admin,
    'systemadministrator': UserRole.admin,
    'admin': UserRole.admin,
    'guest': UserRole.guest,
  };

  static Set<String> _stringSet(Object? raw) =>
      raw is List ? raw.map((e) => e.toString()).toSet() : const {};

  static Map<String, bool> _flags(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        entry.key.toString(): entry.value == true,
    };
  }
}
