import 'package:steelforce/core/database/drift/daos/notification_dao.dart';
import 'package:steelforce/core/network/api/api_defaults.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/notification/data/models/notification_drift_mappers.dart';
import 'package:steelforce/features/notification/data/remote/notification_remote_data_source.dart';

/// Walks `GET /me/notifications` keyset pages into the local mirror.
///
/// The endpoint pages newest first by an opaque `nextCursor` and has no
/// "changed since" filter, so the two jobs are:
///
///  * [catchUp] — newest pages until one reaches rows the device already
///    holds, so nothing that arrived while away is skipped;
///  * [loadOlder] — the next older page for the All or Unread list, for
///    infinite scroll.
///
/// Rows are upserted by id, so a page fetched twice never duplicates one.
/// Cursors live in memory: after a restart the walk starts again from the
/// newest page and steps over pages the mirror already holds.
class InboxPager {
  InboxPager({
    required NotificationRemoteDataSource remote,
    required NotificationDao dao,
    this.pageSize = ApiDefaults.notificationPageSize,
    this.maxPages = ApiDefaults.notificationMaxCatchUpPages,
  })  : _remote = remote,
        _dao = dao;

  final NotificationRemoteDataSource _remote;
  final NotificationDao _dao;
  final int pageSize;

  /// Safety stop per call: a cursor that never ends must not spin on a rep's
  /// mobile data.
  final int maxPages;

  /// `NOTIFICATION_CURSOR_INVALID` (400) — the cursor no longer decodes.
  static const String cursorInvalidCode = 'NOTIFICATION_CURSOR_INVALID';

  /// Next cursor per list, keyed by `unreadOnly`. A present null means that
  /// list reached its end.
  final Map<bool, String?> _next = {};
  final Map<bool, Future<bool>> _inFlight = {};

  /// Pulls the newest page, then — when the mirror already held rows — newer
  /// pages until one overlaps them, so a gap left while away is filled. A
  /// fresh mirror, or [full], takes the newest page only: older history comes
  /// page by page through [loadOlder] as the rep scrolls.
  Future<({int received, int pages})> catchUp({required bool full}) async {
    if (full) _next.clear();
    final closeGap = !full && await _dao.hasRows();
    String? cursor;
    var pages = 0;
    var received = 0;
    do {
      final page = await _remote.fetchPage(cursor: cursor, limit: pageSize);
      pages++;
      received += page.items.length;
      final known = await _store(page);
      cursor = page.nextCursor;
      if (!closeGap || known > 0) break;
    } while (cursor != null && pages < maxPages);

    // The All list scrolls on from where this walk stopped, unless it is
    // already further down.
    _next.putIfAbsent(false, () => cursor);
    return (received: received, pages: pages);
  }

  /// Stores the next older page of the All list, or of the Unread list when
  /// [unreadOnly]. True while older pages remain. A call while one runs for
  /// the same list joins it rather than fetching the same page twice.
  Future<bool> loadOlder({required bool unreadOnly}) {
    // A block, not `=> _inFlight.remove(…)`: that returns this very future,
    // and `whenComplete` would wait on it — forever.
    return _inFlight[unreadOnly] ??= _loadOlder(unreadOnly).whenComplete(() {
      _inFlight.remove(unreadOnly);
    });
  }

  /// Forgets every cursor — on sign-out, so the next user starts fresh.
  void reset() => _next.clear();

  Future<bool> _loadOlder(bool unreadOnly) async {
    if (_next.containsKey(unreadOnly) && _next[unreadOnly] == null) {
      return false;
    }
    var cursor = _next[unreadOnly];
    var restarted = false;
    for (var pages = 0; pages < maxPages; pages++) {
      final NotificationPage page;
      try {
        page = await _remote.fetchPage(
            cursor: cursor, limit: pageSize, unreadOnly: unreadOnly);
      } on ApiException catch (e) {
        // `serverCode`: `code` is normalised from the status (a 400 reads
        // `General.Validation`); the backend's own code is kept beside it.
        final invalid = e.error.serverCode == cursorInvalidCode;
        if (!invalid || cursor == null || restarted) {
          rethrow;
        }
        // The server no longer accepts this cursor: walk again from the
        // newest page; rows already held are stepped over below.
        restarted = true;
        cursor = null;
        continue;
      }
      final known = await _store(page);
      cursor = page.nextCursor;
      _next[unreadOnly] = cursor;
      if (cursor == null) return false;
      // A page the mirror already held showed the rep nothing new.
      if (known < page.items.length) return true;
    }
    return true;
  }

  /// Upserts [page] and returns how many of its rows were already stored.
  Future<int> _store(NotificationPage page) async {
    if (page.items.isEmpty) return 0;
    final known = await _dao.knownIds(page.items.map((item) => item.id));
    await _dao.upsertPage([for (final item in page.items) item.toRow()]);
    return known.length;
  }
}
