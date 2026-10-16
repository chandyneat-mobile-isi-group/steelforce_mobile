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
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/session/app_restart_controller.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/core/session/session_scoped_store.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/authentication/data/datasources/auth_local_data_source.dart';
import 'package:steelforce/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:steelforce/features/authentication/data/models/auth_profile_model.dart';
import 'package:steelforce/features/authentication/data/models/auth_token_model.dart';
import 'package:steelforce/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:steelforce/features/authentication/domain/entities/auth_profile.dart';
import 'package:steelforce/features/authentication/domain/notification_lifecycle.dart';
import 'package:steelforce/features/authentication/domain/repositories/auth_repository.dart';
import 'package:steelforce/features/authentication/domain/usecases/get_current_user.dart';
import 'package:steelforce/features/authentication/domain/usecases/login.dart';
import 'package:steelforce/features/authentication/domain/usecases/logout.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_event.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_state.dart';
import 'package:steelforce/features/authentication/presentation/screens/change_temporary_password_screen.dart';
import 'package:steelforce/features/authentication/presentation/screens/create_new_password_screen.dart';
import 'package:steelforce/features/authentication/presentation/screens/login_screen.dart';

/// A sign-in with a temporary password (`passwordChangeRequired` on the
/// mobile login response) must end on the change-password screen, not the
/// shell, and must stay there across a restart until the change succeeds.
const _logger = ConsoleAppLogger(verbose: false);

const _profileJson = {
  'userId': 'u-1',
  'employeeId': 'EMP000202',
  'email': 'rep@isigroup.com.kh',
  'fullName': 'Sok Dara',
};

const _profile = AuthProfile(
  id: 'u-1',
  employeeId: 'EMP000202',
  email: 'rep@isigroup.com.kh',
  fullName: 'Sok Dara',
  passwordChangeRequired: true,
);

class _MockRemote extends Mock implements AuthRemoteDataSource {}

class _MockLocal extends Mock implements AuthLocalDataSource {}

class _MockNetwork extends Mock implements NetworkInfo {}

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

