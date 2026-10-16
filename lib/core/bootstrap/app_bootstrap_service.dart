import 'dart:async';

import 'package:steelforce/core/config/app_config.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/migrations/legacy/legacy_orders_importer.dart';
import 'package:steelforce/core/database/drift/migrations/legacy/legacy_source_factory.dart';
import 'package:steelforce/core/database/drift/migrations/legacy/legacy_routes_importer.dart';
import 'package:steelforce/core/database/drift/migrations/master_data_locale_backfill.dart';
import 'package:steelforce/core/database/hive/hive_service.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/connectivity_service.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Prepares the application before any feature loads.
///
/// ## Two rules this service exists to enforce
///
/// **1. Boot never blocks on the network** (ADR-002 §3, `docs/blueprint/offline-architecture.md`
/// §2.6). A signed-in rep standing in a warehouse with no signal must reach
/// their data. Therefore this service performs **no** token validation, **no**
/// token refresh, and **no** master-data download. Token refresh is lazy — the
/// network interceptor does it on the first real request, or the sync
/// coordinator does it opportunistically once [ConnectivityService] reports
/// reachable. A failed refresh **never** logs the user out; only a definitive
/// server rejection (refresh token revoked) does, and that cannot be known
/// offline.
///
/// **2. Bootstrap never navigates** (`docs/blueprint/offline-architecture.md` §2.2, ADR-002 §5).
/// Each surface owns its own transition; `SplashScreen` decides
/// `main` vs `chooseLanguage` from `onboarding_complete`. A central
/// bootstrap-driven redirect is the exact global-listener pattern that was
/// already tried, caused guest redirect loops, and was reverted — it is listed
/// as an anti-pattern in `docs/skills/ai-engineering-playbook.md` §12.
///
/// Auth resolution itself stays where it already works: `AuthBloc`
/// (`AuthCheckRequested`) resolves the cached session in the background and
/// mirrors it into `SessionManager` (`docs/blueprint/offline-architecture.md` §2.1/§2.3). This
/// service does not duplicate that.
///
/// ## Ordering note
///
/// The encrypted `AppDatabase` is registered inside [initDependencies] as a lazy
/// singleton and opens on first use, so "init DI" *is* "init the database" —
/// they are not separate ordered steps. Hive must be opened **before** DI
/// because `AppPreferences` resolves `HiveService.cacheBox`.
class AppBootstrapService {
  const AppBootstrapService();

