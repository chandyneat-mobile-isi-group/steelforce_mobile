import 'package:steelforce/routes/app_routes.dart';

/// A resolved notification destination.
///
/// [route] is a name `AppPages.onGenerateRoute` understands; [arguments] carries
/// whatever the target screen needs, and [query] the raw query parameters so a
/// screen can read a tab or filter hint (`?tab=credit`, `?filter=quotes`)
/// without re-parsing the URI.
class NotificationDestination {
  const NotificationDestination({
    required this.route,
    this.arguments,
    this.query = const {},
  });

  /// A route name `AppPages.onGenerateRoute` understands.
  ///
  /// Deliberately **not** a shell tab index. Several of these destinations live
  /// inside `MainShell`'s `IndexedStack` and are reached by selecting a tab
  /// rather than pushing, but the index for a given tab is a UI decision owned
  /// by `ShellTab` — in the home feature, which `core/` must not import
  /// (`docs/blueprint/system-architecture.md` §2). So this file names the *destination* and
  /// `NotificationHost` maps it onto a tab. A second copy of the tab indices
  /// here is precisely how a reordered nav bar starts silently opening Orders.
  final String route;

  final Object? arguments;
  final Map<String, String> query;

  @override
  String toString() => 'NotificationDestination($route)';
}

/// Maps the backend's `app://…` URIs onto this app's routes
/// (`docs/feature/notification/README.md` §11).
///
/// ## The backend builds the URI; this only reads it
///
/// §11 is explicit: *"The backend builds these; do not assemble your own from
/// `entity_type` and `entity_id`."* Three clients deriving the same URI is three
/// chances for one of them to get it subtly wrong, and the failure — a
/// notification that opens the wrong screen — is invisible until a rep reports
/// it. So this file parses and routes. It never constructs.
///
/// ## Unroutable is a normal outcome
///
/// An event that points at no single record falls back to `app://notifications`
/// server-side, and a URI naming a screen this build does not have must land
/// somewhere sane rather than nowhere. Both resolve to the inbox: the rep can
/// always read the full notification there, which is the one destination
/// guaranteed to be able to explain itself.
abstract final class NotificationDeepLink {
  const NotificationDeepLink._();

  /// The scheme every notification link uses.
  static const String scheme = 'app';

  /// `app://notifications` — the fallback, and a real destination in its own
  /// right.
  static const String inboxUri = 'app://notifications';

  /// Resolves [link] to a destination, or null when [link] is absent or is not
  /// an `app://` URI at all.
  ///
  /// Returning null for a malformed link — rather than silently substituting the
  /// inbox — lets the caller distinguish "nothing to route to" from "route to
  /// the inbox", which matters because the first should not steal focus from
  /// whatever the rep was already doing.
  static NotificationDestination? resolve(String? link) {
    if (link == null || link.isEmpty) return null;

    final uri = Uri.tryParse(link);
    if (uri == null) return null;
    if (uri.scheme.isNotEmpty && uri.scheme != scheme) return null;

    // `app://routes/{id}` parses with `routes` as the *host* and `{id}` as the
    // single path segment — an authority-form URI, not a path-form one. Joining
    // them back together is what makes one table cover both shapes, including
    // the path-form `/routes/{id}` the web links use.
    final segments = <String>[
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments.where((s) => s.isNotEmpty),
    ];
    final query = uri.queryParameters;

    if (segments.isEmpty) return _inbox(query);

    return switch (segments) {
      // Route detail, and a stop within a route. Both open the visits tab: the
      // route/stop screens live inside `MainShell`'s IndexedStack, so a push on
      // top of the shell would strand the rep with no bottom nav.
      ['routes', final routeId] => NotificationDestination(
          route: Static.myVisits,
          arguments: {'routeId': routeId},
          query: query,
        ),
      ['routes', final routeId, 'stops', final stopId] =>
        NotificationDestination(
          route: Static.myVisits,
          arguments: {'routeId': routeId, 'stopId': stopId},
          query: query,
        ),
      ['today'] => NotificationDestination(
          route: Static.myVisits,
          query: query,
        ),

      // Quotations and orders share the Orders tab, which is where both live.
      ['quotations', final quoteId] => NotificationDestination(
          route: Static.order,
          arguments: {'quotationId': quoteId},
          query: query,
        ),
      ['orders', final orderId] => NotificationDestination(
          route: Static.order,
          arguments: {'orderId': orderId},
          query: query,
        ),
      ['depots', final depotId] => NotificationDestination(
          route: Static.depot,
          arguments: depotId,
          query: query,
        ),
      ['dashboard'] => NotificationDestination(
          route: Static.main,
          query: query,
        ),
      ['notifications'] => _inbox(query),
      ['settings', 'notifications'] => NotificationDestination(
          route: notificationSettingsRoute,
          query: query,
        ),

      // `app://approvals?filter={type}` has no screen in this build yet — the
      // approvals queue is a later phase. Deliberately routed to the inbox
      // rather than dropped: the notification itself carries the approval and
      // its inline actions, so the rep can still act on it. When the queue ships
      // this becomes one more arm here, and nothing else changes.
      ['approvals'] => _inbox(query),

      // Anything this build does not know. §11: handle it gracefully.
      _ => _inbox(query),
    };
  }

  /// True when [link] resolves to something this build can actually open, as
  /// opposed to falling back to the inbox. Lets a caller decide whether a "View"
  /// button is worth offering.
  static bool isRoutable(String? link) {
    final destination = resolve(link);
    return destination != null && destination.route != inboxRoute;
  }

  static NotificationDestination _inbox(Map<String, String> query) =>
      NotificationDestination(route: inboxRoute, query: query);

  /// Route name for the full-screen inbox.
  static const String inboxRoute = '/notifications';

  /// Route name for the notification settings screen.
  static const String notificationSettingsRoute = '/settings/notifications';
}

/// Holds a deep link that arrived before it could be opened.
///
/// ## Why this exists
///
/// §10, terminated state: *"If the session expired, preserve the deep link
/// across login."* A rep taps a route assignment on a cold handset, the cached
/// session turns out to be gone, and they land on a login screen. Dropping the
/// link there means they sign in and see the home screen — with no sign of the
/// thing they were just told about, and no way back to it except finding it in
/// the inbox by hand.
///
/// Also covers the ordinary startup race: `getInitialMessage()` resolves during
/// bootstrap, before any `Navigator` exists, so the link has to wait somewhere
/// for a frame or two regardless of the session.
///
/// A plain mutable holder registered as a singleton, not a stream: exactly one
/// consumer takes exactly one value, and [take] is destructive so a link cannot
/// be opened twice by two listeners racing.
class PendingNotificationLink {
  String? _link;

  /// True when a link is waiting.
  bool get hasLink => _link != null;

  /// Stores [link], replacing any earlier one.
  ///
  /// Last write wins: if two notifications are tapped before either is handled,
  /// the second is the one the rep just chose, and honouring the first would
  /// open a screen they had already moved past.
  void set(String? link) {
    if (link == null || link.isEmpty) return;
    _link = link;
  }

  /// Returns and clears the pending link.
  String? take() {
    final link = _link;
    _link = null;
    return link;
  }

  /// Drops the pending link without opening it — used on sign-out, so one rep's
  /// deep link is not opened for whoever signs in next.
  void clear() => _link = null;
}
