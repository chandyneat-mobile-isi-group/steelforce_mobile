import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/authentication/presentation/screens/forgot_password_screen.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/phone_number_field.dart';
import 'package:phone_form_field/phone_form_field.dart';

/// `ForgotPasswordScreen` used to navigate to `Static.verifyOtp` internally
/// AND its `onSubmit` caller (in `app_page.dart`) navigated there a second
/// time with a bare `String` argument — which the route now casts as
/// `VerifyOtpArgs?`. That double navigation crashed with a `TypeError` the
/// instant a reset request succeeded.
///
/// Driving that regression end-to-end needs a real keystroke into
/// `PhoneFormField`'s internals, which does not reliably sync in this test
/// harness — the same flakiness that made an earlier `PhoneNumberField`
/// widget test hang for several minutes and get dropped rather than fixed. So
/// this only pins the structural half: the screen offers a single phone
/// field with no e-mail path, not the interactive submit. The actual
/// regression is exercised by hand on-device.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  testWidgets('takes a phone number, not an email/phone toggle',
      (tester) async {
    // The screen used to offer `IdentifierField`, a switcher between e-mail
    // and phone. The sales app has no e-mail identity path, so that switcher
    // is gone — this is the same `PhoneNumberField` the login screen uses,
    // and there is exactly one of it.
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          localizationsDelegates: PhoneFieldLocalization.delegates,
          home: ForgotPasswordScreen(
            onSubmit: (_) async => const ForgotPasswordResult.success(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PhoneNumberField), findsOneWidget);
    expect(find.byType(PhoneFormField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
