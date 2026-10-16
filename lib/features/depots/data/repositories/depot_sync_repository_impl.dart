import 'package:steelforce/core/network/api/api_defaults.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/localization/active_language.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/local/depot_local_data_source.dart';
import 'package:steelforce/features/depots/data/remote/depot_remote_data_source.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_code_lookup.dart';
import 'package:steelforce/features/depots/domain/entities/depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/depot_sync_result.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_sync_repository.dart';

const _depotsEntity = 'depots';

/// Default language reader. Safe to call in a unit test: the underlying service
/// holds a plain `'en'` field until assets are loaded, so this touches no
/// Flutter binding.
String _activeLanguageTag() => ActiveLanguage.acceptLanguageTag;

/// The only repository allowed to touch [DepotRemoteDataSource] — this
/// is where "a Depot row only ever comes from SAP" is enforced: nothing
/// in this feature calls `_local.upsertDepots` except the two sync
/// methods below.
class DepotSyncRepositoryImpl implements DepotSyncRepository {
  const DepotSyncRepositoryImpl({
    required DepotRemoteDataSource remote,
    required DepotLocalDataSource local,
    required NetworkInfo network,
    required AppLogger logger,
    String Function() readLanguageTag = _activeLanguageTag,
  })  : _remote = remote,
        _local = local,
        _network = network,
        _logger = logger,
        _readLanguageTag = readLanguageTag;

  final DepotRemoteDataSource _remote;
  final DepotLocalDataSource _local;
  final NetworkInfo _network;
  final AppLogger _logger;

  /// Reads the `Accept-Language` tag the requests will carry.
  ///
  /// Injected rather than read from [ActiveLanguage] directly so a test can
  /// simulate the rep switching language without a Flutter binding.
  final String Function() _readLanguageTag;

  static const _pageSize = ApiDefaults.maxPageSize;

  /// A page run that never terminates would spin forever against a server
  /// whose `hasNextPage` is stuck true. At 200 rows a page this ceiling is
  /// 200 000 depots — far past any real territory.
  static const _maxPages = 1000;

