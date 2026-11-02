import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:steelforce/features/my_visits/domain/entities/location_sample.dart';
import 'package:steelforce/features/my_visits/domain/services/location_fix_provider.dart';
import 'package:steelforce/features/my_visits/domain/services/location_tracking_service.dart';

/// Periodically reports the device location while an authenticated user is
/// using the app in the foreground.
///
/// Location is optional for sign-in. This service checks permission and system
/// location availability without prompting; the app's permission primer owns
/// any user-facing request.
class LocationHeartbeatService with WidgetsBindingObserver {
  LocationHeartbeatService({
    required LocationTrackingService trackingService,
    required LocationFixProvider locationFixProvider,
    required AuthRemoteDataSource authRemoteDataSource,
    required SessionManager sessionManager,
    required AppLogger logger,
  })  : _trackingService = trackingService,
        _locationFixProvider = locationFixProvider,
        _authRemoteDataSource = authRemoteDataSource,
        _sessionManager = sessionManager,
        _logger = logger {
    WidgetsBinding.instance.addObserver(this);
    _sessionSubscription = _sessionManager.stateChanges.listen((_) {
      if (_sessionManager.canCallProtectedApi) {
        unawaited(start());
      } else {
        unawaited(stop());
      }
    });

    if (_sessionManager.canCallProtectedApi) unawaited(start());
  }

  final LocationTrackingService _trackingService;
  final LocationFixProvider _locationFixProvider;
  final AuthRemoteDataSource _authRemoteDataSource;
  final SessionManager _sessionManager;
  final AppLogger _logger;

  StreamSubscription<LocationSample>? _subscription;
  StreamSubscription<AuthenticationState>? _sessionSubscription;
  Future<void>? _starting;
  int? _startingGeneration;
  DateTime? _lastSentAt;
  LocationAvailability? _lastUnavailableReason;
  bool _isForeground = true;
  bool _disposed = false;
  int _generation = 0;

  static const _throttleInterval = Duration(seconds: 15);

  /// Starts only after checking that the OS location service and permission
  /// are already available. Concurrent callers share the same startup.
  Future<void> start() {
    if (_disposed ||
        !_isForeground ||
        !_sessionManager.canCallProtectedApi ||
        _subscription != null) {
      return Future<void>.value();
    }

    final pending = _starting;
    if (pending != null) {
      final pendingGeneration = _startingGeneration;
      return pending.then((_) {
        if (pendingGeneration != _generation) return start();
      });
    }

    final generation = ++_generation;
    _startingGeneration = generation;
    final pendingStart = _start(generation);
    _starting = pendingStart.whenComplete(() {
      if (_startingGeneration == generation) {
        _starting = null;
        _startingGeneration = null;
      }
    });
    return _starting!;
  }

  Future<void> _start(int generation) async {
    final accountId = _sessionManager.currentUser?.id;
    if (accountId == null || accountId.isEmpty) return;

    LocationAvailability availability;
    try {
      availability =
          await _locationFixProvider.checkAvailability(request: false);
    } catch (error, stackTrace) {
      _logger.error(
        'session.location_availability_check_failed',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    if (!_isCurrent(generation, accountId)) return;
    if (availability != LocationAvailability.available) {
      _logUnavailable(availability);
      return;
    }
    _lastUnavailableReason = null;

    try {
      late final StreamSubscription<LocationSample> subscription;
      subscription = _trackingService.observe(distanceFilterMeters: 25).listen(
        (sample) => _onSample(sample, generation, accountId),
        onError: (Object error, StackTrace stackTrace) {
          _onStreamError(subscription, error, stackTrace);
        },
        onDone: () {
          if (identical(_subscription, subscription)) _subscription = null;
        },
      );
      _subscription = subscription;
      _logger.info('session.location_heartbeat_started');
    } catch (error, stackTrace) {
      _logger.error(
        'session.location_stream_start_failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isForeground = true;
      unawaited(start());
      return;
    }

    _isForeground = false;
    unawaited(stop());
  }

  Future<void> _onSample(
    LocationSample sample,
    int generation,
    String accountId,
  ) async {
    if (!_isCurrent(generation, accountId)) return;

    final now = DateTime.now();
    if (_lastSentAt != null &&
        now.difference(_lastSentAt!) < _throttleInterval) {
      return;
    }
    if (sample.latitude == 0 && sample.longitude == 0) return;

    _lastSentAt = now;
    try {
      // Recheck before the request so a queued sample cannot use a session
      // that ended after the location event arrived.
      if (!_isCurrent(generation, accountId)) return;
      await _authRemoteDataSource.sendHeartbeat(
        sample.latitude,
        sample.longitude,
        sample.accuracyMeters,
        sample.timestamp,
      );
    } catch (error, stackTrace) {
      _logger.error(
        'session.heartbeat_failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _onStreamError(
    StreamSubscription<LocationSample> subscription,
    Object error,
    StackTrace stackTrace,
  ) {
    if (!identical(_subscription, subscription)) return;
    _subscription = null;
    _generation++;
    unawaited(_releaseFailedStream(subscription));
    unawaited(_logStreamError(error, stackTrace));
  }

  Future<void> _releaseFailedStream(
    StreamSubscription<LocationSample> subscription,
  ) async {
    try {
      await subscription.cancel();
      await _trackingService.stopObserving();
    } catch (error, stackTrace) {
      _logger.error(
        'session.location_stream_cleanup_failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _logStreamError(Object error, StackTrace stackTrace) async {
    try {
      final availability =
          await _locationFixProvider.checkAvailability(request: false);
      if (availability != LocationAvailability.available) {
        _logUnavailable(availability);
        return;
      }
    } catch (_) {
      // Preserve the original stream failure below if status itself is unknown.
    }

    _logger.error(
      'session.location_stream_failed',
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _logUnavailable(LocationAvailability availability) {
    if (_lastUnavailableReason == availability) return;
    _lastUnavailableReason = availability;
    _logger.warning(
      'session.location_heartbeat_unavailable',
      fields: {'reason': availability.name},
    );
  }

  bool _isCurrent(int generation, String accountId) =>
      !_disposed &&
      _isForeground &&
      generation == _generation &&
      _sessionManager.canCallProtectedApi &&
      _sessionManager.currentUser?.id == accountId;

  Future<void> stop() async {
    _generation++;
    final subscription = _subscription;
    _subscription = null;
    _lastSentAt = null;
    if (subscription == null) return;

    try {
      await subscription.cancel();
      await _trackingService.stopObserving();
      _logger.info('session.location_heartbeat_stopped');
    } catch (error, stackTrace) {
      _logger.error(
        'session.location_heartbeat_stop_failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    await _sessionSubscription?.cancel();
    _sessionSubscription = null;
    await stop();
  }
}
