import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/database/hive/preference_keys.dart';
import 'package:steelforce/core/database/hive/local_cache.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/notifications/push/push_messaging_service.dart';
import 'package:steelforce/core/permissions/location_permission_service.dart';

/// Which permission a row in the dialog is about.
enum AppPermission { notifications, location }

/// What the dialog is doing with one permission.
enum PermissionOutcome {
  /// Not asked yet — the row shows its reason and waits.
  pending,

  /// A system prompt is on screen for this one.
  asking,

  granted,

  /// Declined, and the OS may prompt again later.
  declined,

  /// Declined permanently, or location services are off. Only settings helps.
  blocked,

  /// Not available on this platform at all. The row is hidden rather than shown
  /// as a failure — a browser user has not done anything wrong.
  unavailable,
}

class AppPermissionsState extends Equatable {
  const AppPermissionsState({
    this.notifications = PermissionOutcome.pending,
    this.location = PermissionOutcome.pending,
    this.isRequesting = false,
    this.settled = false,
  });

  final PermissionOutcome notifications;
  final PermissionOutcome location;

  /// A prompt sequence is running. Disables the buttons so a second tap cannot
  /// start a second sequence over the first system dialog.
  final bool isRequesting;

  /// Every permission the dialog can act on has an answer, so it may close.
  final bool settled;

  PermissionOutcome outcomeFor(AppPermission permission) =>
      switch (permission) {
        AppPermission.notifications => notifications,
        AppPermission.location => location,
      };

  /// The rows worth rendering. An [PermissionOutcome.unavailable] permission is
  /// omitted entirely — showing "not supported" teaches the rep nothing and
  /// makes the dialog look broken on web.
  List<AppPermission> get visiblePermissions => [
        for (final permission in AppPermission.values)
          if (outcomeFor(permission) != PermissionOutcome.unavailable)
            permission,
      ];

  /// True when at least one permission still needs the rep's answer, i.e. the
  /// dialog has a reason to exist.
  bool get hasAnythingToAsk => visiblePermissions.any((p) {
        final outcome = outcomeFor(p);
        return outcome == PermissionOutcome.pending ||
            outcome == PermissionOutcome.declined;
      });

  /// True when something ended up needing the settings app, so the dialog can
  /// swap its primary action for a settings link.
  bool get needsSettings =>
      notifications == PermissionOutcome.blocked ||
      location == PermissionOutcome.blocked;

  AppPermissionsState copyWith({
    PermissionOutcome? notifications,
    PermissionOutcome? location,
    bool? isRequesting,
    bool? settled,
  }) =>
      AppPermissionsState(
        notifications: notifications ?? this.notifications,
        location: location ?? this.location,
        isRequesting: isRequesting ?? this.isRequesting,
        settled: settled ?? this.settled,
      );

  @override
  List<Object?> get props => [notifications, location, isRequesting, settled];
}

/// Drives the one dialog that primes **both** OS permissions this app needs, and
/// registers the handset for push once the answer is known.
///
/// ## Why one dialog for two permissions
///
/// The app needs notifications (a route assignment has to reach the rep) and
/// foreground location (a depot's coordinates, and check-in verification).
/// Both were previously requested cold — push from the inbox card, location from
/// inside the depot form when the rep tapped "Save GPS". Two unexplained
/// system prompts at two unrelated moments is the worst possible framing, and on
/// iOS each one is close to a single chance.
///
/// So they are asked together, once, at a moment the rep can evaluate, with the
/// reason for each stated before the OS dialog appears. That is
/// `docs/feature/notification/README.md` §14's priming rule applied
/// to both permissions rather than only to push.
///
/// ## Why it lives in `core/` and not in a feature
///
/// Notifications belong to `features/notification`; location is used by
/// `features/order` and `features/my_visits`. A dialog covering both cannot live
/// in any one of them without that feature importing another's internals, which
/// `docs/skills/ai-engineering-playbook.md` §12 forbids. Both dependencies here
/// are already `core/` platform abstractions, so this composes them without
/// depending on a feature at all.
///
/// Push **registration** is a notification-feature concern, so it arrives as an
/// injected callback rather than a repository — the same seam the inbox cubit
/// uses for an action's `api_call`.
///
/// ## What it deliberately does not ask for
///
/// Background location. `GeolocatorTrackingService` escalates to "always"
/// immediately before it starts a route trace, which is both the iOS guideline
/// and the existing behaviour. Asking for background up front is how an app gets
/// refused foreground too.
class AppPermissionsCubit extends Cubit<AppPermissionsState> {
  AppPermissionsCubit({
    required PushMessagingService messaging,
    required LocationPermissionService location,
    required LocalCache cache,
    required AppLogger logger,
    required Future<void> Function() registerPushDevice,
    DateTime Function()? clock,
  })  : _messaging = messaging,
        _location = location,
        _cache = cache,
        _logger = logger,
        _registerPushDevice = registerPushDevice,
        _now = clock ?? DateTime.now,
        super(const AppPermissionsState());

