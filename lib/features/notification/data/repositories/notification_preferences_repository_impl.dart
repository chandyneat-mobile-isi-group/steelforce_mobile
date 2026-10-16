import 'package:steelforce/core/database/hive/preference_keys.dart';
import 'package:steelforce/core/database/hive/local_cache.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/notification/data/models/notification_api_mapper.dart';
import 'package:steelforce/features/notification/data/remote/notification_remote_data_source.dart';
import 'package:steelforce/features/notification/domain/entities/notification_preferences.dart';
import 'package:steelforce/features/notification/domain/repositories/notification_preferences_repository.dart';

/// Notification settings, server-owned with a local cache
/// (`docs/feature/notification/README.md` §13).
///
/// ## Why Hive and not the encrypted database
///
/// These are the rep's own toggles and quiet-hours window — settings, not
/// business records and not PII — and they are regenerable from the server on
/// demand. `docs/blueprint/system-architecture.md` §3 puts exactly that class of data in the
/// key-value cache, which also means adding this feature needed no schema
/// migration for it. The **notifications themselves** do go in the encrypted
/// database, because a title and body name a depot and a route.
///
/// ## The cache is never authoritative
///
/// Preferences follow the rep across devices, so a toggle changed on another
/// handset must appear here. Every successful [load] therefore *replaces* the
/// cached document rather than merging into it. The cache exists so the settings
/// screen opens with content instead of a spinner, and so it renders something
/// truthful offline.
class NotificationPreferencesRepositoryImpl
    implements NotificationPreferencesRepository {
  NotificationPreferencesRepositoryImpl({
    required NotificationRemoteDataSource remote,
    required LocalCache cache,
    required SessionManager session,
    required AppLogger logger,
  })  : _remote = remote,
        _cache = cache,
        _session = session,
        _logger = logger;

  final NotificationRemoteDataSource _remote;
  final LocalCache _cache;
  final SessionManager _session;
  final AppLogger _logger;

  @override
  ResultFuture<NotificationPreferences> load() async {
    if (!_session.canCallProtectedApi) {
      // A guest has no settings. Returning `unset` rather than a failure is
      // correct and load-bearing: §13 says absence of a record means
      // "everything on", so this renders a complete, honest screen with every
      // category enabled rather than an error over settings that do exist.
      return const Success(NotificationPreferences.unset);
    }

    try {
      final preferences = await _remote.fetchPreferences();
      await _write(preferences);
      return Success(preferences);
    } on ApiException catch (e) {
      final cached = await this.cached();
      if (cached != null) {
        // Offline, or the gateway is down. The rep sees their real settings and
        // a save will fail loudly if they try — better than an error screen over
        // toggles they can already read.
        _logger.info('notifications.preferences_from_cache',
            fields: {'code': e.error.code});
        return Success(cached);
      }
      _logger.warning('notifications.preferences_failed', fields: {
        'code': e.error.code,
        'status': e.error.statusCode,
      });
      if (e.error.code == ApiErrorCodes.network) {
        return const Failed(NetworkFailure());
      }
      return Failed(ServerFailure(
        message:
            e.error.message ?? 'Could not load your notification settings.',
        statusCode: e.error.statusCode,
      ));
    }
  }

  @override
  Future<NotificationPreferences?> cached() async {
    try {
      final raw = _cache
          .get<Map<String, dynamic>>(PreferenceKeys.kNotificationPreferences);
      if (raw == null) return null;
      return NotificationApiMapper.preferencesFromJson(raw);
    } catch (_) {
      // Broad by necessity: `LocalCache.get` decodes without a guard of its own,
      // so a truncated entry surfaces here as a `FormatException` and a
      // shape change as a `TypeError`. Either way the entry is dropped rather
      // than re-parsed on every screen open. Nothing is lost — the document is
      // regenerable from the server, which is precisely why it is cached and
      // not stored.
      _logger.warning('notifications.preferences_cache_corrupt');
      await _cache.remove(PreferenceKeys.kNotificationPreferences);
      return null;
    }
  }

  @override
  ResultFuture<NotificationPreferences> save(
      NotificationPreferences preferences) async {
    if (!_session.canCallProtectedApi) {
      return const Failed(AuthenticationFailure(
        message: 'Sign in to change your notification settings.',
      ));
    }

    try {
      final saved = await _remote.savePreferences(preferences);
      await _write(saved);
      return Success(saved);
    } on ApiException catch (e) {
      // Deliberately **not** queued for offline replay, unlike inbox mutations.
      // This is a whole-document overwrite with no server-side merge, so a stale
      // document replayed after a reconnect would silently clobber a change the
      // rep made on another handset in the meantime. Failing and letting them
      // retry is honest; reverting another device's settings is not.
      _logger.warning('notifications.preferences_save_failed', fields: {
        'code': e.error.code,
        'status': e.error.statusCode,
      });

      if (e.error.code == ApiErrorCodes.network) {
        return const Failed(NetworkFailure());
      }
      // `422 Notification.CategoryNotMutable` and
      // `400 Notification.QuietHoursIncomplete` both arrive here with a
      // server-localised `message`, which §15 says to key user-facing copy off
      // the `errorCode` for. The mapper already prevents both by construction —
      // it omits locked categories and drops a half-set window — so reaching
      // this branch with one of those codes means the contract moved.
      return Failed(ServerFailure(
        message:
            e.error.message ?? 'Could not save your notification settings.',
        statusCode: e.error.statusCode,
      ));
    }
  }

  @override
  Future<void> clear() =>
      _cache.remove(PreferenceKeys.kNotificationPreferences);

  Future<void> _write(NotificationPreferences preferences) {
    // Round-tripped through the API shape rather than a bespoke cache format, so
    // the reader is `preferencesFromJson` — one parser for both paths. A second
    // format would be a second thing to keep in step with the API.
    final json = NotificationApiMapper.preferencesToJson(preferences);
    // `preferencesToJson` omits locked categories, because sending one back
    // risks a 422 on a value the rep never touched. The cache needs them, or a
    // screen opened offline would show only the three mutable rows and look as
    // though the locked ones had disappeared.
    json['categories'] = [
      for (final category in preferences.categories)
        {
          'category': category.category,
          'displayName': category.displayName,
          'isEnabled': category.isEnabled,
          'pushEnabled': category.pushEnabled,
          'isLocked': category.isLocked,
        },
    ];
    // No TTL. A stale document is never shown as fresh — every [load] replaces
    // it from the server, and the cache is only ever read when that call failed.
    // Expiring it would leave a rep who is offline with no settings screen at
    // all, which is worse than one whose toggles are a day old.
    return _cache.set(PreferenceKeys.kNotificationPreferences, json);
  }
}
