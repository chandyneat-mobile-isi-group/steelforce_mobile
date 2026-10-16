/// Transport defaults shared by every API call: timeouts and paging limits.
/// Split out of the former catch-all `AppConstants`.
abstract final class ApiDefaults {
  static const Duration connectTimeout = Duration(seconds: 15);

  static const Duration receiveTimeout = Duration(seconds: 20);

  /// The server clamps `pageSize` to this rather than rejecting a larger
  /// value, so the real size must be read back from `metadata.pageSize`.
  static const int maxPageSize = 200;

  /// The material list is one-based, like every other paged mobile endpoint.
  static const int firstPage = 1;

  /// One catch-up page. Comfortably inside the server's clamp of
  /// [maxPageSize] and large enough that a rep returning from a week offline
  /// drains in a handful of round trips (§6.1).
  static const int notificationPageSize = 100;

  /// Safety stop on the catch-up loop.
  ///
  /// A paging bug — a server that always reports `hasNextPage`, or a cursor that
  /// never advances — would otherwise spin until the app is killed, on a rep's
  /// mobile data. Ten pages is 1,000 notifications, far past any real backlog;
  /// hitting it is a defect and is logged as one rather than silently truncated.
  static const int notificationMaxCatchUpPages = 10;

  /// How long a screen holds its loading state for a fresh API pull before
  /// rendering the local copy anyway.
  ///
  /// Online-first reads (Depots, My Visits): while online, a screen shows what
  /// the API says *now* rather than what was cached last time. But a slow or
  /// half-dead connection must not strand a rep on a skeleton, so past this
  /// the local copy renders and the pull, which keeps running, refreshes the
  /// screen when it lands. Offline, the pull fails fast and the cache shows at
  /// once.
  static const Duration onlineFirstWait = Duration(seconds: 8);
}
