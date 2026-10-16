import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/my_visits/domain/entities/fraud_flag.dart';
import 'package:steelforce/features/my_visits/domain/entities/fraud_policy.dart';
import 'package:steelforce/features/my_visits/domain/entities/location_sample.dart';
import 'package:steelforce/features/my_visits/domain/services/fraud_detection_service.dart';
import 'package:steelforce/features/my_visits/domain/services/location_fix_provider.dart';
import 'package:steelforce/features/my_visits/domain/services/location_tracking_service.dart';
import 'package:steelforce/features/my_visits/domain/usecases/record_fraud_flag.dart';
import 'package:steelforce/features/my_visits/domain/usecases/record_location_sample.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/location_tracking_state.dart';

const _trailCap = 500;

/// Starts/stops the real GPS stream, persists every sample durably, and screens
/// each one for impossible-travel-speed fraud (mock-location/accuracy are
/// checked at check-in time instead, in
/// `FraudDetectionService.validateCheckIn`).
///
/// Two modes, because a rep walking a route and a rep looking at one screen
/// need very different things from the battery:
///
/// * [start] — the route-scoped stream, behind a real foreground service so it
///   survives the screen going off. Every sample is stored; this is what the
///   GPS trail is made of.
/// * [observeForScreen] — foreground-only, no service and no notification, for
///   a screen that needs to know where the rep is *right now* — the check-in
///   verification and the nearest-first stop sort. Released on [stopObserving].
///
/// Both write [LocationTrackingState.current], which is what anything asking
/// "where is the rep" reads.
///
/// ## The fix ladder (why check-in no longer waits forever)
///
/// [observeForScreen] used to be a stream and nothing else. A stream only
/// emits when the device moves past its distance filter, so a rep standing
/// still in a shop could wait indefinitely — the "Waiting for a GPS fix"
/// dialog that never resolved. Now every search runs three things at once:
///
/// ```text
///  t=0   cached last-known position (≤ 2 min old)  → instant first reading
///  t=0   precise one-shot (satellite), 8 s limit
///  t≈8s  coarse one-shot (Wi-Fi / cell), 7 s limit → works under a roof
///  t=0…  the live stream, for as long as the screen is open
///  t=15s nothing at all → status `unavailable`
/// ```
///
/// Whichever lands first becomes [LocationTrackingState.current]. None of this
/// fabricates a position: every value is one the device itself reported, with
/// its own accuracy and mock flag, so the anti-fraud checks see exactly what
/// they saw before.
class LocationTrackingCubit extends Cubit<LocationTrackingState> {
  LocationTrackingCubit({
    required LocationTrackingService trackingService,
    required RecordLocationSample recordLocationSample,
    required RecordFraudFlag recordFraudFlag,
    required FraudDetectionService fraudDetectionService,
    LocationFixProvider? fixProvider,
  })  : _trackingService = trackingService,
        _recordLocationSample = recordLocationSample,
        _recordFraudFlag = recordFraudFlag,
        _fraudDetectionService = fraudDetectionService,
        // No DI change needed: the registered `GeolocatorTrackingService`
        // implements both interfaces. A test fake that implements only
        // `LocationTrackingService` simply runs without the ladder.
        _fixProvider = fixProvider ??
            (trackingService is LocationFixProvider
                ? trackingService as LocationFixProvider
                : null),
        super(const LocationTrackingState());

  final LocationTrackingService _trackingService;
  final RecordLocationSample _recordLocationSample;
  final RecordFraudFlag _recordFraudFlag;
  final FraudDetectionService _fraudDetectionService;
  final LocationFixProvider? _fixProvider;

  StreamSubscription<LocationSample>? _subscription;
  StreamSubscription<LocationSample>? _observation;
  StreamSubscription<bool>? _serviceWatch;
  Timer? _watchdog;
  static const _policy = FraudPolicy();

  /// Total time a search may run before it is declared [GpsFixStatus.unavailable].
  static const Duration fixSearchTimeout = Duration(seconds: 15);
  static const Duration _preciseTimeout = Duration(seconds: 8);
  static const Duration _coarseTimeout = Duration(seconds: 7);
  static const Duration _lastKnownMaxAge = Duration(minutes: 2);

  /// Bumped on every new search; a late answer from an older search is ignored.
  int _generation = 0;

  /// Whether any position arrived during the current search.
  bool _fixThisSearch = false;

  int _screenFilterMeters = 10;