  @override
  ResultFuture<DateTime?> lastSyncedAt() async {
    try {
      return Success(await _local.getLastSyncedAt(_depotsEntity));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<DepotSyncResult> runInitialSync() async {
    if (!await _network.isConnected) return const Failed(NetworkFailure());
    try {
      var page = 1; // The API is one-based.
      var total = 0;
      DateTime? watermark;

      _logger
          .info('depots.sync.initial.start', fields: {'pageSize': _pageSize});

      while (page <= _maxPages) {
        final result =
            await _remote.fetchInitial(page: page, pageSize: _pageSize);

        // Captured from the *first* page and then held. Taking it from the
        // last page instead would skip anything that changed while the run
        // was in flight: those rows are already in the pages fetched so far
        // or will arrive in the next delta, but only if the watermark still
        // points at the moment the run began.
        watermark ??= result.syncTimestamp;

        _logger.debug('depots.sync.initial.page', fields: {
          'page': page,
          'rows': result.items.length,
          // The size the server actually used, which it clamps silently.
          'serverPageSize': result.pageSize,
          'hasMore': result.hasMore,
        });

        if (result.items.isNotEmpty) {
          await _local.upsertDepots(result.items);
          total += result.items.length;
        }
        if (!result.hasMore) break;
        page++;
      }

      if (watermark == null) {
        // Without a server timestamp the next delta has to fall back to the
        // device clock's idea of now, which is exactly the drift this design
        // avoids. Worth noticing rather than silently absorbing.
        _logger.warning('depots.sync.initial.noServerTimestamp');
      }

      // Advanced only now the whole run has been committed. Advancing per page
      // means an interrupted sync skips everything between the last committed
      // page and the stored timestamp — permanently, because nothing ever
      // asks for that window again.
      final syncedAt = watermark ?? DateTime.now().toUtc();
      // The language is stored with the watermark, not separately: the rows
      // just written are localised for it, and a watermark that outlived its
      // language would let the next delta resume against text the user can no
      // longer read.
      final language = _readLanguageTag();
      await _local.setLastSyncedAt(
        _depotsEntity,
        syncedAt,
        language: language,
      );

      _logger.info('depots.sync.initial.done', fields: {
        'pages': page,
        'upserted': total,
        'watermark': syncedAt.toIso8601String(),
        'language': language,
      });

      return Success(
          DepotSyncResult(upserted: total, deleted: 0, syncedAt: syncedAt));
    } on ApiException catch (e) {
      _logger.error('depots.sync.initial.failed', fields: {
        'errorCode': e.error.code,
        'status': e.error.statusCode,
        'correlationId': e.error.correlationId,
      });
      return Failed(_failure(e.error));
    } on ServerException catch (e) {
      return Failed(
          ServerFailure(message: e.message, statusCode: e.statusCode));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<DepotSyncResult> runDeltaSync() async {
    if (!await _network.isConnected) return const Failed(NetworkFailure());
    try {
      final since = await _local.getLastSyncedAt(_depotsEntity);
      if (since == null) {
        _logger.info('depots.sync.delta.noWatermark');
        return runInitialSync();
      }

      // A language switch invalidates the whole book, and a delta cannot
      // repair it: `shopName` is localised server-side, so the rows only carry
      // the language they were fetched under, and `modifiedSince` returns what
      // the *server* changed — which a device-side language change is not.
      // Without this the directory renders the old language indefinitely.
      //
      // A null stored language means "synced before this was recorded"; that
      // is treated as a match rather than putting every upgrading device
      // through a full re-page for a book almost certainly already correct.
      final storedLanguage = await _local.getSyncedLanguage(_depotsEntity);
      final language = _readLanguageTag();
      if (storedLanguage != null && storedLanguage != language) {
        _logger.info('depots.sync.delta.languageChanged', fields: {
          'from': storedLanguage,
          'to': language,
        });
        return runInitialSync();
      }

      _logger.info('depots.sync.delta.start',
          fields: {'since': since.toIso8601String()});

      var page = 1;
      var upserted = 0;
      var deleted = 0;
      DateTime? watermark;

      while (page <= _maxPages) {
        final delta = await _remote.fetchDelta(
          since: since,
          page: page,
          pageSize: _pageSize,
        );
        watermark ??= delta.syncTimestamp;

        _logger.debug('depots.sync.delta.page', fields: {
          'page': page,
          'upserted': delta.upserted.length,
          // If this is always zero while records vanish server-side, the
          // tombstones are not arriving and local copies will linger forever.
          'tombstones': delta.deletedIds.length,
          'hasMore': delta.hasMore,
        });

        if (delta.upserted.isNotEmpty) {
          await _local.upsertDepots(delta.upserted);
          upserted += delta.upserted.length;
        }
        // Tombstones. Dropping these would leave a depot deleted on the
        // server visible on the phone indefinitely.
        if (delta.deletedIds.isNotEmpty) {
          await _local.markDeleted(delta.deletedIds);
          deleted += delta.deletedIds.length;
        }

        if (!delta.hasMore) break;
        page++;
      }

      // Fall back to the previous watermark rather than to `now`. A server
      // that returned no timestamp must not cause the window between `since`
      // and now to be skipped — repeating a delta is free, missing one is not.
      final syncedAt = watermark ?? since;
      await _local.setLastSyncedAt(
        _depotsEntity,
        syncedAt,
        language: language,
      );

      _logger.info('depots.sync.delta.done', fields: {
        'pages': page,
        'upserted': upserted,
        'deleted': deleted,
        'watermark': syncedAt.toIso8601String(),
        // True when the watermark did not move, so the next delta will re-ask
        // for the same window.
        'watermarkHeld': watermark == null,
      });

      return Success(DepotSyncResult(
        upserted: upserted,
        deleted: deleted,
        syncedAt: syncedAt,
      ));
    } on ApiException catch (e) {
      // A rejected `modifiedSince` means the stored watermark is unusable —
      // most likely a future timestamp written from a device clock by an older
      // build. Left alone it is terminal: every delta from here on fails the
      // same way and the device silently never syncs again.
      //
      // Recovery is to ignore the watermark and re-page from scratch, which
      // rewrites it from the server's clock. Bounded by construction — the
      // initial sync sends no `modifiedSince`, so it cannot land back here.
      if (_isRejectedWatermark(e.error)) {
        _logger.warning('depots.sync.delta.watermarkRejected', fields: {
          'errorCode': e.error.code,
          'correlationId': e.error.correlationId,
        });
        return runInitialSync();
      }

      _logger.error('depots.sync.delta.failed', fields: {
        'errorCode': e.error.code,
        'status': e.error.statusCode,
        'correlationId': e.error.correlationId,
        'invalidFields': e.error.fieldErrors.keys.toList(),
      });
      return Failed(_failure(e.error));
    } on ServerException catch (e) {
      return Failed(
          ServerFailure(message: e.message, statusCode: e.statusCode));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> hydrateDepot(String id) async {
    if (!await _network.isConnected) return const Failed(NetworkFailure());
    try {
      final depot = await _remote.fetchById(id);
      await _local.upsertDepots([depot]);
      return const Success(null);
    } on ApiException catch (e) {
      // A depot outside the caller's row-level scope returns 404, not 403 —
      // distinguishing them would confirm that a given depot exists, which
      // is exactly what a competitor probing the API wants to learn. So a 404
      // here means "not there", never "access denied", and the caller should
      // present it that way.
      return Failed(_failure(e.error));
    } on ServerException catch (e) {
      return Failed(
          ServerFailure(message: e.message, statusCode: e.statusCode));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<Depot> createDepot(DepotDraft draft) async {
    if (!await _network.isConnected) return const Failed(NetworkFailure());

    _logger.info('depots.create.start', fields: {
      'type': draft.type,
      // Whether a fix was captured at all is the useful signal; the position
      // itself is depot data and stays out of the log.
      'hasCoordinates': draft.hasCoordinates,
      'contacts': draft.contacts.length,
    });

    try {
      final created = await _remote.create(draft);

      // The server's version, not the draft: it carries the assigned id, the
      // `Draft` status and the SAP block the client may not set.
      await _local.upsertDepots([created]);

      _logger.info('depots.create.done', fields: {
        'status': created.status.name,
      });
      return Success(created);
    } on ApiException catch (e) {
      _logger.error('depots.create.failed', fields: {
        'errorCode': e.error.code,
        'status': e.error.statusCode,
        'correlationId': e.error.correlationId,
        // `General.Validation` is the default path for bad input — request
        // validation runs before the domain sees the payload, so an
        // unrecognised `type` or a half-supplied coordinate pair lands here
        // rather than as its specific code.
        'invalidFields': e.error.fieldErrors.keys.toList(),
      });
      return Failed(_failure(e.error));
    } on ServerException catch (e) {
      return Failed(
          ServerFailure(message: e.message, statusCode: e.statusCode));
    } on CacheException catch (e) {
      // The depot exists on the server; only the local copy failed. Report
      // it rather than claiming the registration failed — the next sync will
      // bring the row down.
      return Failed(CacheFailure(message: e.message));
    }
  }

  /// True when the server refused the request *because of* the stored
  /// watermark, rather than for any other reason.
  ///
  /// Deliberately narrow. A blanket "400 means resync" would turn every
  /// unrelated validation error into a 31-request re-page, so this requires the
  /// server to have named `modifiedSince` as the offending parameter — which
  /// it does, in the per-field `errors` map documented for `General.Validation`.
  bool _isRejectedWatermark(ApiError error) {
    final status = error.statusCode;
    if (status != 400) return false;
    return error.fieldError('modifiedSince') != null;
  }

  @override
  ResultFuture<DepotCodeLookup> lookupByCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      return const Success(DepotCodeAbsent());
    }
    if (!await _network.isConnected) return const Failed(NetworkFailure());

    // The code itself is depot data, so only its shape is logged.
    _logger.info('depots.lookupByCode.start',
        fields: {'codeLength': trimmed.length});

    try {
      final outcome = await _remote.lookupByCode(trimmed);
      _logger.info('depots.lookupByCode.done', fields: {
        'outcome': switch (outcome) {
          DepotCodeFound() => 'found',
          DepotCodeAbsent() => 'absent',
          DepotCodeUnavailable() => 'erpUnavailable',
        },
      });
      return Success(outcome);
    } on ApiException catch (e) {
      _logger.error('depots.lookupByCode.failed', fields: {
        'errorCode': e.error.code,
        'status': e.error.statusCode,
        'correlationId': e.error.correlationId,
      });
      return Failed(_failure(e.error));
    } on ServerException catch (e) {
      return Failed(
          ServerFailure(message: e.message, statusCode: e.statusCode));
    }
  }

  Failure _failure(ApiError error) {
    if (error.code == ApiErrorCodes.network) return const NetworkFailure();

    // A rejected `modifiedSince` means the stored watermark is unusable —
    // most likely written from a device clock by an older build. Surface the
    // server's per-field explanation rather than a generic message; the
    // recovery is a fresh initial sync.
    final fieldMessage = error.fieldError('modifiedSince');

    return ServerFailure(
      message: fieldMessage ??
          error.message ??
          'Could not sync depots. Please try again.',
      statusCode: error.statusCode,
    );
  }
}
