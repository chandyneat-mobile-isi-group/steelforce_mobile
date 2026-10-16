import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/auth/protected_feature.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/authentication/domain/entities/auth_profile.dart';
import 'package:steelforce/features/authentication/domain/entities/user.dart';
import 'package:steelforce/features/authentication/domain/entities/user_role.dart';

const _user = User(
  id: 'u-1',
  email: 'rep@isigroup.com.kh',
  fullName: 'Sok Dara',
  roles: {UserRole.salesRep},
);

/// A loader that needs the depot directory, like `DepotSyncCubit`.
class _DepotLoader with ProtectedFeature {
  _DepotLoader(this.session);

  @override
  final SessionManager session;

  @override
  Set<String> get requiredPermissions => Permissions.canReadDepots;

  int runs = 0;

  Future<void> load() => whenAuthenticated(() async => runs++);
}

/// A loader that needs nothing beyond a session.
class _AnyLoader with ProtectedFeature {
  _AnyLoader(this.session);

  @override
  final SessionManager session;
}

void main() {
  late SessionManager session;

  setUp(() => session = SessionManager());
  tearDown(() => session.dispose());

  test('a signed-in user without the grant cannot load', () async {
    // A role with neither spelling of the depot grant. Gating on the
    // permission the profile already reports avoids a round trip that could
    // only come back 403.
    session.setUser(_user, permissions: {'visits.create'});
    final loader = _DepotLoader(session);

    expect(session.canCallProtectedApi, isTrue, reason: 'session is fine');
    expect(loader.canLoad, isFalse, reason: 'the grant is what is missing');

    await loader.load();
    expect(loader.runs, 0);
    expect(loader.blockedReason, contains('permission:'));
  });

  test('the outlets spelling grants the same capability', () async {
    // The running backend spells it `outlets.read`. Requiring only
    // `depots.read` refused a call every rep was entitled to make.
    session.setUser(_user, permissions: {Permissions.outletsRead});
    final loader = _DepotLoader(session);

    expect(loader.canLoad, isTrue);
    await loader.load();
    expect(loader.runs, 1);
  });

  test('a signed-in user with the grant loads', () async {
    session.setUser(_user, permissions: {Permissions.depotsRead});
    final loader = _DepotLoader(session);

    expect(loader.canLoad, isTrue);
    await loader.load();
    expect(loader.runs, 1);
  });

  test('no session blocks even when the grant would be held', () async {
    final loader = _DepotLoader(session); // still initializing

    expect(loader.canLoad, isFalse);
    expect(loader.blockedReason, 'session:initializing');
  });

  test('permissions are dropped on sign-out and on expiry', () {
    session.setUser(_user, permissions: {Permissions.depotsRead});
    expect(session.hasPermission(Permissions.depotsRead), isTrue);

    session.clear();
    expect(session.permissions, isEmpty);

    session.setUser(_user, permissions: {Permissions.depotsRead});
    session.expire();
    expect(session.permissions, isEmpty,
        reason: 'a dead session grants nothing');
  });

  test('a feature declaring no permission needs only a session', () {
    final loader = _AnyLoader(session);
    expect(loader.canLoad, isFalse);

    session.setUser(_user);
    expect(loader.canLoad, isTrue);
  });

  test('guardedCall distinguishes "sign in" from "not allowed"', () async {
    session.setUser(_user, permissions: const {});
    final loader = _DepotLoader(session);

    final denied = await loader.guardedCall(() async => throw StateError('no'));
    denied.when(
      success: (_) => fail('should not have run'),
      // Telling a signed-in user to sign in sends them round a loop they
      // cannot win.
      failure: (f) => expect(f.message, contains('does not have access')),
    );

    session.clear();
    final guest = await loader.guardedCall(() async => throw StateError('no'));
    guest.when(
      success: (_) => fail('should not have run'),
      failure: (f) => expect(f.message, contains('Sign in')),
    );
  });
}
