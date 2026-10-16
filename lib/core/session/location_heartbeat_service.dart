import 'dart:async';

import 'package:steelforce/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:steelforce/features/my_visits/domain/services/location_tracking_service.dart';
import 'package:steelforce/core/logging/app_logger.dart';

import 'package:steelforce/core/session/session_manager.dart';

/// Periodically reports the device location to keep the session position current.
///
/// Needs a valid access token. Matches the telemetry rule: no more than one
/// report per 15 seconds, and only after ~25 m of movement.
class LocationHeartbeatService {
  LocationHeartbeatService({
    required LocationTrackingService trackingService,
    required AuthRemoteDataSource authRemoteDataSource,
    required SessionManager sessionManager,
    required AppLogger logger,
  })  : _trackingService = trackingService,
        _authRemoteDataSource = authRemoteDataSource,
        _sessionManager = sessionManager,
        _logger = logger {
    _sessionSubscription = _sessionManager.stateChanges.listen((state) {
      if (state == AuthenticationState.authenticated) {
        start();
      } else {
        stop();
      }
    });
    // If already authenticated on init
    if (_sessionManager.isAuthenticated) {
      start();
    }
  }

  final LocationTrackingService _trackingService;
  final AuthRemoteDataSource _authRemoteDataSource;
  final SessionManager _sessionManager;
  final AppLogger _logger;

  StreamSubscription? _subscription;
  StreamSubscription? _sessionSubscription;
  DateTime? _lastSentAt;

  static const _throttleInterval = Duration(seconds: 15);

  void start() {
    if (_subscription != null) return;

    _subscription = _trackingService
        .observe(distanceFilterMeters: 25)
        .listen((sample) async {
      final now = DateTime.now();
      if (_lastSentAt != null &&
          now.difference(_lastSentAt!) < _throttleInterval) {
        return;
      }

      if (sample.latitude == 0 && sample.longitude == 0) return;

      _lastSentAt = now;
      try {
        await _authRemoteDataSource.sendHeartbeat(
          sample.latitude,
          sample.longitude,
          sample.accuracyMeters,
          sample.timestamp,
        );
      } catch (e, st) {
        _logger.error('session.heartbeat_failed', error: e, stackTrace: st);
      }
    });
    _logger.info('Location heartbeat service started');
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _trackingService.stopObserving();
    _logger.info('Location heartbeat service stopped');
  }

  void dispose() {
    stop();
    _sessionSubscription?.cancel();
  }
}
