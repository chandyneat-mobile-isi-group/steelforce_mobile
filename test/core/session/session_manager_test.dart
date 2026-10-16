import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/authentication/domain/entities/user.dart';
import 'package:steelforce/features/authentication/domain/entities/user_role.dart';

const _user = User(
  id: 'u-1',
  email: 'rep@isigroup.com.kh',
  fullName: 'Sok Dara',
  roles: {UserRole.salesRep},
);

void main() {
  late SessionManager session;

  setUp(() => session = SessionManager());
  tearDown(() => session.dispose());

  test('starts initializing, not guest', () {
    // The distinction is load-bearing: "we have not looked yet" is not the
    // same as "there is no session", and a protected call fired during boot
    // would be an unauthenticated one by accident.
    expect(session.state, AuthenticationState.initializing);
    expect(session.canCallProtectedApi, isFalse);
    expect(session.isAuthenticated, isFalse);
  });

  group('the protected-API gate', () {
    test('is closed for every state except a live session', () {
      expect(session.canCallProtectedApi, isFalse, reason: 'initializing');

      session.clear();
      expect(session.canCallProtectedApi, isFalse, reason: 'guest');

      session.beginAuthentication();
      expect(session.canCallProtectedApi, isFalse, reason: 'authenticating');

      session.expire();
      expect(session.canCallProtectedApi, isFalse, reason: 'expired');
    });

    test('stays open during a token rotation', () {
      // The session is still valid mid-refresh; the interceptor holds the
      // request until the new token lands. Closing the gate here would make
      // every rotation look like a sign-out to the rest of the app.
      session.setUser(_user);
      session.beginRefresh();

      expect(session.state, AuthenticationState.refreshingToken);
      expect(session.canCallProtectedApi, isTrue);

      session.endRefresh();
      expect(session.state, AuthenticationState.authenticated);
    });

    test('a refresh cannot be started from guest', () {
      // Otherwise `beginRefresh` would open the gate for a user with no
      // session at all.
      session.clear();
      session.beginRefresh();

      expect(session.state, AuthenticationState.guest);
      expect(session.canCallProtectedApi, isFalse);
    });
  });

  group('expiry is not the same as sign-out', () {
    test('clear lands in guest', () {
      session.setUser(_user);
      session.clear();

      expect(session.state, AuthenticationState.guest);
      expect(session.currentUser, isNull);
    });

    test('expire lands in sessionExpired', () {
      // So the UI can say *why* the user is being asked to sign in again
      // rather than silently dropping them at a login screen.
      session.setUser(_user);
      session.expire();

      expect(session.state, AuthenticationState.sessionExpired);
      expect(session.currentUser, isNull);
      expect(session.isAuthenticated, isFalse);
    });
  });

  group('observability', () {
    test('emits each distinct transition', () async {
      final seen = <AuthenticationState>[];
      final sub = session.stateChanges.listen(seen.add);

      session
        ..beginAuthentication()
        ..setUser(_user)
        ..beginRefresh()
        ..endRefresh()
        ..expire();

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(seen, [
        AuthenticationState.authenticating,
        AuthenticationState.authenticated,
        AuthenticationState.refreshingToken,
        AuthenticationState.authenticated,
        AuthenticationState.sessionExpired,
      ]);
    });

    test('never emits the same state twice in a row', () async {
      final seen = <AuthenticationState>[];
      final sub = session.stateChanges.listen(seen.add);

      session
        ..setUser(_user)
        ..setUser(_user)
        ..clear()
        ..clear();

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      // A listener rebuilding on state must not be woken by a no-op.
      expect(
          seen, [AuthenticationState.authenticated, AuthenticationState.guest]);
    });

    test('roles fall back to guest with no user', () {
      expect(session.primaryRole, UserRole.guest);
      expect(session.roles, {UserRole.guest});

      session.setUser(_user);
      expect(session.can(UserRole.salesRep), isTrue);
    });
  });
}
