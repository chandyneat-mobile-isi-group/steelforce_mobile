import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/utils/typedefs.dart';

/// Mixin for anything that loads data from a protected endpoint.
///
/// Authentication is a platform capability, not a per-feature one. Before this
/// existed, each cubit that wanted to be careful wrote its own
/// `if (!session.isAuthenticated) return;` — and the ones that forgot fired a
/// request during boot that could only be rejected. The depot directory did
/// exactly that: it ran a full initial sync on every cold start *before*
/// sign-in, producing one guaranteed failure per launch and an error banner in
/// front of a user who had done nothing wrong.
///
/// Usage:
///
/// ```dart
/// class DepotSyncCubit extends Cubit<DepotSyncState>
///     with ProtectedFeature {
///   @override
///   final SessionManager session;
///
///   Future<void> load() => whenAuthenticated(() async {
///         // only runs with a live session
///       });
/// }
/// ```
///
/// A feature author never writes `checkToken`, `getToken`, `refreshToken`,
/// `handle401` or `redirectLogin` — the interceptor and [SessionManager] own
/// all of that. The only decision left here is *whether to ask at all*.
mixin ProtectedFeature {
  /// The global session. Inject it; do not resolve it from the locator inside
  /// the mixin, or the feature becomes untestable without a container.
  SessionManager get session;

  /// The grant this feature's endpoints require, e.g. `depots.read`.
  ///
  /// Override it and [canLoad] additionally checks the signed-in user holds it.
  /// Null means "any authenticated user".
  ///
  /// This is what the depots guide means by *"read the caller's permissions
  /// from `GET /auth/me` and hide actions they lack"*. It is a usability
  /// measure, never a security control — the server re-checks every one. Its
  /// job is to stop the app firing a request that can only come back 403, as
  /// the depot sync did twice per launch for a rep whose role granted
  /// `outlets.*` but not `depots.*`.
  /// Empty means "any authenticated user". Multiple entries are **any-of**,
  /// not all-of: the same capability is spelled `depots.read` on one
  /// deployment and `outlets.read` on another, and a feature needs either.
  Set<String> get requiredPermissions => const {};

  /// True when a protected request can legitimately be made right now.
  ///
  /// Deliberately [SessionManager.canCallProtectedApi] rather than
  /// `isAuthenticated`: a request raised during a token rotation is fine — the
  /// interceptor holds it until the new token lands — whereas one raised while
  /// still booting, as a guest, or after expiry can only fail.
  bool get canLoad {
    if (!session.canCallProtectedApi) return false;
    final required = requiredPermissions;
    return required.isEmpty || session.hasAnyPermission(required);
  }

  /// Why [canLoad] is false, for a log line or an empty-state message.
  String get blockedReason {
    if (!session.canCallProtectedApi) return 'session:${session.state.name}';
    return 'permission:${requiredPermissions.join("|")}';
  }

  /// Runs [action] only with a live session, otherwise does nothing.
  ///
  /// Silence is the correct behaviour for a *background* load — a guest
  /// browsing the app has not asked for this data and should not be shown an
  /// error about it. For a load the user explicitly triggered, prefer
  /// [guardedCall] so the refusal is visible, or `AuthGuard` at the tap site
  /// so they get the login prompt.
  Future<void> whenAuthenticated(Future<void> Function() action) async {
    if (!canLoad) return;
    await action();
  }

  /// [Result]-returning twin of [whenAuthenticated].
  ///
  /// Returns an [AuthenticationFailure] rather than attempting the call, so
  /// the caller's existing failure branch reports "sign in to continue"
  /// instead of a network error the user cannot act on.
  ResultFuture<T> guardedCall<T>(ResultFuture<T> Function() action) async {
    if (!canLoad) {
      return Failed(AuthenticationFailure(
        message: switch (session.state) {
          AuthenticationState.sessionExpired =>
            'Your session expired. Please sign in again.',
          AuthenticationState.initializing =>
            'Still starting up. Try again in a moment.',
          // Authenticated but not permitted — a different problem, and telling
          // this user to sign in would send them round a loop they cannot win.
          _ when session.canCallProtectedApi =>
            'Your account does not have access to this.',
          _ => 'Sign in to continue.',
        },
        statusCode: 401,
      ));
    }
    return action();
  }
}
