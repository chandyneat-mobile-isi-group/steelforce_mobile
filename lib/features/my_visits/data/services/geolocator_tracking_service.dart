import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:geolocator/geolocator.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/my_visits/domain/entities/location_sample.dart';
import 'package:steelforce/features/my_visits/domain/services/location_fix_provider.dart';
import 'package:steelforce/features/my_visits/domain/services/location_tracking_service.dart';

/// Real GPS tracking backed by `geolocator`. Background tracking uses
/// geolocator's own foreground-service mode on Android
/// (`AndroidSettings.foregroundNotificationConfig`) and background location
/// modes on iOS (`AppleSettings.allowBackgroundLocationUpdates`) — no
/// separate background-execution package needed.
///
/// Also implements [LocationFixProvider]: one-shot reads (cached, precise,
/// coarse) that the check-in screen needs to get a first fix quickly and
/// indoors. See that interface for why a stream alone was not enough.
class GeolocatorTrackingService
    implements LocationTrackingService, LocationFixProvider {
  StreamSubscription<Position>? _subscription;
  StreamController<LocationSample>? _controller;

  // ---------------------------------------------------------------------------
  // Foreground observation — shared, reference-counted, replaying.
  //
  // **What was wrong.** `observe()` used to hand every caller the *same*
  // broadcast stream, created with whichever distance filter asked first, and
  // `stopObserving()` tore it down for everyone. Three consequences, and the
  // first one is the "Waiting for a GPS fix" that never ends:
  //
  // 1. The Stop Dashboard opens first and starts the stream at 25 m. It
  //    receives the first fix. The rep opens Check-in: `observe(10)` quietly
  //    returns the existing 25 m stream, and a broadcast stream does not replay
  //    — so a rep standing still never receives a single sample on the
  //    check-in screen. `LocationTrackingState.current` stays null.
  // 2. The check-in screen's 10 m filter was silently ignored.
  // 3. Leaving the check-in screen called `stopObserving()`, which killed the
  //    dashboard's stream underneath it.
  //
  // **Now.** Each `observe()` call gets its own stream. A new listener is
  // immediately given the last known observed sample (if recent), the platform
  // subscription runs at the *smallest* filter any listener asked for, each
  // listener is filtered to its own distance, and the platform subscription
  // only stops when the last listener leaves.
  // ---------------------------------------------------------------------------
  final Set<_Observer> _observers = <_Observer>{};
  StreamSubscription<Position>? _observeSubscription;
  int? _activeObserveFilter;
  LocationSample? _lastObserved;
  DateTime? _lastObservedAt;

  /// How old a remembered sample may be and still be replayed to a new
  /// listener. Two minutes: long enough to bridge Dashboard → Stop → Check-in,
  /// short enough that a rep who drove somewhere is not shown where they were.
  static const Duration _replayMaxAge = Duration(minutes: 2);

  @override
  Future<bool> ensurePermission({bool background = false}) async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    // Staged request: only ask for "always" (background) right before it's
    // actually needed, matching platform-expected UX.
    if (background && permission != LocationPermission.always) {
      permission = await Geolocator.requestPermission();
    }
    return true;
  }

  @override
  Stream<LocationSample> track(String routeId) {
    _controller ??= StreamController<LocationSample>.broadcast(onCancel: stop);
    _subscription ??=
        Geolocator.getPositionStream(locationSettings: _settings()).listen(
      (position) => _controller?.add(_toSample(routeId, position)),
      onError: (Object _) {},
    );
    return _controller!.stream;
  }

  /// Platform-tuned settings.
  ///
  /// Uses [defaultTargetPlatform] rather than `dart:io`'s `Platform.isAndroid`
  /// because `dart:io` does not exist on web. The check is equivalent on mobile
  /// and, on web, simply falls through to the plain [LocationSettings] default
  /// below — which is correct: the Android/iOS branches configure *background*
  /// tracking (foreground notifications, background location indicators), and a
  /// browser cannot track location in the background at all. Web tracking is
  /// foreground-only for as long as the tab is open.
  LocationSettings _settings() {
    if (defaultTargetPlatform == TargetPlatform.android && !kIsWeb) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          // Shown in the Android notification shade for as long as background
          // tracking runs, so it is user-facing copy, not a debug label: it
          // carries the app brand and resolves through the same key store as
          // the rest of the UI. `.tr` is context-free by design
          // (LOCALIZATION.md §2), which is what lets a data-layer service
          // localise without reaching for a BuildContext it cannot have.
          notificationTitle: 'app.name'.tr,
          notificationText: 'my_visits.tracking.notification_text'.tr,
          enableWakeLock: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS && !kIsWeb) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
        accuracy: LocationAccuracy.high, distanceFilter: 10);
  }

  // ---------------------------------------------------------------------------
  // observe / stopObserving
  // ---------------------------------------------------------------------------

  @override
  Stream<LocationSample> observe({int distanceFilterMeters = 25}) {
    final observer = _Observer(max(0, distanceFilterMeters));
    final controller = StreamController<LocationSample>();
    observer.controller = controller;

    controller
      ..onListen = () {
        _observers.add(observer);
        // Replay: a stationary device may not emit again for a long time, and
        // the listener that just arrived is exactly the one that needs to know
        // where the rep is *now*.
        final last = _lastObserved;
        final at = _lastObservedAt;
        if (last != null &&
            at != null &&
            DateTime.now().difference(at) <= _replayMaxAge) {
          observer.lastForwarded = last;
          controller.add(last);
        }
        _syncObserveSubscription();
      }
      ..onCancel = () {
        _observers.remove(observer);
        _syncObserveSubscription();
        unawaited(controller.close());
      };

    return controller.stream;
  }

  /// Keeps exactly one platform subscription, at the smallest filter any
  /// current listener wants — or none, when nobody is listening.
  void _syncObserveSubscription() {
    if (_observers.isEmpty) {
      unawaited(_observeSubscription?.cancel());
      _observeSubscription = null;
      _activeObserveFilter = null;
      return;
    }

    final wanted = _observers.map((o) => o.distanceFilterMeters).reduce(min);
    if (_observeSubscription != null && _activeObserveFilter == wanted) return;

    unawaited(_observeSubscription?.cancel());
    _activeObserveFilter = wanted;
    _observeSubscription = Geolocator.getPositionStream(
      // Plain settings: no foreground-service notification (that belongs to the
      // route-scoped [track]).
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: wanted,
      ),
    ).listen(
      (position) {
        final sample = _toSample('stop-dashboard', position);
        _lastObserved = sample;
        _lastObservedAt = DateTime.now();
        for (final observer in _observers.toList()) {
          observer.offer(sample);
        }
      },
      // Forwarded, not swallowed. "Location switched off" used to vanish here,
      // and the screen had no way to tell a rep why nothing was happening.
      onError: (Object error, StackTrace stackTrace) {
        for (final observer in _observers.toList()) {
          observer.controller?.addError(error, stackTrace);
        }
      },
      // A platform stream can end (service switched off on some OEMs). Forget
      // it so the next listener or retry starts a fresh one instead of
      // attaching to a dead subscription.
      onDone: () {
        _observeSubscription = null;
        _activeObserveFilter = null;
      },
    );
  }

  /// Legacy "stop everything" call, now reference-counted.
  ///
  /// Every caller cancels its own subscription first, which is what actually
  /// releases it. This only stops the platform stream when no listener is
  /// left, so one screen closing can no longer kill another screen's stream.
  @override
  Future<void> stopObserving() async {
    if (_observers.isNotEmpty) return;
    await _observeSubscription?.cancel();
    _observeSubscription = null;
    _activeObserveFilter = null;
  }

  // ---------------------------------------------------------------------------
  // LocationFixProvider
  // ---------------------------------------------------------------------------

  @override
  Future<LocationAvailability> checkAvailability({bool request = true}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationAvailability.servicesDisabled;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && request) {
        permission = await Geolocator.requestPermission();
      }
      // An if-chain rather than a switch: `LocationPermission` has gained
      // values across geolocator versions, and anything unrecognised should
      // fall through to "attempt the fix" rather than fail to compile.
      if (permission == LocationPermission.denied) {
        return LocationAvailability.permissionDenied;
      }
      if (permission == LocationPermission.deniedForever) {
        return LocationAvailability.permissionDeniedForever;
      }
      // whileInUse / always, and `unableToDetermine` (the browser's answer
      // before a prompt): let the fix attempt decide rather than claiming a
      // denial nobody made.
      return LocationAvailability.available;
    } catch (_) {
      // A platform that cannot answer is not a denial. Attempt the fix; the
      // search timeout will report honestly if nothing comes back.
      return LocationAvailability.available;
    }
  }

  @override
  Future<LocationSample?> lastKnownFix({required Duration maxAge}) async {
    // Not implemented by browsers; throws there.
    if (kIsWeb) return null;
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) return null;
      final age = DateTime.now().difference(position.timestamp);
      // A future timestamp (clock skew) is treated as fresh rather than
      // discarded — rejecting it would throw away a perfectly good fix.
      if (age > maxAge) return null;
      return _toSample('last-known', position);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<LocationSample?> currentFix({
    required bool precise,
    required Duration timeout,
  }) async {
    try {
      // geolocator 11.x signature: `desiredAccuracy` + `timeLimit` directly.
      // (12+ moves both into `locationSettings:`; 11.1.0 has no such
      // parameter. If the package is ever upgraded, these still compile —
      // they are only deprecated there.)
      final position = await Geolocator.getCurrentPosition(
        // `medium` is the balanced-power provider on Android (Wi-Fi + cell)
        // and ~100 m on iOS: the one that still answers under a steel roof.
        desiredAccuracy:
            precise ? LocationAccuracy.high : LocationAccuracy.medium,
        timeLimit: timeout,
      )
          // Belt and braces: some OEM builds ignore `timeLimit`.
          .timeout(timeout + const Duration(seconds: 1));
      return _toSample('one-shot', position);
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<bool> serviceEnabledChanges() {
    if (kIsWeb) return const Stream<bool>.empty();
    try {
      return Geolocator.getServiceStatusStream()
          .map((status) => status == ServiceStatus.enabled)
          .handleError((Object _) {});
    } catch (_) {
      return const Stream<bool>.empty();
    }
  }

  @override
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------

  LocationSample _toSample(String routeId, Position position) => LocationSample(
        id: '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(99999)}',
        routeId: routeId,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        speedMps: position.speed,
        headingDegrees: position.heading,
        altitudeMeters: position.altitude,
        timestamp: position.timestamp,
        isMocked: position.isMocked,
      );

  @override
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller?.close();
    _controller = null;
  }
}

/// One `observe()` listener: its own controller and its own distance filter.
class _Observer {
  _Observer(this.distanceFilterMeters);

  final int distanceFilterMeters;
  StreamController<LocationSample>? controller;
  LocationSample? lastForwarded;

  /// Forwards [sample] if this listener has not seen a position yet, or the
  /// rep has moved at least this listener's filter since the last one it saw.
  void offer(LocationSample sample) {
    final c = controller;
    if (c == null || c.isClosed) return;
    final last = lastForwarded;
    if (last != null && distanceFilterMeters > 0) {
      final moved = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        sample.latitude,
        sample.longitude,
      );
      if (moved < distanceFilterMeters) return;
    }
    lastForwarded = sample;
    c.add(sample);
  }
}
