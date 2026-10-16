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

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

/// `LoginScreen` keeps `resizeToAvoidBottomInset: false` so the full-bleed
/// building photo is never squashed, which means the Scaffold does *not*
/// shorten the body when the keyboard opens — the content layer applies the
/// keyboard inset itself.
///
/// That is easy to undo by accident: delete the padding and the screen still
/// builds and still passes a smoke test, but the password field and Sign In
/// button sit underneath the keyboard, and the framework's scroll-into-view
/// stops working because the viewport still appears to reach the screen bottom.
/// These tests pin the observable consequence rather than the implementation,
/// so a different correct fix would still pass.
///
/// **On sizes:** `flutter_test` substitutes a font whose every glyph is a full
/// em square, so text measures far wider here than on a device — the two short
/// strings in `VersionFooter` come to ~377px against ~196px in reality. The
/// keyboard-closed case therefore runs on a wider surface, where that inflated
/// text still fits and a no-overflow assertion means something. It is a harness
/// artifact, not a layout bug.
void main() {
  late _MockAuthBloc bloc;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  setUp(() {
    bloc = _MockAuthBloc();
    whenListen(bloc, const Stream<AuthState>.empty(),
        initialState: const AuthInitialState());
  });

  tearDown(() => bloc.close());

  Future<void> pumpLogin(
    WidgetTester tester, {
    required double keyboard,
    Size size = const Size(375, 667), // iPhone SE (2nd/3rd gen)
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          localizationsDelegates: PhoneFieldLocalization.delegates,
          home: MediaQuery(
            // Kept in step with tester.view above; a MediaQuery that disagrees
            // with the render surface silently tests a layout that cannot occur.
            data: MediaQueryData(
              size: size,
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: BlocProvider<AuthBloc>.value(
              value: bloc,
              child: const LoginScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('no overflow while the keyboard is open', (tester) async {
    await pumpLogin(tester, keyboard: 300);
    // RenderFlex overflow surfaces as an exception, not a failed expectation,
    // so without this it would pass silently.
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Sign In button can be scrolled above the keyboard',
      (tester) async {
    await pumpLogin(tester, keyboard: 300);

    final button = find.byType(GradientButton);
    expect(button, findsOneWidget);

    // Only 367px of usable height, so the form is taller than the viewport and
    // the button starts below the fold — correct, not a bug. What matters is
    // that scrolling can bring it clear of the keyboard. Before the fix that
    // was impossible: the viewport still ran to the bottom of the screen, so
    // the framework considered the button visible and never revealed it.
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();

    expect(tester.getRect(button).bottom, lessThanOrEqualTo(667 - 300),
        reason: 'Sign In button is still behind the keyboard');
  });

  testWidgets('leaves no leftover inset once the keyboard closes',
      (tester) async {
    // Wider surface so the inflated test-font footer fits (see class docs),
    // which lets the no-overflow assertion below be meaningful.
    await pumpLogin(tester, keyboard: 0, size: const Size(414, 896));

    expect(tester.takeException(), isNull);
    // The regression this guards: a fix that kept applying the keyboard inset
    // while the keyboard is shut would push the button off the bottom.
    expect(tester.getRect(find.byType(GradientButton)).bottom,
        lessThanOrEqualTo(896));
  });
}