  Future<bool> start(String routeId, {bool background = false}) async {
    final granted =
        await _trackingService.ensurePermission(background: background);
    if (!granted) {
      emit(state.copyWith(permissionDenied: true));
      return false;
    }

    emit(state.copyWith(isTracking: true, permissionDenied: false));
    _subscription?.cancel();
    _subscription = _trackingService
        .track(routeId)
        .listen((sample) => _onSample(routeId, sample));
    return true;
  }

  Future<void> _onSample(String routeId, LocationSample sample) async {
    if (isClosed) return;
    final trail = [...state.trail, sample];
    _fixThisSearch = true;
    emit(state.copyWith(
        current: sample,
        currentReceivedAt: DateTime.now(),
        fixStatus: GpsFixStatus.acquired,
        trail: trail.length > _trailCap
            ? trail.sublist(trail.length - _trailCap)
            : trail));

    unawaited(_recordLocationSample(sample));

    final previous =
        state.trail.length >= 2 ? state.trail[state.trail.length - 2] : null;
    if (previous != null &&
        _fraudDetectionService.isImpossibleTravel(previous, sample, _policy)) {
      unawaited(_recordFraudFlag(FraudFlag(
        id: '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(99999)}',
        routeId: routeId,
        type: FraudFlagType.impossibleSpeed,
        detail:
            'Implausible travel speed detected between consecutive GPS samples.',
        timestamp: sample.timestamp,
        blocked: false,
      )));
    }
  }

  /// A light, screen-scoped position stream, plus the fix ladder above.
  ///
  /// Samples from here are *not* persisted. They are a live reading for the UI,
  /// not the audit trail — that is [start]'s job.
  ///
  /// Safe to call repeatedly: a second call replaces the first rather than
  /// stacking subscriptions. Returns false when location is unavailable, with
  /// [LocationTrackingState.fixStatus] saying exactly why.
  Future<bool> observeForScreen({int distanceFilterMeters = 10}) {
    _screenFilterMeters = distanceFilterMeters;
    return _search(resubscribe: true);
  }

  /// Starts a fresh search, restarting the stream. For the "Try again" button,
  /// and for returning from system settings.
  Future<bool> retryFix() => _search(resubscribe: true);

  /// Asks for a newer position without tearing the stream down. Called when
  /// the check-in dialog opens: a stationary device's last stream sample may
  /// be minutes old, and the verdict should be about *now*.
  Future<bool> refreshFix() => _search(resubscribe: _observation == null);

  Future<bool> _search({required bool resubscribe}) async {
    final generation = ++_generation;
    _fixThisSearch = false;
    _watchdog?.cancel();

    final availability = await _checkAvailability();
    if (isClosed || generation != _generation) return false;

    if (availability != LocationAvailability.available) {
      emit(state.copyWith(
        permissionDenied: availability != LocationAvailability.servicesDisabled,
        fixStatus: switch (availability) {
          LocationAvailability.servicesDisabled =>
            GpsFixStatus.servicesDisabled,
          LocationAvailability.permissionDeniedForever =>
            GpsFixStatus.permissionDeniedForever,
          _ => GpsFixStatus.permissionDenied,
        },
      ));
      // Location switched back on from the quick-settings shade → search again
      // on its own, without the rep having to find a retry button.
      if (availability == LocationAvailability.servicesDisabled) {
        _watchServiceStatus();
      }
      return false;
    }

    _serviceWatch?.cancel();
    _serviceWatch = null;

    final now = DateTime.now();
    emit(state.copyWith(
      permissionDenied: false,
      searchStartedAt: now,
      // Keep showing a recent fix while refreshing it; only fall back to
      // "searching" when there is nothing usable to show.
      fixStatus: state.usableFix(now) != null
          ? GpsFixStatus.acquired
          : GpsFixStatus.searching,
    ));

    if (resubscribe || _observation == null) {
      await _observation?.cancel();
      if (isClosed || generation != _generation) return false;
      _observation = _trackingService
          .observe(distanceFilterMeters: _screenFilterMeters)
          .listen(
            (sample) => _acceptFix(sample),
            onError: (Object _) => _onStreamError(generation),
          );
    }

    _watchdog = Timer(fixSearchTimeout, () => _onSearchTimeout(generation));

    final fixes = _fixProvider;
    if (fixes != null) {
      unawaited(_seedFromLastKnown(fixes, generation));
      unawaited(_runLadder(fixes, generation));
    }
    return true;
  }

  Future<LocationAvailability> _checkAvailability() async {
    final fixes = _fixProvider;
    if (fixes != null) return fixes.checkAvailability(request: true);
    final granted = await _trackingService.ensurePermission();
    return granted
        ? LocationAvailability.available
        : LocationAvailability.permissionDenied;
  }