  final PushMessagingService _messaging;
  final LocationPermissionService _location;
  final LocalCache _cache;
  final AppLogger _logger;

  /// Posts the device + token to `POST /mobile/devices/register`.
  ///
  /// Called after the notification answer is known — **whichever way it went**.
  /// §4.2: a declined registration is still kept, with
  /// `pushPermissionGranted: false`, so the inbox keeps syncing and the delivery
  /// log reads `NO_DEVICE` once rather than a run of failures.
  final Future<void> Function() _registerPushDevice;

  /// Injectable so the re-offer window is testable without waiting a fortnight.
  final DateTime Function() _now;

  /// §14's cap on re-offering after a decline.
  static const Duration reofferInterval = Duration(days: 14);

  /// Reads the current state of both permissions without prompting.
  Future<void> load() async {
    final notifications = _outcomeForAuthorization(
      await _messaging.authorization(),
    );
    final location = _outcomeForLocation(await _location.status());
    if (isClosed) return;

    emit(state.copyWith(
      notifications: notifications,
      location: location,
      settled: false,
    ));
  }

  /// Whether the dialog should be shown at all right now.
  ///
  /// [hasSeenFirstRoute] is the §14 gate, supplied by the caller: the
  /// notification feature must not reach into the visits feature to find out.
  /// A rep who has not yet seen a route has no reason to say yes to either
  /// permission, and iOS does not give the app a second chance to ask.
  Future<bool> shouldPrompt({required bool hasSeenFirstRoute}) async {
    final decision = await _decide(hasSeenFirstRoute: hasSeenFirstRoute);

    // Logged, always, with the reason.
    //
    // This returned a bare bool and explained nothing, which made
    // `push.permission status=notDetermined` unanswerable from the logs: the
    // status says the prompt has not run, and the only thing that runs it is
    // this method, silently declining for one of four different reasons. Three
    // of them are correct behaviour and one is a stale 14-day stamp from a
    // dismissal the rep has forgotten — indistinguishable without this line.
    _logger.info('permissions.primer', fields: {
      'show': decision.show,
      'reason': decision.reason,
      'notifications': state.notifications.name,
      'location': state.location.name,
    });

    return decision.show;
  }

  Future<_PrimerDecision> _decide({required bool hasSeenFirstRoute}) async {
    // §14's gate. Nothing has been asked and nothing should be.
    if (!hasSeenFirstRoute) {
      return const _PrimerDecision(false, 'no_route_seen_yet');
    }

    await load();
    if (isClosed) return const _PrimerDecision(false, 'closed');

    // Everything is granted, permanently blocked, or unavailable on this
    // platform — the dialog has no question left to put.
    if (!state.hasAnythingToAsk) {
      return _PrimerDecision(
        false,
        state.needsSettings ? 'blocked_needs_settings' : 'nothing_to_ask',
      );
    }

    final lastOffered = _readLastOffered();
    if (lastOffered == null) {
      return const _PrimerDecision(true, 'first_offer');
    }

    final elapsed = _now().difference(lastOffered);
    if (elapsed >= reofferInterval) {
      return const _PrimerDecision(true, 'reoffer_window_open');
    }

    // The most confusing of the four, and the reason the remaining days are
    // named: a rep who tapped "Not now" days ago sees a permanent
    // `notDetermined` with no dialog and no explanation.
    return _PrimerDecision(
      false,
      'within_reoffer_cap_${(reofferInterval - elapsed).inDays}d_left',
    );
  }

