import 'package:steelforce/features/authentication/domain/notification_lifecycle.dart';
import 'package:steelforce/features/authentication/domain/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/session/app_restart_controller.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/core/session/session_scoped_store.dart';
import 'package:steelforce/core/session/unsent_work.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/authentication/domain/entities/user.dart';
import 'package:steelforce/features/authentication/domain/entities/user_role.dart';
import 'package:steelforce/features/authentication/domain/usecases/get_current_user.dart';
import 'package:steelforce/features/authentication/domain/usecases/login.dart';
import 'package:steelforce/features/authentication/domain/usecases/logout.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_event.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockLogin extends Mock implements Login {}

class _MockLogout extends Mock implements Logout {}

class _MockGetCurrentUser extends Mock implements GetCurrentUser {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _RecordingStore implements SessionScopedStore {
  bool cleared = false;

  @override
  String get debugName => 'test.store';

  @override
  Future<void> clearForSignOut() async => cleared = true;
}

/// Fails every hook, to prove sign-out survives it.
class _ThrowingNotifications implements NotificationLifecycle {
  @override
  Future<void> onSignedIn() async => throw StateError('no network');

  @override
  Future<void> onSigningOut() async => throw StateError('no network');
}

/// Records when the notification side of sign-out ran.
///
/// A two-method fake rather than a mock of `NotificationCoordinator`: that is
/// the entire reason [NotificationLifecycle] exists — `AuthBloc` must be
/// testable without standing up Firebase, a Drift DAO and three repositories.
class _RecordingNotifications implements NotificationLifecycle {
  final List<String> calls = [];

  @override
  Future<void> onSignedIn() async => calls.add('signedIn');

  @override
  Future<void> onSigningOut() async => calls.add('signingOut');
}

void main() {
  const logger = ConsoleAppLogger(verbose: false);

  late _MockLogin login;
  late _MockLogout logout;
  late _MockGetCurrentUser getCurrentUser;
  late SessionManager session;
  late _MockAuthRepository repository;
  late AppRestartController restart;
  late _RecordingStore store;
  late _RecordingNotifications notifications;

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const LogoutParams());
  });

  AuthBloc build() => AuthBloc(
        login: login,
        logout: logout,
        getCurrentUser: getCurrentUser,
        sessionManager: session,
        sessionReset: SessionResetService([store], logger),
        appRestart: restart,
        repository: repository,
        logger: logger,
        notifications: notifications,
      );

  setUp(() {
    notifications = _RecordingNotifications();
    login = _MockLogin();
    logout = _MockLogout();
    getCurrentUser = _MockGetCurrentUser();
    session = SessionManager();
    repository = _MockAuthRepository();
    restart = AppRestartController();
    store = _RecordingStore();
    when(() => logout(any())).thenAnswer((_) async => const Success(null));
  });

  Future<void> signOut(AuthBloc bloc) async {
    bloc.add(const LogoutRequested());
    // One turn of the event loop is enough: every awaited call in the handler
    // is already-completed test doubles.
    await Future<void>.delayed(Duration.zero);
  }

  test('the device is deregistered before the token is discarded', () async {
    // `docs/feature/notification/README.md` §4.4, and the ordering is the whole
    // point: deregistration is an authenticated call, so it has to happen while
    // the bearer token is still valid. Skipping it — or running it after — leaves
    // the platform pushing one rep's notifications at a handset that has since
    // been handed to somebody else.
    final order = <String>[];
    notifications.calls.clear();
    when(() => logout(any())).thenAnswer((_) async {
      order.add('logout');
      return const Success(null);
    });

    final bloc = build();
    addTearDown(bloc.close);

    await signOut(bloc);
    order.insertAll(0, notifications.calls);

    expect(order, ['signingOut', 'logout']);
  });

  test('a failing deregistration does not block sign-out', () async {
    // A rep who cannot sign out because a deregistration failed is worse than a
    // stale registration — which the backend deactivates on its own once FCM
    // reports the token dead.
    final bloc = AuthBloc(
      login: login,
      logout: logout,
      getCurrentUser: getCurrentUser,
      sessionManager: session,
      sessionReset: SessionResetService([store], logger),
      appRestart: restart,
      repository: repository,
      logger: logger,
      notifications: _ThrowingNotifications(),
    );
    addTearDown(bloc.close);

    await signOut(bloc);

    verify(() => logout(any())).called(1);
    expect(session.isAuthenticated, isFalse);
    expect(bloc.state, isA<AuthGuestState>());
  });

  test('sign-out clears tokens, feature stores and the session', () async {
    final bloc = build();
    addTearDown(bloc.close);

    await signOut(bloc);

    verify(() => logout(any())).called(1);
    expect(store.cleared, isTrue);
    expect(session.isAuthenticated, isFalse);
    expect(bloc.state, isA<AuthGuestState>());
  });

  test('sign-out restarts the app', () async {
    final bloc = build();
    addTearDown(bloc.close);
    final before = restart.value;

    await signOut(bloc);

    expect(restart.value, greaterThan(before));
  });

  test('sign-out restarts even when the state is already guest', () async {
    // The bug this pins down: `AuthGuestState` is an Equatable with no props,
    // so bloc suppresses the emit when guest is already the current state.
    // Anything keyed off that emission — as the first fix was — waits forever
    // and the app never restarts. The restart must not depend on it.
    final bloc = build();
    addTearDown(bloc.close);

    bloc.add(const AuthGuestRequested());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state, isA<AuthGuestState>());

    final before = restart.value;
    await signOut(bloc);

    expect(restart.value, greaterThan(before),
        reason: 'restart must not be gated on a state change that bloc '
            'legitimately suppresses');
    expect(store.cleared, isTrue);
  });

  test('a signed-in session is torn down on sign-out', () async {
    final bloc = build();
    addTearDown(bloc.close);
    session.setUser(_user());
    expect(session.isAuthenticated, isTrue);

    await signOut(bloc);

    expect(session.isAuthenticated, isFalse);
    expect(session.currentUser, isNull);
  });

  group('unsent work', () {
    AuthBloc buildWith(int unsent) => AuthBloc(
          login: login,
          logout: logout,
          getCurrentUser: getCurrentUser,
          sessionManager: session,
          sessionReset: SessionResetService([store], logger),
          appRestart: restart,
          repository: repository,
          logger: logger,
          notifications: notifications,
          unsentWork: UnsentWorkService([_Unsent(unsent)], logger),
        );

    test('sign-out is refused while work has not reached the server', () async {
      // Sign-out wipes the device; going ahead would destroy it.
      final bloc = buildWith(2);
      addTearDown(bloc.close);
      session.setUser(_user());
      final before = restart.value;

      await signOut(bloc);

      verifyNever(() => logout(any()));
      expect(store.cleared, isFalse);
      expect(notifications.calls, isEmpty);
      expect(session.isAuthenticated, isTrue);
      expect(restart.value, before);
    });

    test('sign-out proceeds once nothing is left unsent', () async {
      final bloc = buildWith(0);
      addTearDown(bloc.close);

      await signOut(bloc);

      verify(() => logout(any())).called(1);
      expect(store.cleared, isTrue);
    });
  });
}

class _Unsent implements UnsentWorkSource {
  const _Unsent(this.count);
  final int count;

  @override
  String get debugName => 'test.unsent';

  @override
  Future<int> countUnsent() async => count;

  @override
  Future<int> countSendable() async => count;

  @override
  Future<void> sendNow() async {}
}

User _user() => const User(
      id: 'u1',
      email: 'rep@isigroup.com.kh',
      fullName: 'Rep One',
      roles: {UserRole.salesRep},
    );
