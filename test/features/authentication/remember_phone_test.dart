import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/session/app_restart_controller.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/core/session/session_scoped_store.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/authentication/domain/entities/auth_profile.dart';
import 'package:steelforce/features/authentication/domain/notification_lifecycle.dart';
import 'package:steelforce/features/authentication/domain/repositories/auth_repository.dart';
import 'package:steelforce/features/authentication/domain/repositories/sign_in_memory.dart';
import 'package:steelforce/features/authentication/domain/usecases/get_current_user.dart';
import 'package:steelforce/features/authentication/domain/usecases/get_remembered_phone.dart';
import 'package:steelforce/features/authentication/domain/usecases/login.dart';
import 'package:steelforce/features/authentication/domain/usecases/logout.dart';
import 'package:steelforce/features/authentication/domain/usecases/update_remembered_phone.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_event.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_state.dart';
import 'package:steelforce/features/authentication/presentation/screens/login_screen.dart';

const _logger = ConsoleAppLogger(verbose: false);

const _profile = AuthProfile(
  id: 'u-1',
  employeeId: 'EMP000202',
  email: 'rep@isigroup.com.kh',
  fullName: 'Sok Dara',
  permissions: {'outlets.read'},
);

class _MockLogin extends Mock implements Login {}

class _MockLogout extends Mock implements Logout {}

class _MockGetCurrentUser extends Mock implements GetCurrentUser {}

class _MockRepo extends Mock implements AuthRepository {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _NoopStore implements SessionScopedStore {
  @override
  String get debugName => 'noop';
  @override
  Future<void> clearForSignOut() async {}
}

class _NoopNotifications implements NotificationLifecycle {
  const _NoopNotifications();
  @override
  Future<void> onSignedIn() async {}
  @override
  Future<void> onSigningOut() async {}
}

/// In-memory [SignInMemory] that records every write, so a test can prove
/// what was — and was not — kept.
class _FakeMemory implements SignInMemory {
  _FakeMemory([this.phone]);
  String? phone;
  final writes = <String>[];
  bool failReads = false;

  @override
  Future<String?> readPhone() async {
    if (failReads) throw Exception('keystore locked');
    return phone;
  }

  @override
  Future<void> rememberPhone(String value) async {
    writes.add(value);
    phone = value;
  }

  @override
  Future<void> forgetPhone() async {
    writes.add('<forget>');
    phone = null;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(const LoginParams(identifier: '', password: ''));
    registerFallbackValue(const AuthGuestRequested());
  });

  group('AuthBloc applies "Remember me"', () {
    late _MockLogin login;
    late _FakeMemory memory;
    late SessionManager session;

    AuthBloc build() => AuthBloc(
          login: login,
          logout: _MockLogout(),
          getCurrentUser: _MockGetCurrentUser(),
          sessionManager: session,
          sessionReset: SessionResetService([_NoopStore()], _logger),
          appRestart: AppRestartController(),
          repository: _MockRepo(),
          logger: _logger,
          notifications: const _NoopNotifications(),
          updateRememberedPhone: UpdateRememberedPhone(memory),
        );

    setUp(() {
      login = _MockLogin();
      memory = _FakeMemory();
      session = SessionManager();
    });

    tearDown(() => session.dispose());

    Future<void> signIn({required bool remember}) async {
      final bloc = build();
      bloc.add(LoginSubmittedEvent(
        identifier: '+85512345201',
        password: 'secret-password',
        rememberPhone: remember,
      ));
      await bloc.stream
          .firstWhere((s) => s is AuthenticatedState || s is AuthFailureState);
      await bloc.close();
    }

    test('ticked: keeps the phone number and never the password', () async {
      when(() => login(any())).thenAnswer((_) async => const Success(_profile));

      await signIn(remember: true);

      expect(memory.phone, '+85512345201');
      expect(memory.writes, ['+85512345201']);
      expect(memory.writes.join(), isNot(contains('secret-password')));
    });

    test('unticked: forgets a number kept from before', () async {
      memory.phone = '+85599999999';
      when(() => login(any())).thenAnswer((_) async => const Success(_profile));

      await signIn(remember: false);

      expect(memory.phone, isNull);
    });

    test('a rejected sign-in leaves the remembered number alone', () async {
      memory.phone = '+85599999999';
      when(() => login(any())).thenAnswer((_) async =>
          const Failed(AuthenticationFailure(message: 'Wrong password')));

      await signIn(remember: true);

      expect(memory.phone, '+85599999999');
      expect(memory.writes, isEmpty);
    });
  });

  group('GetRememberedPhone', () {
    test('returns the kept number', () async {
      final r = await GetRememberedPhone(_FakeMemory('+85512345201'))(
          const NoParams());
      expect(
          r.when(success: (p) => p, failure: (_) => 'failed'), '+85512345201');
    });

    test('a storage failure is a CacheFailure, not a crash', () async {
      final r = await GetRememberedPhone(_FakeMemory()..failReads = true)(
          const NoParams());
      expect(
          r.when(success: (_) => null, failure: (f) => f), isA<CacheFailure>());
    });
  });

  group('LoginScreen', () {
    late _MockAuthBloc bloc;

    setUp(() {
      bloc = _MockAuthBloc();
      whenListen(bloc, const Stream<AuthState>.empty(),
          initialState: const AuthInitialState());
    });

    tearDown(() => bloc.close());

    Future<void> pump(WidgetTester tester, SignInMemory memory) async {
      await tester.runAsync(() => LocalizationService.instance.load('en'));
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light(AppTypography.latinFontFamily),
          localizationsDelegates: PhoneFieldLocalization.delegates,
          home: BlocProvider<AuthBloc>.value(
            value: bloc,
            child: LoginScreen(getRememberedPhone: GetRememberedPhone(memory)),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    bool ticked(WidgetTester tester) =>
        tester.widget<Checkbox>(find.byType(Checkbox)).value!;

    testWidgets('pre-fills the remembered number and ticks the box',
        (tester) async {
      await pump(tester, _FakeMemory('+85512345201'));

      // The field's own text, not its "12 345 201" hint.
      final field =
          tester.widget<EditableText>(find.byType(EditableText).first);
      expect(field.controller.text, '12 345 201');
      expect(ticked(tester), isTrue);
    });

    testWidgets('nothing remembered: empty field, box unticked',
        (tester) async {
      await pump(tester, _FakeMemory());

      expect(ticked(tester), isFalse);
    });

    testWidgets('submits the choice with the sign-in, password typed fresh',
        (tester) async {
      await pump(tester, _FakeMemory('+85512345201'));

      await tester.tap(find.text('auth.remember_me'.tr));
      await tester.pump();
      expect(ticked(tester), isFalse);

      await tester.enterText(find.byType(TextFormField).last, 'secret-pw');
      await tester.tap(find.text('auth.login_btn'.tr));
      await tester.pump();

      final sent = verify(() => bloc.add(captureAny())).captured.last
          as LoginSubmittedEvent;
      expect(sent.identifier, '+85512345201');
      expect(sent.rememberPhone, isFalse);
    });
  });
}