  /// The rep tapped **Enable**. Asks for each outstanding permission in turn.
  ///
  /// Sequential, never concurrent: two overlapping system dialogs is undefined
  /// on both platforms, and on Android the second silently replaces the first so
  /// the rep answers one question and is recorded as having answered two.
  ///
  /// Notifications go first because push is the permission the rep just read a
  /// justification for, and because its answer gates the device registration.
  Future<void> requestAll() async {
    if (state.isRequesting) return;

    // Stamped before any prompt. A rep who dismisses a system dialog by tapping
    // outside it leaves the status unchanged, and without this the dialog
    // returns on the very next launch — the nagging §14 caps.
    await _stampOffered();
    if (isClosed) return;
    emit(state.copyWith(isRequesting: true));

    if (state.notifications == PermissionOutcome.pending ||
        state.notifications == PermissionOutcome.declined) {
      emit(state.copyWith(notifications: PermissionOutcome.asking));
      final result = _outcomeForAuthorization(
        await _messaging.requestPermission(),
      );
      if (isClosed) return;
      emit(state.copyWith(notifications: result));

      // Registered whichever way it went — see [_registerPushDevice].
      await _register();
      if (isClosed) return;
    }

    if (state.location == PermissionOutcome.pending ||
        state.location == PermissionOutcome.declined) {
      emit(state.copyWith(location: PermissionOutcome.asking));
      final result = _outcomeForLocation(await _location.request());
      if (isClosed) return;
      emit(state.copyWith(location: result));
    }

    if (isClosed) return;
    emit(state.copyWith(isRequesting: false, settled: true));

    _logger.info('permissions.primed', fields: {
      'notifications': state.notifications.name,
      'location': state.location.name,
    });
  }

  /// The rep tapped **Not now**. Starts the 14-day clock and closes.
  ///
  /// The device is still registered, with the permission state as it stands, so
  /// the inbox syncs and the platform knows not to push at this handset.
  Future<void> skip() async {
    await _stampOffered();
    await _register();
    if (isClosed) return;
    emit(state.copyWith(settled: true));
    _logger.info('permissions.deferred');
  }

  /// Opens the OS settings page, for a permission only settings can change.
  Future<bool> openSettings() => _location.openSettings();

  /// Registers the handset, swallowing failure.
  ///
  /// Never fatal: a rep who cannot register for push must still reach their
  /// inbox, and the registration is retried on the next launch, the next token
  /// rotation and the next permission change — §4.1's four triggers exist so no
  /// single failure is permanent.
  Future<void> _register() async {
    try {
      await _registerPushDevice();
    } catch (error, stackTrace) {
      _logger.error('permissions.device_registration_failed',
          error: error, stackTrace: stackTrace);
    }
  }

  PermissionOutcome _outcomeForAuthorization(PushAuthorization authorization) =>
      switch (authorization) {
        PushAuthorization.authorized ||
        PushAuthorization.provisional =>
          PermissionOutcome.granted,
        PushAuthorization.notDetermined => PermissionOutcome.pending,
        PushAuthorization.denied => PermissionOutcome.declined,
        PushAuthorization.deniedPermanently => PermissionOutcome.blocked,
        // Web has no transport. Hidden rather than shown as declined.
        PushAuthorization.unsupported => PermissionOutcome.unavailable,
      };

  PermissionOutcome _outcomeForLocation(LocationPermissionStatus status) =>
      switch (status) {
        LocationPermissionStatus.whileInUse ||
        LocationPermissionStatus.always =>
          PermissionOutcome.granted,
        LocationPermissionStatus.notDetermined => PermissionOutcome.pending,
        LocationPermissionStatus.denied => PermissionOutcome.declined,
        // Both need the settings app, for different reasons the dialog explains
        // separately — a permanent denial versus a device-wide toggle.
        LocationPermissionStatus.deniedForever ||
        LocationPermissionStatus.servicesDisabled =>
          PermissionOutcome.blocked,
        LocationPermissionStatus.unsupported => PermissionOutcome.unavailable,
      };

  DateTime? _readLastOffered() {
    try {
      final raw = _cache.get<int>(PreferenceKeys.kPermissionPrimerShownAt);
      if (raw == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(raw);
    } catch (_) {
      // A corrupt entry reads as "never offered", which errs towards showing the
      // dialog once more rather than silencing it for good. Given the cost of
      // the opposite mistake — a rep who never receives a route assignment —
      // that is the right direction to fail in.
      return null;
    }
  }

  Future<void> _stampOffered() => _cache.set(
        PreferenceKeys.kPermissionPrimerShownAt,
        _now().millisecondsSinceEpoch,
      );
}

/// Why the primer is or is not being shown. Internal to
/// [AppPermissionsCubit.shouldPrompt]'s logging.
class _PrimerDecision {
  const _PrimerDecision(this.show, this.reason);

  final bool show;
  final String reason;
}
