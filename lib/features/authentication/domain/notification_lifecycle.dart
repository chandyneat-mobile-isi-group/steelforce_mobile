/// The notification-side effects of signing in and out, as authentication sees
/// them.
///
/// ## Why this interface exists rather than a direct call
///
/// `docs/feature/notification/README.md` §4.4 requires the device
/// deregistration to happen **before** the access token is discarded, which puts
/// it squarely inside `AuthBloc._onLogout`. But a feature must not import
/// another feature's `data/` layer (`docs/skills/ai-engineering-playbook.md` §12), and
/// `AuthBloc` reaching for `NotificationCoordinator` — which owns Firebase, a
/// Drift DAO and three repositories — would make every authentication test stand
/// all of that up.
///
/// So authentication declares the two moments it can report, and the
/// notification feature implements them. The dependency points inward, and
/// `AuthBloc` stays testable with a two-method fake.
abstract interface class NotificationLifecycle {
  /// A session has just been established.
  ///
  /// Registers this installation (§4.1: "after every successful login") and
  /// pulls the new rep's inbox from scratch — the cursor and the rows belong to
  /// whoever was signed in before.
  Future<void> onSignedIn();

  /// A sign-out is starting, and the access token is **still valid**.
  ///
  /// Deregisters the installation while the call can still be authorised, then
  /// clears the locally-mirrored inbox, the queued acknowledgements and the
  /// cached preferences — all of which are rep-scoped.
  Future<void> onSigningOut();
}
