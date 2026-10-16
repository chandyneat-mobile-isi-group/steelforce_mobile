import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/network/api/api_error.dart';

/// The API answers in two different error dialects depending on the endpoint,
/// and conflating them is the integration mistake the guide calls out first.
void main() {
  group('OAuth errors (auth endpoints)', () {
    test('takes the stable code from the error_uri, not the OAuth token', () {
      // `invalid_grant` is RFC 6749's generic "grant rejected" token and says
      // nothing about *why*. The platform code in the URI is what the app can
      // branch on and localise from.
      final error = ApiError.fromBody({
        'error': 'invalid_grant',
        'error_description': 'The e-mail address or password is incorrect.',
        'error_uri':
            'https://docs.isigroup.com.kh/errors/Auth.InvalidCredentials',
      }, statusCode: 400);

      expect(error.code, ApiErrorCodes.invalidCredentials);
      expect(error.statusCode, 400);
    });

    test('falls back to the OAuth token when no error_uri is sent', () {
      final error = ApiError.fromBody(
        {'error': 'invalid_client'},
        statusCode: 400,
      );

      expect(error.code, 'invalid_client');
    });

    test('a rejected login is 400 and never reads as unauthenticated', () {
      // RFC 6749 §5.2 mandates 400 for a rejected grant. If this were treated
      // as a 401 the interceptor would try to refresh, burning a rotation and
      // potentially spending one of the five attempts that lock the account.
      final error = ApiError.fromBody({
        'error': 'invalid_grant',
        'error_uri':
            'https://docs.isigroup.com.kh/errors/Auth.InvalidCredentials',
      }, statusCode: 400);

      expect(error.isUnauthenticated, isFalse);
      expect(error.isPermissionDenied, isFalse);
    });
  });

  group('RFC 9457 problem documents (everything else)', () {
    test('branches on errorCode and keeps detail out of user-facing text', () {
      final error = ApiError.fromBody({
        'type': 'https://docs.isigroup.com.kh/errors/Depot.NotFound',
        'title': 'The requested resource was not found.',
        'status': 404,
        'detail': "No depot was found with identifier '…'.",
        'errorCode': 'Depot.NotFound',
        'correlationId': '0HNNOE4PB87QD:00000001',
      });

      expect(error.code, ApiErrorCodes.depotNotFound);
      expect(error.statusCode, 404);
      expect(error.correlationId, '0HNNOE4PB87QD:00000001');
      // `title` is server-localised and safe to show; `detail` is English and
      // belongs in logs.
      expect(error.message, 'The requested resource was not found.');
      expect(error.detail, isNot(error.message));
    });

    test('reads the per-field errors map on a validation failure', () {
      final error = ApiError.fromBody({
        'errorCode': 'General.Validation',
        'status': 400,
        'errors': {
          'parameters.modifiedSince': [
            'modifiedSince cannot be in the future.',
          ],
        },
      });

      expect(error.isValidation, isTrue);
      // Matched on the trailing segment, because the server prefixes query
      // parameters but the caller thinks in plain field names.
      expect(error.fieldError('modifiedSince'),
          'modifiedSince cannot be in the future.');
    });

    test('recovers the code from `type` when errorCode is absent', () {
      final error = ApiError.fromBody({
        'type': 'https://docs.isigroup.com.kh/errors/Depot.Closed',
        'status': 422,
      });

      expect(error.code, ApiErrorCodes.depotClosed);
    });
  });

  group('403 is not 401', () {
    test('a permission denial never reads as an expired session', () {
      // Signing the user out on a 403 and showing a login screen is wrong and
      // confusing: they are authenticated, they simply may not do this.
      final error = ApiError.fromBody(
        {'errorCode': 'Auth.PermissionDenied', 'status': 403},
      );

      expect(error.isPermissionDenied, isTrue);
      expect(error.isUnauthenticated, isFalse);
    });

    test('a 401 is the only thing that reads as unauthenticated', () {
      final error = ApiError.fromBody(
        {'errorCode': 'Auth.NotAuthenticated', 'status': 401},
      );

      expect(error.isUnauthenticated, isTrue);
      expect(error.isPermissionDenied, isFalse);
    });
  });

  test('a non-JSON body degrades instead of throwing', () {
    // A gateway timeout page or an HTML error is not a reason to crash.
    final error = ApiError.fromBody('<html>502</html>', statusCode: 502);

    expect(error.code, ApiErrorCodes.unknown);
    expect(error.statusCode, 502);
  });
}
