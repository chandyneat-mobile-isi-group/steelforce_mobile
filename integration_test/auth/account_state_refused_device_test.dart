import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/app.dart';
import 'package:steelforce/core/bootstrap/app_bootstrap_service.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/features/authentication/authentication_injection.dart';
import 'package:steelforce/features/authentication/data/datasources/auth_local_data_source.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_event.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_state.dart';
import 'package:steelforce/features/authentication/presentation/screens/login_screen.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/gradient_button.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/phone_number_field.dart';
import 'package:steelforce/routes/app_routes.dart';

import '../support/automation_harness.dart';

/// TC-AUTH-005 on a device: a locked, inactive or expired-password account is
/// refused, the status pill shows **the server's text**, and the rep stays on
/// the login screen with no tokens stored.
///
/// The refusal is answered inside the app's HTTP client, so no real account is
/// needed and none can be locked; the phone and password typed are dummies.
/// Each state is sent in two shapes:
///
///  * **documented** — the RFC 9457 problem document with `errorCode`
///    (`docs/feature/authentication/integration-guide.md`);
///  * **staging** — the envelope the staging backend actually returns today,
///    `{"success":false,"error":{"code","message","traceId"}}` (observed
///    2026-10-08 for a refused login). Staging's exact codes for these three
///    states are not confirmed, so the codes there follow its observed
///    `AUTH_INVALID_CREDENTIALS` naming.

class _Refusal {
  const _Refusal(this.name, this.status, this.body, this.serverText);
  final String name;
  final int status;
  final Map<String, dynamic> body;
  final String serverText;
}

Map<String, dynamic> _documented(String code, String text) => {
      'type': 'https://docs.isigroup.com.kh/errors/$code',
      'title': text,
      'status': 400,
      'errorCode': code,
      'correlationId': 'qa-automation',
    };

Map<String, dynamic> _staging(String code, String text) => {
      'success': false,
      'error': {
        'code': code,
        'message': text,
        'traceId': 'qa-automation',
        'details': null,
      },
    };

const _locked = 'Your account is locked. Try again in 15 minutes.';
const _inactive = 'Your account is inactive. Contact your administrator.';
const _expired = 'Your password has expired. Please change it.';

final _refusals = [
  _Refusal('documented locked', 400, _documented('Auth.AccountLocked', _locked),
      _locked),
  _Refusal('documented inactive', 400,
      _documented('Auth.AccountInactive', _inactive), _inactive),
  _Refusal('documented password expired', 400,
      _documented('Auth.PasswordExpired', _expired), _expired),
  _Refusal(
      'staging locked', 400, _staging('AUTH_ACCOUNT_LOCKED', _locked), _locked),
  _Refusal('staging inactive', 400,
      _staging('AUTH_ACCOUNT_INACTIVE', _inactive), _inactive),
  _Refusal('staging password expired', 400,
      _staging('AUTH_PASSWORD_EXPIRED', _expired), _expired),
];

/// Answers the login call with [refusal], as the backend would.
class _LoginRefused extends Interceptor {
  _LoginRefused(this.refusal);
  final _Refusal refusal;
  int hits = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!options.path.endsWith(ApiEndpoints.loginEndpoint)) {
      return handler.next(options);
    }
    hits++;
    noteInjectedResponse(options.method, options.path, refusal.status);
    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<Map<String, dynamic>>(
          requestOptions: options,
          statusCode: refusal.status,
          data: refusal.body,
        ),
      ),
      true,
    );
  }
}

AuthBloc _authBloc() => navigatorKey.currentContext!.read<AuthBloc>();

String _slug(String s) => s.replaceAll(' ', '-');

void main() {
  ensureAutomationBinding();

  setUpAll(() => const AppBootstrapService().run());

  for (final refusal in _refusals) {
    automationTest('${refusal.name} account is refused with the server text',
        (tester) async {
      await tester.pumpWidget(const ISISteelSalesApp());
      await pumpUntil(tester, () => navigatorKey.currentContext != null,
          reason: 'the app to build its navigator');
      if (_authBloc().state is AuthenticatedState) {
        _authBloc().add(const LogoutRequested());
        await pumpUntil(tester, () => _authBloc().state is! AuthenticatedState,
            reason: 'the previous session to end');
      }

      final fault = _LoginRefused(refusal);
      final bare = GetIt.instance<Dio>(instanceName: bareClientName);
      bare.interceptors.add(fault);
      addTearDown(() => bare.interceptors.remove(fault));

      navigatorKey.currentState!
          .pushNamedAndRemoveUntil(Static.login, (_) => false);
      await pumpUntil(
          tester, () => find.byType(LoginScreen).evaluate().isNotEmpty,
          reason: 'the login screen');
      await tester.pump(const Duration(milliseconds: 600));

      // Dummy credentials: the request is answered before it leaves the phone.
      await tester.enterText(
        find.descendant(
          of: find.byType(PhoneNumberField),
          matching: find.byType(EditableText),
        ),
        '12000111',
      );
      await tester.enterText(
        find.byWidgetPredicate((w) => w is EditableText && w.obscureText),
        'Dummy-Pass-123',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byType(GradientButton));

      await pumpUntil(
        tester,
        () =>
            _authBloc().state is AuthFailureState ||
            _authBloc().state is AuthenticatedState,
        reason: 'the sign-in to finish',
      );
      await tester.pump(const Duration(seconds: 1));
      await captureScreen(tester, _slug(refusal.name));

      final state = _authBloc().state;
      expect(fault.hits, 1,
          reason: 'The login call must be made exactly once.');
      expect(state, isA<AuthFailureState>(),
          reason: 'A refused account must end as a sign-in failure.');
      expect(find.byType(LoginScreen), findsOneWidget,
          reason: 'The rep must stay on /login.');
      expect(await GetIt.instance<AuthLocalDataSourceImpl>().readAccessToken(),
          isNull,
          reason: 'A refused login must store no token.');
      expect(find.textContaining(refusal.serverText), findsOneWidget,
          reason: 'The status pill must show the server text '
              '"${refusal.serverText}"; the app showed '
              '"${state is AuthFailureState ? state.message : state}".');
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
