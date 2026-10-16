import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/authentication/domain/entities/user.dart';
import 'package:steelforce/features/authentication/domain/entities/user_role.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_sync_scope.dart';

/// The route feed is filtered by the rep's territory. It used to be the
/// hardcoded literal `'Phnom Penh'` — correct only for the bundled fixture
/// that always carried that value, and simply wrong against the real API,
/// where a rep on `PP-NORTH` asked for a territory that does not exist and got
/// an empty day indistinguishable from having no visits.
const _user = User(
  id: 'rep-1',
  email: 'rep@isigroup.com.kh',
  fullName: 'Rep One',
  roles: {UserRole.salesRep},
);

void main() {
  late SessionManager session;

  setUp(() => session = SessionManager());

  test('reads the territory the profile actually carries', () {
    session.setUser(_user, territoryCode: 'PP-NORTH');

    final scope = RouteSyncScope.forCurrentUser(session);

    expect(scope.territory, 'PP-NORTH');
    expect(scope.repId, 'rep-1');
    expect(scope.hasTerritory, isTrue);
  });

  test('falls back to unscoped rather than guessing a territory', () {
    // No territory on the profile. Substituting a plausible-looking code would
    // quietly return the wrong rep's rows, or none, with nothing to show why.
    session.setUser(_user);

    final scope = RouteSyncScope.forCurrentUser(session);

    expect(scope.territory, RouteSyncScope.unscoped);
    expect(scope.hasTerritory, isFalse);
  });

  test('treats a blank territory as unscoped', () {
    session.setUser(_user, territoryCode: '   ');

    expect(RouteSyncScope.forCurrentUser(session).hasTerritory, isFalse);
  });

  test('a signed-out session scopes to guest with no territory', () {
    session.setUser(_user, territoryCode: 'PP-NORTH');
    session.clear();

    final scope = RouteSyncScope.forCurrentUser(session);

    expect(scope.repId, 'guest');
    // The previous rep's territory must not survive a sign-out.
    expect(scope.hasTerritory, isFalse);
  });

  test('an expired session does not leak the previous territory', () {
    session.setUser(_user, territoryCode: 'PP-NORTH');
    session.expire();

    expect(RouteSyncScope.forCurrentUser(session).hasTerritory, isFalse);
  });
}