  /// Runs the boot sequence. Safe to await before `runApp`; performs no I/O
  /// that can hang on a dead network.
  Future<BootstrapResult> run() async {
    // 1–2. Config + logger. The logger is constructed directly rather than
    // resolved from DI because it must be able to report a DI failure.
    const AppLogger logger = ConsoleAppLogger();

    // The host is the single most useful thing to see first: almost every
    // "the app cannot log in" report ends with the build pointing somewhere
    // unexpected. `hostOverridden` distinguishes a `--dart-define` launch from
    // the compiled `.env`, which is otherwise invisible.
    logger.info('bootstrap.started', fields: {
      'apiHost': Uri.tryParse(AppConfig.apiBaseUrl)?.host,
      'hostOverridden': AppConfig.hasOverride,
    });

    try {
      // 3a. `intl` locale data. Must precede any localised date/number
      //     formatting, which means effectively any screen.
      //
      //     Without this, `DateFormat.yMMMd('km')` throws
      //     `LocaleDataException` — the *explicit-locale* constructors are the
      //     ones that need it; the no-argument ones fall back to `en_US` and
      //     silently render English dates to a Khmer-reading rep. Both
      //     failures were already in the tree: `profile_info_section.dart`
      //     wraps its formatter in a try/catch and degrades to English rather
      //     than initialising once, here, where it belongs.
      //
      //     Loading every locale is a few hundred KB and happens off the
      //     network; the app ships exactly two languages and can switch
      //     between them at runtime, so lazily loading one is not worth the
      //     branch.
      await initializeDateFormatting();
      logger.info('bootstrap.intl_ready');

      // 3. Key-value store. Must precede DI (see class doc).
      await HiveService.init();
      logger.info('bootstrap.hive_ready');

      // 4. DI — also registers the encrypted AppDatabase (opens lazily) and
      //    secure storage. Sprint 1 crypto (T1.0–T1.4, T1.6) is already built:
      //    the composite key and fail-closed cipher check run at first open.
      await initDependencies();
      logger.info('bootstrap.di_ready');

      // 5. Legacy plaintext → encrypted imports (T1.5 routes, T1.5b orders).
      //    Run at most once each, before any feature reads, so no screen can
      //    observe a half-migrated store. Local disk work only — no network, so
      //    ADR-002 §3 holds. On web both are no-ops: `AbsentLegacySource`
      //    reports no legacy file, because a browser never ran the sqflite
      //    build that would have created one.
      await _importLegacyRoutes(logger);
      await _importLegacyOrders(logger);

      // 5b. One-shot master-data locale backfill. Local disk only (it clears
      //     three cursor tables), so ADR-002 §3 still holds — the re-sync it
      //     arms happens later, opportunistically, on whatever screen asks.
      await _backfillMasterDataLocale(logger);

      // 6. Session restore: intentionally a no-op here. AuthBloc's
      //    AuthCheckRequested reads the cached user from secure storage in the
      //    background with zero network calls (OFFLINE_FIRST §2.1, §2.5).

      // 7. Connectivity. Started last so a slow reachability probe can never
      //    delay first frame; the initial state is `offline` until the probe
      //    proves otherwise.
      //
      //    Deliberately **not** awaited. `start()` awaits its first probe — a
      //    contract its own tests rely on — so awaiting it here put a network
      //    round trip on the path to `runApp`. Against an unreachable gateway
      //    that stalled boot for the probe timeout, and before that timeout
      //    was enforced (the probe had no `connectTimeout`, see
      //    [HttpReachabilityProbe]) it stalled indefinitely: no first frame,
      //    just the launch screen. That is precisely the "boot never blocks on
      //    the network" rule in this class's doc comment, ADR-002 §3 and
      //    OFFLINE_FIRST §2.6.
      //
      //    Fire-and-forget is safe because nothing here reads the result:
      //    `ConnectivityService` publishes to a broadcast stream and every
      //    consumer is already built to react to a transition rather than to
      //    poll an initial value.
      final connectivity = sl<ConnectivityService>();
      unawaited(connectivity.start());
      logger.info('bootstrap.connectivity_starting');

      // The host is repeated here, not only on `bootstrap.started`. That
      // first line is emitted before the VM service attaches, so it is
      // routinely missing from the `flutter run` console — and it carries the
      // single most useful fact when nothing can connect.
      logger.info('bootstrap.completed', fields: {
        'apiHost': Uri.tryParse(AppConfig.apiBaseUrl)?.host,
        'hostOverridden': AppConfig.hasOverride,
      });
      return const BootstrapResult.success();
    } catch (error, stackTrace) {
      // A bootstrap failure is not recoverable here, but it must never surface
      // as a raw exception (ENGINEERING_STANDARD §7) and must never be
      // swallowed silently (playbook §12).
      logger.error('bootstrap.failed', error: error, stackTrace: stackTrace);
      return BootstrapResult.failure(error.runtimeType.toString());
    }
  }
}

/// Runs the T1.5 legacy import, then purges the plaintext source **only** if the
/// import was verifiably complete.
///
/// This is the step that actually removes depot PII and employee GPS traces
/// from unencrypted storage — the top entry in `docs/blueprint/migration-plan.md` §9's
/// risk register. Two rules govern it:
///
/// 1. **Verify, then purge.** `safeToPurge` is false if anything was skipped
///    (an orphan stop, an unknown depot). Those rows exist *only* in the
///    plaintext file, so deleting it would destroy them. We would rather leave
///    plaintext on disk for one more release than lose a rep's captures.
/// 2. **A failed import never blocks boot.** The importer rolls its transaction
///    back and rethrows; we log and continue. The app still opens on encrypted
///    data — offline is a normal state, not an error screen (ADR-002 §4) — and
///    the import retries on the next launch because no marker was written.
Future<void> _importLegacyRoutes(AppLogger logger) async {
  final importer = LegacyRoutesImporter(
    db: sl<AppDatabase>(),
    source: createLegacySqliteSource('routes.db'),
    logger: logger,
  );

  try {
    final result = await importer.import();
    if (result.alreadyDone || result.sourceMissing) return;

    logger.info('bootstrap.legacy_import', fields: {
      'imported': result.totalImported,
      'skipped': result.totalSkipped,
    });

    if (result.safeToPurge) {
      await importer.purgeLegacyData();
      logger.warning('bootstrap.legacy_plaintext_purged');
    } else {
      // Deliberately loud: plaintext PII is still on disk and a human needs to
      // know why. The usual cause is a stop whose depot the directory has
      // not synced yet — the next depot sync fixes it and the following
      // launch retries.
      logger.error('bootstrap.legacy_purge_withheld', fields: {
        'skipped': result.totalSkipped,
      });
    }
  } catch (error, stackTrace) {
    logger.error('bootstrap.legacy_import_failed',
        error: error, stackTrace: stackTrace);
  }
}

