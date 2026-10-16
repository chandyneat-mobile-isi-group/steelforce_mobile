import 'package:steelforce/core/logging/app_logger.dart';

/// Implemented by anything holding data that belongs to *one signed-in rep*
/// and must not survive them signing out — a draft quotation, an in-progress
/// visit, a cached credit position.
///
/// This exists as an inversion so `authentication` never imports `order` or
/// `my_visits`. Auth owns "the session ended"; each feature owns "here is what
/// that means for my data". Adding a feature means registering one more
/// implementation, not editing the logout path — which is the only way this
/// stays correct as features are added.
///
/// Sign-out leaves nothing behind — master data included: the next session
/// reads the catalog and depot directory from the API again. Because that
/// destroys anything not yet sent, sign-out is gated by `UnsentWorkService`.
abstract interface class SessionScopedStore {
  /// Human-readable name, used only in logs when one store fails.
  String get debugName;

  /// Drops everything tied to the outgoing session. Must be idempotent — it
  /// runs on every sign-out, including ones where there was nothing to clear.
  Future<void> clearForSignOut();
}

/// Fans a sign-out out across every registered [SessionScopedStore].
///
/// One store failing must not strand the others: a cart that refuses to clear
/// cannot be allowed to leave an active visit session behind, and neither may
/// block the user from actually being signed out. So failures are logged and
/// swallowed per store, and the sign-out always completes.
class SessionResetService {
  const SessionResetService(this._stores, this._logger);

  final List<SessionScopedStore> _stores;
  final AppLogger _logger;

  Future<void> clearAll() async {
    for (final store in _stores) {
      try {
        await store.clearForSignOut();
      } catch (e, stack) {
        // Never rethrow: the user pressed logout and is entitled to be logged
        // out regardless of what one feature's local store is doing.
        _logger.error(
          'Session cleanup failed for ${store.debugName}',
          error: e,
          stackTrace: stack,
        );
      }
    }
  }
}
