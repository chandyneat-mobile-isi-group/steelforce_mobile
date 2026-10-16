import 'dart:async';

import 'package:steelforce/features/authentication/domain/entities/user.dart';
import 'package:steelforce/features/authentication/domain/entities/user_role.dart';

/// The application-wide authentication lifecycle.
///
/// Distinct from `AuthState`, which is `AuthBloc`'s *presentation* state and
/// exists to drive the login screen (spinner, error banner). This is the
/// platform-level fact that every other feature consumes, and it is
/// deliberately readable **synchronously** — a feature deciding whether to
/// issue a protected request cannot await a stream first.
enum AuthenticationState {
  /// Boot has not yet resolved whether a stored session exists. Protected
  /// calls must not fire here: the answer is simply not known yet, and a
  /// request sent now would be an unauthenticated one by accident.
  initializing,

  /// No session, and that is a normal resting state — the app is browsable.
  guest,

  /// A sign-in is in flight.
  authenticating,

  /// A valid session is held. The only state in which protected APIs may be
  /// called.
  authenticated,

  /// An access token is being rotated. The session is still valid; requests
  /// issued now are queued by the interceptor rather than rejected.
  refreshingToken,

  /// A session existed and can no longer be recovered — the refresh token was
  /// rejected or revoked. Distinct from [guest] so the UI can explain *why*
  /// the user is being asked to sign in again rather than silently dropping
  /// them at a login screen.
  sessionExpired,
}

/// Single source of truth for "who is signed in right now" and "may we call a
/// protected API", kept in memory.
///
/// [AuthBloc] drives it on every auth change and the network layer drives it
/// on refresh failure, so guards, middleware and any widget can read the
/// current user, roles and lifecycle state synchronously. A plain singleton
/// registered in DI — not tied to any router.
///
/// **Features must consume this rather than re-deriving authentication.** The
/// rule the architecture depends on is [canCallProtectedApi]: a feature that
/// checks it before fetching cannot accidentally fire an unauthenticated
/// request during boot, during a sign-in, or after a session has expired.
class SessionManager {
  User? _user;
  Set<String> _permissions = const {};
  String? _territoryCode;
  AuthenticationState _state = AuthenticationState.initializing;

  User? get currentUser => _user;

  /// The fine-grained grants from `GET /auth/me`, e.g. `depots.read`.
  ///
  /// Held here rather than inside the depot/order/quotation features so a
  /// feature can ask "may this user do X" without owning a copy of the
  /// profile. **A client-side check is a courtesy, never a security control** —
  /// the server re-checks every one. Its job is to avoid firing a request that
  /// can only come back 403, and to hide a button the user cannot press.
  Set<String> get permissions => _permissions;

  /// The rep's assigned territory from `GET /auth/me`, e.g. `PP-NORTH`.
  ///
  /// Held here for the same reason as [permissions]: a feature that scopes a
  /// request by territory should not have to own a copy of the auth profile.
  /// Null for a guest, and null when the server omits it — callers must have a
  /// sensible answer for that rather than substituting a guess, because a
  /// wrong territory returns somebody else's (or nobody's) rows and looks
  /// exactly like an empty day.
  ///
  /// **This is a filter, never an authorisation claim.** The server derives
  /// the rep from the bearer token; sending a territory only narrows what it
  /// returns.
  String? get territoryCode => _territoryCode;

  /// Whether the signed-in user holds [permission].
  ///
  /// False when unknown, which is the safe direction: a feature that gates on
  /// this simply does not load rather than firing a doomed request.
  bool hasPermission(String permission) => _permissions.contains(permission);

  bool hasAnyPermission(Iterable<String> any) => any.any(_permissions.contains);

  /// True only in [AuthenticationState.authenticated].
  bool get isAuthenticated => _state == AuthenticationState.authenticated;

  AuthenticationState get state => _state;

  /// The gate every protected feature should check before issuing a request.
  ///
  /// A token rotation ([AuthenticationState.refreshingToken]) still counts as
  /// authenticated: the session is valid and the interceptor holds the request
  /// until the new token lands. Everything else — still booting, a guest,
  /// mid-sign-in, or expired — means the call can only fail, and failing it
  /// here costs nothing while failing it at the server costs a round trip and
  /// puts an error banner in front of a user who did nothing wrong.
  bool get canCallProtectedApi =>
      _state == AuthenticationState.authenticated ||
      _state == AuthenticationState.refreshingToken;

  Set<UserRole> get roles => _user?.roles ?? const {UserRole.guest};
  UserRole get primaryRole => _user?.primaryRole ?? UserRole.guest;

  bool can(UserRole role) => _user?.hasRole(role) ?? false;
  bool canAny(Iterable<UserRole> any) => _user?.hasAnyRole(any) ?? false;
  bool canAll(Iterable<UserRole> all) => _user?.hasAllRoles(all) ?? false;

  final _users = StreamController<User?>.broadcast();
  final _states = StreamController<AuthenticationState>.broadcast();

  /// Emits on every session change — feed this to a router's refresh
  /// listenable so redirects re-run on login/logout.
  Stream<User?> get changes => _users.stream;

  /// Emits every lifecycle transition. Use this to react to *why* the session
  /// changed; use [changes] when only the user matters.
  Stream<AuthenticationState> get stateChanges => _states.stream;

  /// A sign-in is in flight.
  void beginAuthentication() => _transition(AuthenticationState.authenticating);

  /// A token rotation is in flight. The user is unchanged.
  void beginRefresh() {
    // Only meaningful while signed in. A refresh cannot start from `guest`,
    // and letting it set the state from there would open the protected-API
    // gate for a user with no session.
    if (_state == AuthenticationState.authenticated) {
      _transition(AuthenticationState.refreshingToken);
    }
  }

  /// A rotation finished successfully — back to a plain valid session.
  void endRefresh() {
    if (_state == AuthenticationState.refreshingToken) {
      _transition(AuthenticationState.authenticated);
    }
  }

  void setUser(User user,
      {Set<String> permissions = const {}, String? territoryCode}) {
    _user = user;
    _permissions = permissions;
    _territoryCode = territoryCode;
    _users.add(user);
    _transition(AuthenticationState.authenticated);
  }

  /// Replaces the signed-in user's details — a name or picture the user just
  /// edited — without touching the session's state, grants or territory.
  ///
  /// Not [setUser]: that also forces [AuthenticationState.authenticated],
  /// which would wrongly end a token rotation that is still in flight.
  void updateUser(User user) {
    if (_user == null) return;
    _user = user;
    _users.add(user);
  }

  /// Drops the session deliberately — sign-out, or boot finding nothing
  /// stored. Lands in [AuthenticationState.guest], which is not an error.
  void clear() {
    _user = null;
    _permissions = const {};
    _territoryCode = null;
    _users.add(null);
    _transition(AuthenticationState.guest);
  }

  /// Drops the session because it can no longer be recovered: the refresh
  /// token was rejected, reused, or revoked.
  ///
  /// Separate from [clear] so the UI can say "your session expired, sign in
  /// again" instead of silently presenting a login screen — and so a feature
  /// can tell a deliberate sign-out from one the server forced.
  void expire() {
    _user = null;
    _permissions = const {};
    _territoryCode = null;
    _users.add(null);
    _transition(AuthenticationState.sessionExpired);
  }

  void _transition(AuthenticationState next) {
    // Distinct transitions only, so a listener rebuilding on state cannot be
    // woken by a no-op.
    if (_state == next) return;
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  void dispose() {
    _users.close();
    _states.close();
  }
}
