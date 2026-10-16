import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_event.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_state.dart';
import 'package:steelforce/features/authentication/presentation/screens/login_screen.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/gradient_button.dart';
import 'package:phone_form_field/phone_form_field.dart';

/// `LoginScreen` sets `resizeToAvoidBottomInset: false` so the full-bleed
/// building photo behind the form does not squash when the keyboard opens.
/// The cost of that choice is that nothing else resizes either: the form used
/// to stay centred in the *full* screen height and end up underneath the
/// keyboard, with the password field and the Sign In button unreachable.
///
/// Flutter's own "scroll the focused field into view" could not save it,
/// because the scrollable's viewport also still ran to the bottom of the
/// screen — so the field it was asked to reveal already counted as visible.
///
/// The fix is a `Padding` of `viewInsets.bottom` on the content layer only.
/// These tests pin the observable consequence rather than the widget that
/// produces it: with a keyboard-sized inset applied, the submit button must
/// still sit inside the visible area.
class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  /// A 390×844 phone with [keyboard] logical pixels of keyboard showing.
  Widget harness({required double keyboard}) {
    final bloc = _MockAuthBloc();
    whenListen(
      bloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthInitialState(),
    );
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        localizationsDelegates: PhoneFieldLocalization.delegates,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: BlocProvider<AuthBloc>.value(
            value: bloc,
            child: const LoginScreen(),
          ),
        ),
      ),
    );
  }

  testWidgets('submit button stays on screen while the keyboard is open',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 336 is a representative iOS keyboard height at this width.
    await tester.pumpWidget(harness(keyboard: 336));
    await tester.pumpAndSettle();

    final button = find.byType(GradientButton);
    expect(button, findsOneWidget);

    // The assertion that actually encodes the bug: the button's bottom edge
    // must clear the top of the keyboard (844 - 336 = 508). Before the fix it
    // sat at roughly the vertical centre of the *full* height, underneath it.
    final rect = tester.getRect(button);
    expect(
      rect.bottom,
      lessThanOrEqualTo(844 - 336),
      reason: 'Sign In button is hidden behind the keyboard',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('layout is unchanged when no keyboard is showing',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(keyboard: 0));
    await tester.pumpAndSettle();

    // No inset means no padding, so the form keeps the whole height — the
    // guard against "fixed the keyboard, broke the default state".
    expect(find.byType(GradientButton), findsOneWidget);
    expect(tester.getRect(find.byType(GradientButton)).bottom,
        lessThanOrEqualTo(844.0));
    expect(tester.takeException(), isNull);
  });
}
