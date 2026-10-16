import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/features/authentication/data/models/auth_profile_model.dart';
import 'package:steelforce/features/authentication/domain/entities/user_role.dart';

/// `GET /api/v1/auth/me` — the `data` of the live response, mapped onto the
/// app's profile.
void main() {
  const me = {
    'id': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
    'email': 'rep@isigroup.com.kh',
    'englishName': 'Sok Dara',
    'khmerName': 'សុខ ដារ៉ា',
    'empCode': 'EMP000202',
    'phone': '+85512345209',
    'passwordChangeRequired': true,
    'temporaryPasswordExpiresAt': '2026-10-07T06:23:57.624Z',
    'lastLoginAt': '2026-10-07T06:23:57.624Z',
    'lineManager': {
      'id': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
      'empCode': 'EMP000001',
      'englishName': 'Manager',
    },
    'isAdmin': false,
  };

  test('the profile is read from /api/v1/auth/me', () {
    expect(ApiEndpoints.currentUserEndpoint, '/api/v1/auth/me');
  });

  test('maps every field the app uses', () {
    final p = AuthProfileModel.fromJson(me);
    expect(p.id, '3fa85f64-5717-4562-b3fc-2c963f66afa6');
    expect(p.email, 'rep@isigroup.com.kh');
    expect(p.fullName, 'Sok Dara');
    expect(p.khmerName, 'សុខ ដារ៉ា');
    expect(p.employeeId, 'EMP000202');
    expect(p.phoneNumber, '+85512345209');
    expect(p.passwordChangeRequired, isTrue);
    expect(p.temporaryPasswordExpiresAt,
        DateTime.utc(2026, 10, 7, 6, 23, 57, 624));
    expect(p.lastLoginAt, DateTime.utc(2026, 10, 7, 6, 23, 57, 624));
    expect(p.roles, isEmpty);
  });

  test('isAdmin becomes the admin role', () {
    final p = AuthProfileModel.fromJson({...me, 'isAdmin': true});
    expect(p.roles, {UserRole.admin});
  });

  test('survives the secure-storage cache round trip', () {
    final p = AuthProfileModel.fromJson(me);
    final restored = AuthProfileModel.fromJson(p.toJson());
    expect(restored.khmerName, p.khmerName);
    expect(restored.temporaryPasswordExpiresAt, p.temporaryPasswordExpiresAt);
    expect(restored.passwordChangeRequired, isTrue);
  });

  test('clearing the flag also drops the temporary-password expiry', () {
    final p =
        AuthProfileModel.fromJson(me).copyWithPasswordChangeRequired(false);
    expect(p.temporaryPasswordExpiresAt, isNull);
    expect(p.khmerName, 'សុខ ដារ៉ា');
  });
}
