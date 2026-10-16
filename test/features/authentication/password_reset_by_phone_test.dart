import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/platform/device/device_identity.dart';
import 'package:steelforce/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:steelforce/features/authentication/domain/entities/password_reset_grant.dart';

/// Password reset verifies the rep by **phone number** (SMS code), never by
/// e-mail. These pin the three requests against the staging contract:
/// `forgot-password/request` → `verify-otp` (returns `resetToken`) → `reset`.
class _MockDevice extends Mock implements DeviceIdentity {}

class _Recorder implements HttpClientAdapter {
  _Recorder(this.reply);

  final ResponseBody Function(RequestOptions) reply;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return reply(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  late _Recorder adapter;
  late AuthRemoteDataSourceImpl remote;

  void build(ResponseBody Function(RequestOptions) reply) {
    adapter = _Recorder(reply);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    remote = AuthRemoteDataSourceImpl(
      authedClient: dio,
      bareClient: dio,
      device: _MockDevice(),
    );
  }

  test('step 1 asks for an SMS code by phone number, no e-mail', () async {
    build((_) => _json({
          'success': true,
          'data': {'expiresIn': 300, 'codeLength': 6},
        }));

    await remote.forgotPassword(' 012 345 201 ');

    final req = adapter.requests.single;
    expect(req.path, '/api/v1/auth/forgot-password/request');
    expect(req.data, {
      'recoveryMethod': 'phone',
      'phoneNumber': '012 345 201',
    });
  });

  test('step 2 trades the code for the reset token and policy', () async {
    build((_) => _json({
          'success': true,
          'data': {
            'resetToken': 'rt-1',
            'expiresIn': 600,
            'passwordPolicy': {
              'minLength': 8,
              'maxLength': 64,
              'requireUppercase': true,
              'requireLowercase': true,
              'requireNumber': true,
              'requireSpecial': true,
            },
          },
        }));

    final grant = await remote.verifyResetCode(
        phoneNumber: '+85512345209', otp: '123456');

    expect(grant.resetToken, 'rt-1');
    expect(grant.expiresIn, 600);
    expect(
      grant.policy,
      const PasswordPolicy(
        minLength: 8,
        maxLength: 64,
        requireUppercase: true,
        requireLowercase: true,
        requireNumber: true,
        requireSpecial: true,
      ),
    );
    final req = adapter.requests.single;
    expect(req.path, '/api/v1/auth/forgot-password/verify-otp');
    expect(req.data, {
      'recoveryMethod': 'phone',
      'phoneNumber': '+85512345209',
      'otp': '123456',
    });
  });

  test('step 2 refuses a success that carries no token', () async {
    build((_) => _json({'success': true, 'data': <String, dynamic>{}}));

    expect(
      () => remote.verifyResetCode(phoneNumber: '012345201', otp: '123456'),
      throwsA(isA<ApiException>()),
    );
  });

  test('step 2 surfaces a wrong code as an ApiException', () async {
    build((_) => _json({
          'success': false,
          'error': {
            'code': 'AUTH_INVALID_OTP',
            'message': 'The code is incorrect.',
            'details': {'attemptsRemaining': 4},
          },
        }, 400));

    expect(
      () => remote.verifyResetCode(phoneNumber: '012345201', otp: '000000'),
      throwsA(isA<ApiException>()),
    );
  });

  test('no step goes under /mobile/ — the rep has no token yet', () {
    for (final path in [
      ApiEndpoints.sendOtpEndpoint,
      ApiEndpoints.verifyOtpEndpoint,
      ApiEndpoints.resetOtpEndpoint,
    ]) {
      expect(path, isNot(contains('/mobile/')));
      expect(ApiEndpoints.authRoutes, contains(path));
    }
  });

  group('PasswordPolicy', () {
    const policy = PasswordPolicy(
      minLength: 8,
      maxLength: 16,
      requireUppercase: true,
      requireLowercase: true,
      requireNumber: true,
      requireSpecial: true,
    );

    test('reports the first broken rule, in order', () {
      expect(policy.firstViolation('Ab1!'), PasswordRule.minLength);
      expect(
          policy.firstViolation('Abcdefgh1!xxxxxxx'), PasswordRule.maxLength);
      expect(policy.firstViolation('abcdefg1!'), PasswordRule.uppercase);
      expect(policy.firstViolation('ABCDEFG1!'), PasswordRule.lowercase);
      expect(policy.firstViolation('Abcdefgh!'), PasswordRule.number);
      expect(policy.firstViolation('Abcdefg12'), PasswordRule.special);
      expect(policy.firstViolation('Abcdef1!'), isNull);
    });

    test('an empty policy accepts anything', () {
      expect(const PasswordPolicy().firstViolation(''), isNull);
    });
  });

  test('step 3 sets the password with the token', () async {
    build((_) => _json({
          'success': true,
          'data': {'message': 'ok'},
        }));

    await remote.resetPassword(resetToken: 'rt-1', newPassword: 'NewPass123!');

    final req = adapter.requests.single;
    expect(req.path, '/api/v1/auth/forgot-password/reset');
    expect(req.data, {
      'resetToken': 'rt-1',
      'newPassword': 'NewPass123!',
      'confirmPassword': 'NewPass123!',
    });
  });
}
