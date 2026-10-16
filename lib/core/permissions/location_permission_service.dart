/// Where the OS location permission stands, in terms this app acts on.
///
/// Deliberately not `geolocator`'s `LocationPermission`: that enum is a plugin
/// type, and `docs/blueprint/system-architecture.md` §2 keeps plugin types out
/// of everything above the platform boundary. It also carries distinctions this
/// app has no use for while missing the one it does — whether location
/// *services* are switched off device-wide, which is a different problem from a
/// permission and needs a different message.
enum LocationPermissionStatus {
  /// Never asked. The explainer is due, and this is the only state from which
  /// asking can still show a prompt on iOS.
  notDetermined,

  /// Granted for foreground use. **This is what the app actually needs** —
  /// capturing a depot's coordinates and verifying a check-in both happen
  /// with the app open.
  whileInUse,

  /// Granted including background. Never requested by the priming dialog: the
  /// tracking service asks for it separately, immediately before it starts a
  /// background route trace, which is both the iOS guideline and what
  /// `GeolocatorTrackingService` already does.
  always,

  /// Declined, but the OS may prompt again.
  denied,

  /// Declined permanently. Only the settings app can change this now, so an
  /// "Enable" button here would be a control that silently does nothing.
  deniedForever,

  /// The permission may be fine, but **location services are off device-wide**.
  ///
  /// A distinct state because the fix is distinct: no amount of granting helps
  /// until the rep turns location on. Telling them to "allow location access"
  /// when the toggle is off sends them to the wrong screen.
  servicesDisabled,

  /// No location provider in this build or on this platform. Not an error.
  unsupported;

  /// True when the app can actually read a position.
  bool get isGranted => this == whileInUse || this == always;

  /// True when asking could still show a prompt.
  bool get canPrompt => this == notDetermined || this == denied;

  /// True when the only remaining route is the OS settings app.
  bool get needsSystemSettings =>
      this == deniedForever || this == servicesDisabled;

  /// True when the rep has said no, however finally.
  bool get isDeclined => this == denied || this == deniedForever;
}

/// The OS location permission, abstracted away from `geolocator`.
///
/// ## Why this exists when two services already call `Geolocator` directly
///
/// `GeolocatorOrderLocationService` and `GeolocatorTrackingService` each request
/// the permission inline, at the moment they need a fix — a depot-registration
/// form tapping "Save GPS", or a route trace starting. That is correct
/// *just-in-time* behaviour and is not being replaced.
///
/// What was missing is the **priming** step. A cold request in the middle of a
/// form gives the rep no reason to say yes, and on iOS a "no" is close to
/// permanent — the same trap
/// `docs/feature/notification/README.md` §14 describes for the push
/// prompt. This interface is what lets one explainer ask for both permissions at
/// a moment the rep can evaluate, before either feature needs one.
///
/// Read-only queries are safe to call at any time. [request] shows a system
/// prompt and must only be called from the explainer.
abstract interface class LocationPermissionService {
  /// The permission as the platform reports it **now**, including whether
  /// location services are switched off device-wide.
  ///
  /// Queried rather than cached: the rep can revoke it, or turn location off
  /// entirely, between two launches.
  Future<LocationPermissionStatus> status();

  /// Shows the OS prompt for **foreground** location.
  ///
  /// Never asks for background ("always"). That escalation belongs immediately
  /// before a background trace starts, where the rep can connect the request to
  /// what it is for — asking up front is how an app gets denied both.
  Future<LocationPermissionStatus> request();

  /// Opens the OS settings page for this app, for a permanent denial.
  ///
  /// Returns false when the platform could not open it, so a caller can avoid
  /// leaving the rep tapping a dead control.
  Future<bool> openSettings();
}
