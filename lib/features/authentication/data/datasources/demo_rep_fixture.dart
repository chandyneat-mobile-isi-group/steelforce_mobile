// TODO(release-gate): demo-only data source; must never be registered in a release mobile build (USE_MOCK_DATA=false).
import 'package:steelforce/features/authentication/data/models/auth_profile_model.dart';
import 'package:steelforce/features/authentication/data/models/auth_token_model.dart';
import 'package:steelforce/features/authentication/domain/entities/auth_profile.dart';
import 'package:steelforce/features/authentication/domain/entities/user_role.dart';

/// The single fictional rep every demo-mode data source signs in as.
///
/// These values are shared with the depot and visit mocks, so a demo
/// shows one consistent person across every screen. Nobody here is real.
abstract final class DemoRep {
  static const id = 'demo-rep-001';
  static const employeeCode = 'DEMO001';
  static const fullName = 'Sokha Chan';
  static const khmerName = 'ចាន់ សុខា';
  static const phoneNumber = '+855 12 000 001';
  static const email = 'sokha.demo@example.com';
  static const territoryCode = 'PP-01';
  static const territoryName = 'Phnom Penh';

  /// What a sales representative holds on the live backend. It covers both
  /// depot permission spellings, and leaves out the manager-only
  /// `readall`, `delete` and `approve`.
  static const permissions = {
    Permissions.depotsRead,
    Permissions.depotsCreate,
    Permissions.depotsUpdate,
    Permissions.outletsRead,
    Permissions.outletsCreate,
    Permissions.outletsUpdate,
  };

  /// The profile `/mobile/auth/profile` would return for the demo rep.
  /// [lastLoginAt] is passed in so the profile screen shows the real
  /// sign-in time of this demo session.
  static AuthProfileModel profile({DateTime? lastLoginAt}) => AuthProfileModel(
        id: id,
        employeeId: employeeCode,
        email: email,
        fullName: fullName,
        khmerName: khmerName,
        roles: const {UserRole.salesRep},
        permissions: permissions,
        territoryCode: territoryCode,
        language: 'en',
        timeZone: 'Asia/Phnom_Penh',
        company: 'SteelForce Demo',
        phoneNumber: phoneNumber,
        position: 'Sales Representative',
        department: 'Field Sales — $territoryName',
        lastLoginAt: lastLoginAt,
        lineManagerName: 'Demo Manager',
        lineManagerCode: 'DEMO000',
        salesOrgCode: 'DEMO',
        salesOrgName: 'Demo Sales Org',
      );

  /// A new opaque token pair. Nothing in the app decodes a token (no JWT
  /// parsing anywhere). The interceptor only attaches it, and the session is
  /// decided by the cached profile. So an opaque string is enough. The
  /// counter makes each pair distinct, the way a real rotation is.
  static AuthTokenModel issueTokens() {
    _issued++;
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    return AuthTokenModel(
      accessToken: 'demo-access-$stamp-$_issued',
      refreshToken: 'demo-refresh-$stamp-$_issued',
      expiresIn: 899,
    );
  }

  static int _issued = 0;
}