  Future<void> _seedFromLastKnown(
      LocationFixProvider fixes, int generation) async {
    final cached = await fixes.lastKnownFix(maxAge: _lastKnownMaxAge);
    if (cached == null || isClosed || generation != _generation) return;
    // A cached reading only fills a gap. It never replaces a live one.
    if (state.usableFix() != null) return;
    final receivedAt = cached.timestamp.isAfter(DateTime.now())
        ? DateTime.now()
        : cached.timestamp;
    _acceptFix(cached, receivedAt: receivedAt);
  }

  Future<void> _runLadder(LocationFixProvider fixes, int generation) async {
    final precise =
        await fixes.currentFix(precise: true, timeout: _preciseTimeout);
    if (isClosed || generation != _generation) return;
    if (precise != null) {
      _acceptFix(precise);
      return;
    }
    // The stream may have answered while the precise read was waiting.
    if (_fixThisSearch) return;

    final coarse =
        await fixes.currentFix(precise: false, timeout: _coarseTimeout);
    if (isClosed || generation != _generation) return;
    if (coarse != null) _acceptFix(coarse);
  }

  void _acceptFix(LocationSample sample, {DateTime? receivedAt}) {
    if (isClosed) return;
    final existing = state.usableFix();
    // Don't let an older reading overwrite a newer one that is still usable.
    if (existing != null && sample.timestamp.isBefore(existing.timestamp)) {
      return;
    }
    _fixThisSearch = true;
    emit(state.copyWith(
      current: sample,
      currentReceivedAt: receivedAt ?? DateTime.now(),
      fixStatus: GpsFixStatus.acquired,
      permissionDenied: false,
    ));
  }

  void _onStreamError(int generation) {
    if (isClosed || generation != _generation) return;
    // Most often: Location switched off while the screen was open. Re-check
    // so the UI can say that instead of searching silently.
    unawaited(_recheckAvailability(generation));
  }

  Future<void> _recheckAvailability(int generation) async {
    final fixes = _fixProvider;
    if (fixes == null) return;
    final availability = await fixes.checkAvailability(request: false);
    if (isClosed || generation != _generation) return;
    if (availability == LocationAvailability.servicesDisabled) {
      emit(state.copyWith(fixStatus: GpsFixStatus.servicesDisabled));
      _watchServiceStatus();
    }
  }

  void _onSearchTimeout(int generation) {
    if (isClosed || generation != _generation || _fixThisSearch) return;
    // Keep a recent fix if there is one; otherwise say plainly that none came.
    // The stream keeps running — a fix that arrives later still lands.
    emit(state.copyWith(
      fixStatus: state.usableFix() != null
          ? GpsFixStatus.acquired
          : GpsFixStatus.unavailable,
    ));
  }

  void _watchServiceStatus() {
    final fixes = _fixProvider;
    if (fixes == null || _serviceWatch != null) return;
    _serviceWatch = fixes.serviceEnabledChanges().listen(
      (enabled) {
        if (enabled && !isClosed) unawaited(retryFix());
      },
      onError: (Object _) {},
    );
  }

  /// Opens the system page that fixes the current [GpsFixStatus], if any.
  Future<bool> openSettingsForStatus() async {
    final fixes = _fixProvider;
    if (fixes == null) return false;
    return switch (state.fixStatus) {
      GpsFixStatus.servicesDisabled => fixes.openLocationSettings(),
      GpsFixStatus.permissionDeniedForever => fixes.openAppSettings(),
      // Can still be asked in-app; the search re-prompts.
      GpsFixStatus.permissionDenied => retryFix(),
      GpsFixStatus.idle ||
      GpsFixStatus.searching ||
      GpsFixStatus.acquired ||
      GpsFixStatus.unavailable =>
        Future<bool>.value(false),
    };
  }

  /// Releases [observeForScreen]. Leaves a route-scoped [start] running — the
  /// two are independent, and a rep closing a screen has not ended their day.
  Future<void> stopObserving() async {
    _generation++;
    _watchdog?.cancel();
    _watchdog = null;
    await _serviceWatch?.cancel();
    _serviceWatch = null;
    await _observation?.cancel();
    _observation = null;
    await _trackingService.stopObserving();
    if (!isClosed && state.fixStatus != GpsFixStatus.acquired) {
      emit(state.copyWith(fixStatus: GpsFixStatus.idle));
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _trackingService.stop();
    emit(state.copyWith(isTracking: false));
  }

  @override
  Future<void> close() {
    _generation++;
    _watchdog?.cancel();
    _serviceWatch?.cancel();
    _subscription?.cancel();
    _observation?.cancel();
    _trackingService.stopObserving();
    _trackingService.stop();
    return super.close();
  }
}
