import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/app.dart';
import 'package:steelforce/core/bootstrap/app_bootstrap_service.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/features/authentication/data/datasources/auth_local_data_source.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_event.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_state.dart';
import 'package:steelforce/features/authentication/presentation/screens/login_screen.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/gradient_button.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/phone_number_field.dart';
import 'package:steelforce/routes/app_routes.dart';

import '../support/automation_harness.dart';

/// TC-AUTH-018 on a device: the real login succeeds against the backend, then
/// the profile read (`/auth/me`) fails. The app must wipe the tokens it just
/// saved, show the failure and keep the rep signed out — never a half-open
/// session that boots into an empty shell.
///
/// A backend cannot be made to fail on cue, so this test answers `/auth/me`
/// with a 503 from inside the app's own HTTP client. The fault is added only
/// in this test and removed after it; the app code is unchanged.
const _phone = String.fromEnvironment('QA_PHONE');
const _password = String.fromEnvironment('QA_PASSWORD');

AuthBloc _authBloc() => navigatorKey.currentContext!.read<AuthBloc>();

/// Rejects the profile read with a server error, as an unhealthy backend would.
class _ProfileReadFails extends Interceptor {
  int hits = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!options.path.endsWith(ApiEndpoints.currentUserEndpoint)) {
      return handler.next(options);
    }
    hits++;
    noteInjectedResponse(options.method, options.path, 503);
    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<Map<String, dynamic>>(
          requestOptions: options,
          statusCode: 503,
          data: {
            'success': false,
            'error': {'code': 'Test.ProfileUnavailable'},
          },
        ),
      ),
      true, // still logged as api.error by the app's own interceptors
    );
  }
}

void main() {
  ensureAutomationBinding();

  setUpAll(() => const AppBootstrapService().run());

  automationTest('a profile read failing after login leaves the rep signed out',
      (tester) async {
    if (_phone.isEmpty || _password.isEmpty) {
      fail('QA_PHONE / QA_PASSWORD were not passed as --dart-define.');
    }
    await tester.pumpWidget(const ISISteelSalesApp());
    await pumpUntil(tester, () => navigatorKey.currentContext != null,
        reason: 'the app to build its navigator');

    if (_authBloc().state is AuthenticatedState) {
      _authBloc().add(const LogoutRequested());
      await pumpUntil(tester, () => _authBloc().state is! AuthenticatedState,
          reason: 'the previous session to end');
    }

    final fault = _ProfileReadFails();
    final client = GetIt.instance<Dio>();
    client.interceptors.add(fault);
    addTearDown(() => client.interceptors.remove(fault));

    navigatorKey.currentState!
        .pushNamedAndRemoveUntil(Static.login, (_) => false);
    await pumpUntil(
        tester, () => find.byType(LoginScreen).evaluate().isNotEmpty,
        reason: 'the login screen');
    await tester.pump(const Duration(milliseconds: 600));
    await captureScreen(tester, '1-login-screen');

    await tester.enterText(
      find.descendant(
        of: find.byType(PhoneNumberField),
        matching: find.byType(EditableText),
      ),
      _phone,
    );
    await tester.enterText(
      find.byWidgetPredicate((w) => w is EditableText && w.obscureText),
      _password,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await captureScreen(tester, '2-form-filled');
    await tester.tap(find.byType(GradientButton));
    await tester.pump(const Duration(milliseconds: 150));
    await captureScreen(tester, '3-signing-in');

    await pumpUntil(
      tester,
      () =>
          _authBloc().state is AuthFailureState ||
          _authBloc().state is AuthenticatedState,
      reason: 'the sign-in to finish',
    );
    await tester.pump(const Duration(seconds: 2));
    await captureScreen(tester, '4-profile-read-failed');

    // The profile is only read after the login call succeeded, so a hit here
    // proves the credentials were accepted and the failure is the second step.
    expect(fault.hits, greaterThan(0),
        reason: 'Login did not succeed, so /auth/me was never called — '
            'this run cannot judge TC-AUTH-018 (check the account).');
    expect(_authBloc().state, isA<AuthFailureState>(),
        reason: 'A failed profile read must surface as a sign-in failure.');
    expect(find.byType(LoginScreen), findsOneWidget,
        reason: 'The rep must stay on the login screen.');

    final tokens = GetIt.instance<AuthLocalDataSourceImpl>();
    expect(await tokens.readAccessToken(), isNull,
        reason:
            'The access token saved before the profile read must be wiped.');
    expect(await tokens.readRefreshToken(), isNull,
        reason: 'The refresh token must be wiped too — no half-open session.');

    // Signed out for good: the login screen is still what the rep sees.
    await tester.pump(const Duration(seconds: 1));
    await captureScreen(tester, '5-still-signed-out');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