/// Runs the T1.5b legacy Orders import, then purges the plaintext source
/// **only** if the import was verifiably complete.
///
/// Same two rules as [_importLegacyRoutes], and the same reasoning — see that
/// function. The stakes differ slightly in shape: this file holds a rep's saved
/// quotations and, critically, the **sync queue**, whose rows are by definition
/// work the server has never seen. Losing those is unrecoverable, which is why
/// this runs before any feature can read and why a failure leaves the plaintext
/// source untouched for the next launch to retry.
Future<void> _importLegacyOrders(AppLogger logger) async {
  final importer = LegacyOrdersImporter(
    db: sl<AppDatabase>(),
    source: createLegacySqliteSource('catalog.db'),
    logger: logger,
  );

  try {
    final result = await importer.import();
    if (result.alreadyDone || result.sourceMissing) return;

    logger.info('bootstrap.legacy_orders_import', fields: {
      'imported': result.totalImported,
    });

    if (result.safeToPurge) {
      await importer.purgeLegacyData();
      logger.warning('bootstrap.legacy_orders_plaintext_purged');
    } else {
      logger.error('bootstrap.legacy_orders_purge_withheld', fields: {
        'skipped': result.totalSkipped,
      });
    }
  } catch (error, stackTrace) {
    logger.error('bootstrap.legacy_orders_import_failed',
        error: error, stackTrace: stackTrace);
  }
}

/// Arms a one-time full re-sync of master data so an already-synced install
/// picks up the Khmer names the feed now carries. See
/// [MasterDataLocaleBackfill] for why a delta sync can never do this on its own.
///
/// A failure here is logged and swallowed, matching the legacy importers above:
/// the marker is only written inside the transaction, so a failed attempt
/// simply retries on the next launch. The cost of *not* running is stale names,
/// not data loss — never a reason to block boot.
Future<void> _backfillMasterDataLocale(AppLogger logger) async {
  try {
    await MasterDataLocaleBackfill(db: sl<AppDatabase>(), logger: logger).run();
  } catch (error, stackTrace) {
    logger.error('bootstrap.master_data_locale_backfill_failed',
        error: error, stackTrace: stackTrace);
  }
}

/// Outcome of [AppBootstrapService.run].
///
/// A sealed result rather than a thrown exception so `main` can decide how to
/// degrade without a `try`/`catch` around `runApp`.
sealed class BootstrapResult {
  const BootstrapResult();

  const factory BootstrapResult.success() = BootstrapSuccess;
  const factory BootstrapResult.failure(String reason) = BootstrapFailure;

  bool get isSuccess => this is BootstrapSuccess;
}

final class BootstrapSuccess extends BootstrapResult {
  const BootstrapSuccess();
}

final class BootstrapFailure extends BootstrapResult {
  const BootstrapFailure(this.reason);

  /// Exception *type* only — never a message, which could embed PII
  /// (`docs/skills/security.md` §10).
  final String reason;
}

// ─────────────────────────────────────────────────────────────────────────────
// Not yet wired — tracked infrastructure, NOT forgotten steps.
//
// These boot steps are specified but blocked on infrastructure that does not
// exist yet. Per `docs/skills/engineering-standard.md` §2 and `docs/blueprint/system-architecture.md`
// §4, they must not be built ahead of their dependencies:
//
//   • Sync-queue crash recovery (inFlight → queued) — `docs/blueprint/sync-architecture.md` §7.
//     Blocked on: a Drift `sync_queue` table + `SyncQueueDao` (Phase 2), and
//     promoting the Orders feature's working queue into `core/sync/` (ADR-006).
//
//   • SyncCoordinator start — `docs/blueprint/sync-architecture.md` §9. Blocked on the above.
//
//   • WorkflowSession resume check — `docs/blueprint/offline-architecture.md` §3, ADR-007.
//     Blocked on: a Drift `workflow_session` table + generalizing `my_visits`'
//     `ActiveWorkflow` into `core/workflow/` (Phase 3). NOTE: `workflow_state`
//     is the last live table in the plaintext `routes.db` — the T1.5 purge
//     empties every business table but cannot delete the file until this lands.
//
//   • User-workspace init/reset on user switch. Blocked on an ADR: no business
//     table carries a `userId` today, and ADR-001 mandates a single database,
//     so per-user isolation is an open architectural decision.
//
// See `docs/blueprint/migration-plan.md` for sequencing. Do not stub these in with
// no-op implementations — an empty hook reads as "done" to the next engineer.
// ─────────────────────────────────────────────────────────────────────────────
