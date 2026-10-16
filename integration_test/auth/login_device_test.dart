import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/app.dart';
import 'package:steelforce/core/bootstrap/app_bootstrap_service.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_event.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_state.dart';
import 'package:steelforce/features/authentication/presentation/screens/login_screen.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/gradient_button.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/phone_number_field.dart';
import 'package:steelforce/routes/app_routes.dart';

import '../support/automation_harness.dart';

/// TC-AUTH-002 on a real device or simulator, against the backend selected
/// with `--dart-define=API_BASE_URL`. The account comes from `QA_PHONE` /
/// `QA_PASSWORD` dart-defines, which the automation framework fills from the
/// environment's secrets — they are never written to a file.
///
/// The app is booted the way `main.dart` boots it, minus the process-wide
/// error handlers, which the test framework owns while a test runs.
const _phone = String.fromEnvironment('QA_PHONE');
const _password = String.fromEnvironment('QA_PASSWORD');

AuthBloc _authBloc() => navigatorKey.currentContext!.read<AuthBloc>();

void main() {
  ensureAutomationBinding();

  setUpAll(() => const AppBootstrapService().run());

  automationTest('a field rep signs in with phone and password',
      (tester) async {
    if (_phone.isEmpty || _password.isEmpty) {
      fail('QA_PHONE / QA_PASSWORD were not passed as --dart-define.');
    }
    await tester.pumpWidget(const ISISteelSalesApp());
    await pumpUntil(tester, () => navigatorKey.currentContext != null,
        reason: 'the app to build its navigator');

    // A session left over from an earlier run is ended first, so the test
    // always exercises a real sign-in.
    if (_authBloc().state is AuthenticatedState) {
      _authBloc().add(const LogoutRequested());
      await pumpUntil(tester, () => _authBloc().state is! AuthenticatedState,
          reason: 'the previous session to end');
    }

    navigatorKey.currentState!
        .pushNamedAndRemoveUntil(Static.login, (_) => false);
    await pumpUntil(
        tester, () => find.byType(LoginScreen).evaluate().isNotEmpty,
        reason: 'the login screen');
    await tester.pump(const Duration(milliseconds: 600));
    await captureScreen(tester, 'login-screen');

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
    await tester.tap(find.byType(GradientButton));

    await pumpUntil(
      tester,
      () =>
          _authBloc().state is AuthenticatedState ||
          _authBloc().state is AuthFailureState,
      reason: 'the sign-in to finish',
    );
    await tester.pump(const Duration(seconds: 2));
    await captureScreen(tester, 'after-sign-in');

    final state = _authBloc().state;
    expect(state, isA<AuthenticatedState>(),
        reason: state is AuthFailureState
            ? 'Sign-in refused: ${state.message}'
            : 'Sign-in did not complete.');
    expect(find.byType(LoginScreen), findsNothing,
        reason: 'A signed-in rep must leave the login screen.');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