class _Spy extends NavigatorObserver {
  final pushed = <RouteSettings>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previous) =>
      pushed.add(route.settings);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
    registerFallbackValue(const LoginParams(identifier: '', password: ''));
    registerFallbackValue(AuthProfileModel.fromJson(_profileJson));
    registerFallbackValue(
        const AuthTokenModel(accessToken: '', refreshToken: ''));
  });

  group('AuthTokenModel', () {
    test('reads the wrapped camelCase mobile login response', () {
      final token = AuthTokenModel.fromMap({
        'success': true,
        'data': {
          'accessToken': 'a',
          'refreshToken': 'r',
          'tokenType': 'Bearer',
          'expiresIn': 900,
          'passwordChangeRequired': true,
        },
      });
      expect(token.accessToken, 'a');
      expect(token.refreshToken, 'r');
      expect(token.expiresIn, 900);
      expect(token.isUsable, isTrue);
      expect(token.passwordChangeRequired, isTrue);
    });

    test('still reads the raw OAuth response, flag absent means false', () {
      final token = AuthTokenModel.fromMap({
        'access_token': 'a',
        'refresh_token': 'r',
        'expires_in': 899,
      });
      expect(token.isUsable, isTrue);
      expect(token.passwordChangeRequired, isFalse);
    });
  });

  group('AuthProfileModel', () {
    test('caches the flag so a restart does not skip the change', () {
      final model = AuthProfileModel.fromJson(_profileJson)
          .copyWithPasswordChangeRequired(true);
      final restored = AuthProfileModel.fromJson(model.toJson());
      expect(restored.passwordChangeRequired, isTrue);
      expect(
        restored.copyWithPasswordChangeRequired(false).passwordChangeRequired,
        isFalse,
      );
    });
  });

  group('AuthRepositoryImpl', () {
    late _MockRemote remote;
    late _MockLocal local;
    late _MockNetwork network;
    late AuthRepositoryImpl repo;

    setUp(() {
      remote = _MockRemote();
      local = _MockLocal();
      network = _MockNetwork();
      repo = AuthRepositoryImpl(
        remote: remote,
        local: local,
        networkInfo: network,
        logger: _logger,
      );
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => local.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          )).thenAnswer((_) async {});
      when(() => local.cacheSession(
            token: any(named: 'token'),
            profile: any(named: 'profile'),
          )).thenAnswer((_) async {});
      when(() => remote.getProfile())
          .thenAnswer((_) async => AuthProfileModel.fromJson(_profileJson));
    });

    void stubLogin({required bool passwordChangeRequired}) => when(
        () => remote.login(
              phoneNumber: any(named: 'phoneNumber'),
              password: any(named: 'password'),
              pushToken: any(named: 'pushToken'),
              rememberDevice: any(named: 'rememberDevice'),
            )).thenAnswer((_) async => AuthTokenModel(
          accessToken: 'a',
          refreshToken: 'r',
          passwordChangeRequired: passwordChangeRequired,
        ));

    test('copies the login flag onto the profile it returns and caches',
        () async {
      stubLogin(passwordChangeRequired: true);
      final result = await repo.login(identifier: '012345201', password: 'x');

      final profile = (result as Success<AuthProfile>).data;
      expect(profile.passwordChangeRequired, isTrue);
      final cached = verify(() => local.cacheSession(
            token: any(named: 'token'),
            profile: captureAny(named: 'profile'),
          )).captured.single as AuthProfileModel;
      expect(cached.passwordChangeRequired, isTrue);
    });

    test('an ordinary sign-in is not flagged', () async {
      stubLogin(passwordChangeRequired: false);
      final result = await repo.login(identifier: '012345201', password: 'x');
      expect((result as Success<AuthProfile>).data.passwordChangeRequired,
          isFalse);
    });

    test('markPasswordChanged clears the flag on the cached profile', () async {
      when(() => local.readProfile()).thenAnswer((_) async =>
          AuthProfileModel.fromJson(_profileJson)
              .copyWithPasswordChangeRequired(true));
      when(() => local.cacheProfile(any())).thenAnswer((_) async {});

      final result = await repo.markPasswordChanged();

      expect(result, isA<Success<void>>());
      final written = verify(() => local.cacheProfile(captureAny()))
          .captured
          .single as AuthProfileModel;
      expect(written.passwordChangeRequired, isFalse);
    });
  });

  group('AuthBloc', () {
    late _MockLogin login;
    late _MockRepo repo;
    late SessionManager session;

    AuthBloc build() => AuthBloc(
          login: login,
          logout: _MockLogout(),
          getCurrentUser: _MockGetCurrentUser(),
          sessionManager: session,
          sessionReset: SessionResetService([_NoopStore()], _logger),
          appRestart: AppRestartController(),
          repository: repo,
          logger: _logger,
          notifications: const _NoopNotifications(),
        );

    setUp(() {
      login = _MockLogin();
      repo = _MockRepo();
      session = SessionManager();
    });

    blocTest<AuthBloc, AuthState>(
      'a temporary-password sign-in is authenticated but flagged',
      setUp: () => when(() => login(any()))
          .thenAnswer((_) async => const Success(_profile)),
      build: build,
      act: (b) => b.add(
          const LoginSubmittedEvent(identifier: '012345201', password: 'x')),
      expect: () => [
        const AuthLoadingState(),
        AuthenticatedState(_profile.toUser(), passwordChangeRequired: true),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'completing the change clears the flag locally and in state',
      setUp: () {
        when(() => repo.markPasswordChanged())
            .thenAnswer((_) async => const Success(null));
        session.setUser(_profile.toUser());
      },
      build: build,
      act: (b) => b.add(const PasswordChangeCompleted()),
      expect: () => [AuthenticatedState(_profile.toUser())],
      verify: (_) => verify(() => repo.markPasswordChanged()).called(1),
    );

    blocTest<AuthBloc, AuthState>(
      'a cache failure while clearing the flag still lets the rep in',
      setUp: () {
        when(() => repo.markPasswordChanged()).thenAnswer(
            (_) async => const Failed(CacheFailure(message: 'locked')));
        session.setUser(_profile.toUser());
      },
      build: build,
      act: (b) => b.add(const PasswordChangeCompleted()),
      expect: () => [AuthenticatedState(_profile.toUser())],
    );
  });

  group('LoginScreen', () {
    testWidgets('a flagged sign-in goes to change-password, not the shell',
        (tester) async {
      final bloc = _MockAuthBloc();
      final spy = _Spy();
      addTearDown(bloc.close);
      whenListen(
        bloc,
        Stream<AuthState>.fromIterable([
          const AuthLoadingState(),
          AuthenticatedState(_profile.toUser(), passwordChangeRequired: true),
        ]),
        initialState: const AuthInitialState(),
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          localizationsDelegates: PhoneFieldLocalization.delegates,
          navigatorObservers: [spy],
          routes: {
            '/': (_) => BlocProvider<AuthBloc>.value(
                value: bloc, child: const LoginScreen()),
            '/main': (_) => const Scaffold(body: Text('SHELL')),
            '/change-temporary-password': (_) =>
                const Scaffold(body: Text('CHANGE')),
          },
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('CHANGE'), findsOneWidget);
      expect(find.text('SHELL'), findsNothing);
      expect(spy.pushed.last.name, '/change-temporary-password');
      // The sign-in password travels with the route, so it is not asked for
      // a second time.
      expect(spy.pushed.last.arguments, isA<String>());
    });
  });

  group('ChangeTemporaryPasswordScreen', () {
    const strong = 'NewPassword123!';

    Future<List<(String, String)>> pump(
      WidgetTester tester, {
      String? currentPassword = 'Temp-Pass-0001',
      ResetPasswordResult result = const ResetPasswordResult.success(),
      VoidCallback? onSuccess,
      VoidCallback? onSignOut,
    }) async {
      final calls = <(String, String)>[];
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light(AppTypography.latinFontFamily),
          home: ChangeTemporaryPasswordScreen(
            currentPassword: currentPassword,
            onSubmit: (current, next) async {
              calls.add((current, next));
              return result;
            },
            onSuccess: onSuccess ?? () {},
            onSignOut: onSignOut ?? () {},
          ),
        ),
      ));
      await tester.pump();
      return calls;
    }

    // `VibeField` draws its label outside the input, so fields are found by
    // position: [current,] new, confirm.
    Finder at(int i) => find.byType(TextFormField).at(i);

    Future<void> tapSave(WidgetTester tester) async {
      final button = find.text('auth.change_password_button'.tr);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('submits the carried temporary password with the new one',
        (tester) async {
      var succeeded = false;
      final calls = await pump(tester, onSuccess: () => succeeded = true);

      expect(find.byType(TextFormField), findsNWidgets(2));
      await tester.enterText(at(0), strong);
      await tester.enterText(at(1), strong);
      await tapSave(tester);

      expect(calls, [('Temp-Pass-0001', strong)]);
      expect(succeeded, isTrue);
    });

    testWidgets('asks for the current password when none was carried',
        (tester) async {
      final calls = await pump(tester, currentPassword: null);

      expect(find.byType(TextFormField), findsNWidgets(3));
      await tester.enterText(at(0), 'Temp-Pass-0001');
      await tester.enterText(at(1), strong);
      await tester.enterText(at(2), strong);
      await tapSave(tester);

      expect(calls, [('Temp-Pass-0001', strong)]);
    });

    testWidgets('rejects a short, reused or mismatched password locally',
        (tester) async {
      final calls = await pump(tester);

      await tester.enterText(at(0), 'short');
      await tester.enterText(at(1), 'short');
      await tapSave(tester);
      expect(find.text('auth.change_password_too_short'.tr), findsOneWidget);

      await tester.enterText(at(0), 'Temp-Pass-0001');
      await tester.enterText(at(1), 'Temp-Pass-0001');
      await tapSave(tester);
      expect(
          find.text('auth.change_password_same_as_current'.tr), findsOneWidget);

      await tester.enterText(at(0), strong);
      await tester.enterText(at(1), '${strong}x');
      await tapSave(tester);
      expect(find.text('auth.passwords_dont_match'.tr), findsOneWidget);

      expect(calls, isEmpty);
    });

    testWidgets('shows the server message and stays put on failure',
        (tester) async {
      var succeeded = false;
      await pump(
        tester,
        result: const ResetPasswordResult.failure('Current password is wrong'),
        onSuccess: () => succeeded = true,
      );

      await tester.enterText(at(0), strong);
      await tester.enterText(at(1), strong);
      await tapSave(tester);

      expect(find.text('Current password is wrong'), findsOneWidget);
      expect(succeeded, isFalse);
    });

    testWidgets('cannot be backed out of; sign-out is the only exit',
        (tester) async {
      var signedOut = false;
      await pump(tester, onSignOut: () => signedOut = true);

      final scope = tester.widget<PopScope>(find.byType(PopScope));
      expect(scope.canPop, isFalse);

      final signOut = find.text('auth.change_temp_password_sign_out'.tr);
      await tester.ensureVisible(signOut);
      await tester.tap(signOut);
      expect(signedOut, isTrue);
    });
  });
}
