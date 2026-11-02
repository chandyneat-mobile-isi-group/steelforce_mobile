import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/app.dart';
import 'package:steelforce/core/bootstrap/app_bootstrap_service.dart';
import 'package:steelforce/core/bootstrap/background_sync_startup.dart';
import 'package:steelforce/core/bootstrap/error_boundary.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/responsive/breakpoints.dart';

Future<void> main() async {
  // Constructed directly rather than resolved from DI: it has to be able to
  // report a failure in DI itself, so it cannot depend on DI succeeding.
  const AppLogger logger = ConsoleAppLogger();

  // Installed first, before anything can throw. A build error, an uncaught
  // async error, or a widget that fails to build is now logged and contained
  // instead of replacing the screen with an error box nobody records.
  ErrorBoundary.install(logger);

  ErrorBoundary.runGuarded(logger, () async {
    WidgetsFlutterBinding.ensureInitialized();

    // A background sync run may be mid-drain in this process, holding Hive and
    // the database from another isolate. Let it finish (bounded) before
    // bootstrap opens them here.
    await awaitBackgroundSyncHandover();

    // All initialization lives in AppBootstrapService so the boot sequence has
    // one documented, testable home. It performs no network I/O and no
    // navigation — see that class's doc comment for why (ADR-002 §3/§5,
    // OFFLINE_FIRST §2.2).
    await const AppBootstrapService().run();

    // Push is deliberately NOT started here. `NotificationCoordinator.start()`
    // runs from `NotificationHost`, under `MaterialApp`, because two of its
    // steps need things that do not exist yet at this point in boot:
    //
    //   * Android notification channels are created with **translated** names,
    //     and the language bundle is loaded asynchronously by `LanguageCubit`
    //     when the widget tree builds. Android caches a channel's name at
    //     creation and ignores later renames — so creating them here would pin
    //     every rep's system settings to raw localisation keys, permanently.
    //   * A tapped notification has to navigate, and there is no Navigator
    //     until `MaterialApp` exists.
    //
    // OS-scheduled sync for work saved offline while the app is closed or in
    // the background (Android WorkManager / iOS BGTaskScheduler). Best effort
    // by design: the foreground `SyncEngine` is the reliable path. Not awaited
    // — registering with the OS must never delay first frame. No-op on web.
    unawaited(startBackgroundSync());

    // Portrait on phones only. A tablet keeps every orientation: locked to
    // portrait, iPadOS letterboxes the whole app inside black bars when the
    // iPad is held landscape, and the tablet layouts never get the width
    // they were built for.
    if (_isPhone()) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // The app starts regardless of bootstrap outcome: SplashScreen owns the
    // first transition and a guest can always browse local data. Surfacing a
    // hard boot error screen would contradict "offline is a normal state, not
    // an error state" (ADR-002 §4).
    runApp(const ISISteelSalesApp());
  });
}

/// Whether this device is a phone, judged by the physical screen rather than
/// the window — a tablet in Split View still counts as a tablet.
///
/// iOS answers no: its Info.plist already makes iPhone portrait-only and
/// iPad free, and the display size is not reliable this early in boot — a
/// wrong "phone" here letterboxes every iPad.
bool _isPhone() {
  if (defaultTargetPlatform == TargetPlatform.iOS) return false;
  final displays = WidgetsBinding.instance.platformDispatcher.displays;
  if (displays.isEmpty) return true;
  final display = displays.first;
  final logical = display.size / display.devicePixelRatio;
  return logical.shortestSide < Breakpoints.compactMax;
}
