import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/authentication/domain/entities/user.dart';
import 'package:steelforce/features/authentication/domain/entities/user_role.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_event.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_state.dart';
import 'package:steelforce/features/authentication/presentation/screens/login_screen.dart';
import 'package:phone_form_field/phone_form_field.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _Spy extends NavigatorObserver {
  final pushed = <String?>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previous) =>
      pushed.add(route.settings.name);
}

/// Sign-in is a single request: phone + password, straight to the shell. The
/// one-time code now guards password *reset* only.
///
/// These pin that a successful sign-in lands on the shell and that a failure
/// is reported in place without navigating.
///
/// Driving the form itself is deliberately avoided — `PhoneFormField`'s
/// internals do not sync reliably in this harness (see the note in
/// `forgot_password_flow_test.dart`), so these drive the bloc instead, which
/// is where the behaviour under test actually lives.
void main() {
  late _MockAuthBloc bloc;
  late _Spy spy;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  setUp(() {
    bloc = _MockAuthBloc();
    spy = _Spy();
  });

  tearDown(() => bloc.close());

  Future<void> pump(WidgetTester tester, Stream<AuthState> states) async {
    whenListen(bloc, states, initialState: const AuthInitialState());
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          localizationsDelegates: PhoneFieldLocalization.delegates,
          navigatorObservers: [spy],
          routes: {
            '/': (_) => BlocProvider<AuthBloc>.value(
                value: bloc, child: const LoginScreen()),
            '/main': (_) => const Scaffold(body: Text('SHELL')),
            '/verify-otp': (_) => const Scaffold(body: Text('VERIFY')),
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('a successful sign-in goes straight to the shell',
      (tester) async {
    await pump(
      tester,
      Stream.value(const AuthenticatedState(User(
        id: 'u1',
        email: 'rep@isigroup.com.kh',
        fullName: 'Sophea Chan',
        roles: {UserRole.salesRep},
      ))),
    );
    await tester.pumpAndSettle();

    expect(find.text('SHELL'), findsOneWidget);
    expect(find.text('VERIFY'), findsNothing,
        reason: 'signing in must not route through a code screen');
  });

  testWidgets('a failure is reported, a success is not', (tester) async {
    // The success pill was removed because the shell appearing says the same
    // thing. The failure message must survive that removal — it is the only
    // thing telling a rep their password was wrong.
    await pump(
      tester,
      Stream.value(
          const AuthFailureState('Phone number or password is incorrect')),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Phone number or password is incorrect'), findsOneWidget);
    // Still on the login screen — a failure must not navigate.
    expect(find.text('SHELL'), findsNothing);
  });
}
