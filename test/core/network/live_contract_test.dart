import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/authentication/data/models/auth_profile_model.dart';
import 'package:steelforce/features/authentication/data/models/auth_token_model.dart';
import 'package:steelforce/features/authentication/domain/entities/user_role.dart';

/// Payloads captured verbatim from the running API, not written from the guide.
///
/// The guide is close to the server but not identical to it, and two of the
/// differences below were real defects that no doc-derived fixture would have
/// caught: `/auth/me` returns `userId` rather than `id`, and roles arrive as
/// display names (`"Sales Representative"`) rather than enum identifiers.
void main() {
  group('POST /auth/login — raw OAuth, not wrapped', () {
    // Verbatim, truncated only in the token bodies.
    final response = {
      'access_token': 'eyJhbGciOiJSUzI1NiIsImtpZCI6IkVCQjI5OTk5',
      'token_type': 'Bearer',
      'expires_in': 900,
      'id_token': 'eyJhbGciOiJSUzI1NiIsImtpZCI6IkVCQjI5OTk5',
      'refresh_token': 'eyJhbGciOiJSU0EtT0FFUCIsImVuYyI6IkEyNTZD',
    };

    test('parses without an envelope', () {
      final token = AuthTokenModel.fromMap(response);

      expect(token.accessToken, isNotEmpty);
      expect(token.refreshToken, isNotEmpty);
      expect(token.expiresIn, 900);
      expect(token.tokenType, 'Bearer');
    });
  });

  group('GET /auth/me — wrapped', () {
    final profile = AuthProfileModel.fromJson(const {
      'userId': '019fefd2-1111-4a7f-b0d2-1f9e4c8a2b31',
      'employeeId': 'EMP000202',
      'fullName': 'Sales Rep',
      'email': 'rep@isigroup.com.kh',
      // Display names, with a space — not `salesRep`.
      'roles': ['Sales Representative'],
      'permissions': ['outlets.read', 'visits.create'],
      'territoryCode': 'PP-NORTH',
      'depotCode': 'DEPOT-PP01',
      'language': 'en',
      'theme': 'light',
    });

    test('reads the identifier from userId', () {
      // Reading only `id` left every profile with an empty identifier.
      expect(profile.id, '019fefd2-1111-4a7f-b0d2-1f9e4c8a2b31');
    });

    test('resolves a display-name role to the enum', () {
      // Matching on underscore-stripped names alone left a sales rep holding
      // no roles at all, silently hiding every role-gated action.
      expect(profile.roles, {UserRole.salesRep});
    });

    test('an unknown role is dropped, not thrown on', () {
      final future = AuthProfileModel.fromJson(const {
        'userId': 'x',
        'roles': ['Regional Director', 'Sales Representative'],
      });

      expect(future.roles, {UserRole.salesRep},
          reason: 'a newer server must not crash an older client');
    });
  });

  group('GET /mobile/depots — envelope', () {
    final body = {
      'success': true,
      'message': 'Depots retrieved successfully.',
      'data': {
        'depots': [<String, dynamic>{}, <String, dynamic>{}],
        'syncTimestamp': '2026-08-13T01:28:35.4974802+00:00',
      },
      'metadata': {
        'page': 1,
        'pageSize': 2,
        'totalRecords': 10,
        'totalPages': 5,
        'hasNextPage': true,
        'hasPreviousPage': false,
        'syncTimestamp': '2026-08-13T01:28:35.4974802+00:00',
        'isDeltaSync': false,
      },
      'traceId': '0HNNOQUJEES2Q:00000013',
      'timestamp': '2026-08-13T01:28:35Z',
    };

    test('metadata parses, including the 7-digit fractional timestamp', () {
      final envelope = ApiEnvelope.fromBody(body);
      final meta = envelope.metadata!;

      expect(meta.page, 1);
      // Read back rather than assumed — the server clamps silently.
      expect(meta.pageSize, 2);
      expect(meta.totalRecords, 10);
      expect(meta.hasNextPage, isTrue);
      expect(meta.isDeltaSync, isFalse);
      expect(meta.syncTimestamp?.isUtc, isTrue,
          reason: 'the watermark must be comparable as UTC');
    });
  });

  group('problem documents', () {
    test('a framework 403 yields a branchable code, not a spec fragment', () {
      // ASP.NET answers a bare 403 with no errorCode and a `type` pointing at
      // the RFC. Mining the last path segment produced the "code"
      // `rfc9110#section-15.5.4`, which matches nothing and misleads in a log.
      final error = ApiError.fromBody(const {
        'type': 'https://tools.ietf.org/html/rfc9110#section-15.5.4',
        'title': 'Forbidden',
        'status': 403,
        'instance': '/api/v1/mobile/depots',
        'traceId': '00-db7ae633051b152d-80d9819e7c9e8f47-00',
        'correlationId': '0HNNOQUJEES2Q:00000013',
      });

      expect(error.code, ApiErrorCodes.permissionDenied);
      expect(error.isPermissionDenied, isTrue);
      // A 403 must never sign the user out — it means "never allowed", not
      // "token stale".
      expect(error.isUnauthenticated, isFalse);
      expect(error.correlationId, '0HNNOQUJEES2Q:00000013');
    });

    test('a platform error URL still yields its code', () {
      final error = ApiError.fromBody(const {
        'type': 'https://docs.isigroup.com.kh/errors/Depot.NotFound',
        'title': 'The requested resource was not found.',
        'status': 404,
      });

      expect(error.code, ApiErrorCodes.depotNotFound);
    });

    test('a rejected login is OAuth-shaped at HTTP 400', () {
      // Verbatim from the running API.
      final error = ApiError.fromBody(const {
        'error': 'invalid_grant',
        'error_description': 'The e-mail address or password is incorrect.',
        'error_uri':
            'https://docs.isigroup.com.kh/errors/Auth.InvalidCredentials',
      }, statusCode: 400);

      expect(error.code, ApiErrorCodes.invalidCredentials);
      // RFC 6749 mandates 400 for a rejected grant, so this must not be
      // mistaken for a stale token and trigger a refresh.
      expect(error.isUnauthenticated, isFalse);
    });
  });
}
