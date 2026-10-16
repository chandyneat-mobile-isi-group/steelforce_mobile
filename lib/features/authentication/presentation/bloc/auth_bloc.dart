import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/database/drift/local_database_reset.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/session/app_restart_controller.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/core/session/session_scoped_store.dart';
import 'package:steelforce/core/session/unsent_work.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/authentication/domain/entities/auth_profile.dart';
import 'package:steelforce/features/authentication/domain/repositories/auth_repository.dart';
import 'package:steelforce/features/authentication/domain/usecases/get_current_user.dart';
import 'package:steelforce/features/authentication/domain/usecases/login.dart';
import 'package:steelforce/features/authentication/domain/usecases/logout.dart';
import 'package:steelforce/features/authentication/domain/usecases/update_remembered_phone.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_event.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_state.dart';
import 'package:steelforce/features/authentication/domain/notification_lifecycle.dart';
import 'package:steelforce/features/shell/presentation/bloc/home_cubit.dart';
import 'package:steelforce/routes/app_routes.dart';

/// Orchestrates auth use cases and keeps the app-wide [SessionManager] in sync
/// so guards, role checks, and sync scopes have a single, synchronous source
/// of truth for "who is signed in right now".
///
/// Holds no business logic itself — it only maps events to use-case calls and
/// their [Result] into states (+ the matching session mutation).
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required Login login,
    required Logout logout,
    required GetCurrentUser getCurrentUser,
    required SessionManager sessionManager,
    required SessionResetService sessionReset,
    required AppRestartController appRestart,
    required AuthRepository repository,
    required AppLogger logger,
    required NotificationLifecycle notifications,
    UnsentWorkService? unsentWork,
    LocalDataOwnership? dataOwnership,
    UpdateRememberedPhone? updateRememberedPhone,
  })  : _repo = repository,
        _updateRememberedPhone = updateRememberedPhone,
        _unsentWork = unsentWork,
        _dataOwnership = dataOwnership,
        _logger = logger,
        _notifications = notifications,
        _login = login,
        _logout = logout,
        _getCurrentUser = getCurrentUser,
        _session = sessionManager,
        _sessionReset = sessionReset,
        _appRestart = appRestart,
        super(const AuthInitialState()) {
    on<AuthCheckRequested>(_onCheck);
    on<AuthGuestRequested>(_onGuest);
    // `droppable` guards against double-submits: extra taps while a login
    // is in flight are ignored rather than queued.
    on<LoginSubmittedEvent>(_onLogin, transformer: droppable());
    // `droppable` for the same reason as login: sign-out is idempotent but not
    // free — each run clears the stores again and bumps the restart
    // generation, so a double-tap would tear the whole app down twice.
    on<LogoutRequested>(_onLogout, transformer: droppable());
    on<PasswordChangeCompleted>(_onPasswordChangeCompleted,
        transformer: droppable());
  }

  final Login _login;
  final Logout _logout;
  final GetCurrentUser _getCurrentUser;
  final SessionManager _session;
  final SessionResetService _sessionReset;
  final AppRestartController _appRestart;
  final AuthRepository _repo;
  final AppLogger _logger;

  /// The notification feature's sign-in/sign-out hooks.
  ///
  /// A narrow interface rather than the coordinator itself, so authentication
  /// does not depend on the notification feature's data layer — the rule in
  /// `docs/skills/ai-engineering-playbook.md` §12 that no feature imports another
  /// feature's `data/`. It also keeps `AuthBloc` testable without standing up
  /// Firebase.
  final NotificationLifecycle _notifications;

  /// Refuses a sign-out that would wipe work the server does not have yet.
  /// Optional so tests that do not exercise it need not build one.
  final UnsentWorkService? _unsentWork;

  /// Wipes the previous rep's data before a different rep's session starts.
  final LocalDataOwnership? _dataOwnership;

  /// Applies the login form's "Remember me". Optional so tests that do not
  /// exercise it need not build one.
  final UpdateRememberedPhone? _updateRememberedPhone;

  /// Session restore on boot. A cached session promotes to [AuthenticatedState];
  /// its absence is *not* an error here — the user simply continues as a guest,
  /// free to browse until they hit a protected feature.
  Future<void> _onCheck(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingState());
    final result = await _getCurrentUser(const NoParams());
    await _claimLocalData(result);
    emit(result.when(
      success: (profile) {
        final user = profile.toUser();
        // Permissions travel with the restored session, so a feature gated on
        // `depots.read` knows the answer before its first request rather
        // than discovering it as a 403.
        _session.setUser(user,
            permissions: profile.permissions,
            territoryCode: profile.territoryCode);
        return AuthenticatedState(user,
            passwordChangeRequired: profile.passwordChangeRequired);
      },
      failure: (_) {
        _session.clear();
        return const AuthGuestState();
      },
    ));
  }

  void _onGuest(AuthGuestRequested event, Emitter<AuthState> emit) {
    _session.clear();
    emit(const AuthGuestState());
  }

  Future<void> _onLogin(
    LoginSubmittedEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingState());
    // Global lifecycle, separate from this bloc's presentation state: while a
    // sign-in is in flight the protected-API gate stays shut, so a feature
    // cannot fire a request against a session that does not exist yet.
    _session.beginAuthentication();
    final result = await _login(
      LoginParams(
        identifier: event.identifier,
        password: event.password,
        rememberDevice: event.rememberDevice,
      ),
    );
    // A single request: `/mobile/auth/login` returns the token pair directly.
    // The only one-time code in the app guards password *reset*.
    await _claimLocalData(result);
    // Only once the number is known to be right: a rejected sign-in leaves
    // whatever was remembered before. A storage failure here is not worth
    // failing a good sign-in over — the form is simply not pre-filled.
    if (result is Success<AuthProfile>) {
      await _updateRememberedPhone
          ?.call(event.rememberPhone ? event.identifier : null);
    }
    emit(result.when(
      // `login` resolves the full profile — permissions and feature flags
      // included — but the session only needs the narrower [User] shape that
      // guards and role checks read.
      success: (profile) {
        final user = profile.toUser();
        _session.setUser(user,
            permissions: profile.permissions,
            territoryCode: profile.territoryCode);
        return AuthenticatedState(user,
            passwordChangeRequired: profile.passwordChangeRequired);
      },
      // Never retry a rejected password automatically: five failures lock the
      // account for fifteen minutes, and three background retries would spend
      // three of them.
      failure: (f) => AuthFailureState(_messageFor(f)),
    ));
  }

  /// The server has already accepted the new password; this only forgets the
  /// flag locally. A cache failure is logged, not surfaced — the rep is in,
  /// and at worst the next launch asks again.
  Future<void> _onPasswordChangeCompleted(
    PasswordChangeCompleted event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _repo.markPasswordChanged();
    result.when(
      success: (_) {},
      failure: (_) => _logger.warning('auth.password_change.flag_not_cleared'),
    );
    final user = _session.currentUser;
    if (user != null) emit(AuthenticatedState(user));
  }

  /// The text to put in front of the user for [failure].
  ///
  /// Failures raised *by the client* carry English literals written for
  /// developers, and showing those verbatim is why a Khmer session displayed
  /// "No internet connection." in English. Those are translated here, in the
  /// presentation layer, where `.tr` belongs.
  ///
  /// Server failures keep [Failure.message] as-is: the API already localised
  /// it against the `Accept-Language` header this app sends on every request.
  String _messageFor(Failure failure) => switch (failure) {
        NetworkFailure() => 'common.no_connection'.tr,
        // Distinct from the above on purpose: the device *has* a network, so
        // telling the user to check their connection sends them hunting for a
        // problem that is not theirs.
        ServerUnreachableFailure() => 'common.server_unreachable'.tr,
        _ => failure.message,
      };

  /// Signing out drops the token store, every session-scoped feature store,
  /// and the in-memory session, in that order.
  ///
  /// Ordering matters: tokens go first so a request racing the sign-out cannot
  /// be authorized, and [SessionManager.clear] goes last because it is what
  /// notifies listeners the session ended — anything reacting to that must
  /// find the underlying stores already empty rather than half-cleared.
  ///
  /// The emitted state is [AuthGuestState] rather than a dedicated
  /// "logged out" one: this app is guest-first, so "signed out" and "browsing
  /// as a guest" are genuinely the same authorization level. Where the user
  /// *lands* is the caller's decision, not this bloc's.
  /// Restarting the app is part of signing out, not something the caller has
  /// to remember to do afterwards.
  ///
  /// It cannot be driven off the emitted state either: [AuthGuestState] is an
  /// `Equatable` with no props, so every instance compares equal and bloc
  /// suppresses the emit whenever guest was already the current state. A
  /// screen waiting for that state to arrive waits forever — which is exactly
  /// why the first version of this appeared to do nothing. Restarting here
  /// makes it unconditional, and gives every future sign-out entry point the
  /// same behaviour for free.
  Future<void> _onLogout(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Sign-out wipes the local database, so it is refused while work saved
    // on this device has not reached the server. The profile screen checks
    // first and tells the rep; this is the backstop for any other caller.
    final unsent = await _unsentWork?.count() ?? 0;
    if (unsent > 0) {
      _logger.warning('auth.logout_blocked_unsent_work',
          fields: {'count': unsent});
      return;
    }

    // **Before** the token store is dropped, and that ordering is the whole
    // point (`docs/feature/notification/README.md` §4.4): deregistering this
    // installation is an authenticated call. Skipping it leaves the platform
    // pushing one rep's notifications at a handset that has since been handed to
    // somebody else — which is a disclosure, not an inconvenience.
    //
    // It also clears the locally-mirrored inbox and any queued acknowledgements,
    // so the next rep neither reads the previous one's notifications nor has
    // their queue replayed under a new token.
    //
    // Deliberately not fatal: a rep who cannot sign out because a deregistration
    // failed is worse than a stale registration, which the backend deactivates
    // on its own once FCM reports the token dead.
    try {
      await _notifications.onSigningOut();
    } catch (error, stackTrace) {
      _logger.error('auth.logout_notification_cleanup_failed',
          error: error, stackTrace: stackTrace);
    }

    await _logout(LogoutParams(allDevices: event.allDevices));
    await _sessionReset.clearAll();
    _session.clear();

    // Reset shell navigation tab to Home (Main Screen)
    try {
      if (GetIt.instance.isRegistered<ShellTabController>()) {
        GetIt.instance<ShellTabController>().goTo(ShellTab.home);
      }
    } catch (_) {}

    emit(const AuthGuestState());

    // Rebuild the tree and ensure redirection to the main screen
    _appRestart.restart();
    try {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        Static.main,
        (route) => false,
      );
    } catch (e) {
      _logger.warning('auth.logout_redirect_fallback',
          fields: {'error': e.toString()});
    }
  }

  /// Ties the local data to the rep who just signed in, wiping it first if
  /// it belongs to someone else. Never blocks the sign-in: a failure here is
  /// logged, and the rep still gets in.
  Future<void> _claimLocalData(Result<AuthProfile> result) async {
    final ownership = _dataOwnership;
    if (ownership == null) return;
    final userId = result.when(success: (p) => p.id, failure: (_) => null);
    if (userId == null) return;
    try {
      await ownership.claim(userId);
    } catch (error, stackTrace) {
      _logger.error('auth.local_data_claim_failed',
          error: error, stackTrace: stackTrace);
    }
  }
}
