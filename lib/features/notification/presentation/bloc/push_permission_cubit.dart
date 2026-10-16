import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/database/hive/preference_keys.dart';
import 'package:steelforce/core/database/hive/local_cache.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/notification/domain/entities/push_registration.dart';
import 'package:steelforce/features/notification/domain/usecases/push_device_usecases.dart';

class PushPermissionState extends Equatable {
  const PushPermissionState({
    this.status = PushPermissionStatus.notDetermined,
    this.showExplainer = false,
    this.requesting = false,
  });

  final PushPermissionStatus status;

  /// Whether the in-app explainer card should be on screen right now.
  ///
  /// Never true on first launch — see [PushPermissionCubit.evaluate].
  final bool showExplainer;

  final bool requesting;

  /// The rep declined and the inbox should carry the unobtrusive banner that
  /// links to system settings (§14).
  ///
  /// Distinct from [showExplainer]: the explainer *asks*, the banner *explains
  /// why nothing is arriving*. Showing both at once would be nagging, which is
  /// why [showExplainer] wins while it is true.
  ///
  /// Covers `deniedPermanently` as well as `denied` — in the permanent case it
  /// is the *only* surface offered, because the OS will not prompt again and
  /// settings is the one place the answer can still change.
  bool get showDeclinedBanner => status.isDeclined && !showExplainer;

  PushPermissionState copyWith({
    PushPermissionStatus? status,
    bool? showExplainer,
    bool? requesting,
  }) =>
      PushPermissionState(
        status: status ?? this.status,
        showExplainer: showExplainer ?? this.showExplainer,
        requesting: requesting ?? this.requesting,
      );

  @override
  List<Object?> get props => [status, showExplainer, requesting];
}

/// Owns the permission-priming rules of
/// `docs/feature/notification/README.md` §14.
///
/// ## The single most consequential rule in the whole feature
///
/// **Do not request the OS push permission on first launch.** iOS gives an app
/// exactly one prompt, ever. Spending it on a rep who has just installed the app
/// and has no idea what it does is how an app ends up permanently silent — and
/// there is no recovery except talking every affected user through system
/// settings by hand.
///
/// So the prompt is gated behind an in-app explainer, shown only once the rep
/// has seen their first route and the sentence *"get notified the moment a
/// route, order, or approval needs you"* means something concrete to them.
///
/// ## What happens on a decline
///
/// Everything keeps working. The registration is posted with
/// `pushPermissionGranted: false` so the inbox still syncs and the delivery log
/// reads `NO_DEVICE` rather than a run of failures; the inbox shows an
/// unobtrusive banner linking to system settings; and the explainer may be
/// re-shown **at most once every 14 days**. That cap is [_reofferInterval], and
/// it is the difference between a reminder and nagging.
class PushPermissionCubit extends Cubit<PushPermissionState> {
  PushPermissionCubit({
    required GetPushPermissionStatus getStatus,
    required RequestPushPermission requestPermission,
    required LocalCache cache,
    DateTime Function()? clock,
  })  : _getStatus = getStatus,
        _request = requestPermission,
        _cache = cache,
        _now = clock ?? DateTime.now,
        super(const PushPermissionState());

  final GetPushPermissionStatus _getStatus;
  final RequestPushPermission _request;
  final LocalCache _cache;

  /// Injectable so the 14-day rule is testable without waiting a fortnight.
  final DateTime Function() _now;

  /// §14's cap on re-offering after a decline.
  static const Duration _reofferInterval = Duration(days: 14);

  /// Decides whether the explainer is due.
  ///
  /// [hasSeenFirstRoute] is the gate the spec's flow describes — login →
  /// onboarding → *the rep sees their first route* → explainer. The caller
  /// supplies it because the notification feature must not reach into the
  /// visits feature's data layer to find out.
  Future<void> evaluate({required bool hasSeenFirstRoute}) async {
    final status = await _getStatus();
    if (isClosed) return;

    // Nothing to ask for: already granted, or no push transport in this build
    // (web). `unsupported` deliberately does not show a declined banner either —
    // pointing a browser user at iOS system settings would be nonsense.
    if (status == PushPermissionStatus.granted ||
        status == PushPermissionStatus.provisional ||
        status == PushPermissionStatus.unsupported) {
      emit(state.copyWith(status: status, showExplainer: false));
      return;
    }

    if (!hasSeenFirstRoute) {
      emit(state.copyWith(status: status, showExplainer: false));
      return;
    }

    emit(state.copyWith(
      status: status,
      showExplainer: _mayOffer(status),
    ));
  }

  /// The rep tapped **Enable**. This is the only path to the OS prompt.
  Future<void> accept() async {
    if (state.requesting) return;
    emit(state.copyWith(requesting: true));

    // Stamped before the result lands, so a rep who dismisses the system prompt
    // by tapping outside it still starts the 14-day clock. Otherwise the
    // explainer reappears on the next evaluate and becomes the nagging §14 caps.
    await _stampOffered();

    final result = await _request(const NoParams());
    if (isClosed) return;

    emit(result.when(
      success: (status) => state.copyWith(
        status: status,
        showExplainer: false,
        requesting: false,
      ),
      // The permission call itself does not fail in a way worth surfacing — the
      // repository already swallows a registration failure and retries on the
      // next launch. Close the card either way; leaving it up would invite a
      // second tap that iOS will not honour.
      failure: (_) => state.copyWith(showExplainer: false, requesting: false),
    ));
  }

  /// The rep tapped **Not now**. Starts the 14-day clock.
  Future<void> defer() async {
    await _stampOffered();
    if (isClosed) return;
    emit(state.copyWith(showExplainer: false));
  }

  bool _mayOffer(PushPermissionStatus status) {
    // The OS has said it will not prompt again (Android 13+ after a hard
    // denial). The explainer's primary action is "Enable", which would call
    // `requestPermission()` and return the same denial without showing
    // anything — a button that silently does nothing. The settings banner is
    // the honest surface here, so never offer the card.
    if (!status.canPrompt) return false;

    final lastOffered = _readLastOffered();
    // Never offered: this is the first time the rep has reached the point where
    // the explainer makes sense.
    if (lastOffered == null) return true;

    // `notDetermined` after a previous offer means they tapped "Not now" — the
    // OS was never asked. Same 14-day cap as a decline; re-asking sooner is the
    // nagging §14 rules out.
    return _now().difference(lastOffered) >= _reofferInterval;
  }

  DateTime? _readLastOffered() {
    try {
      final raw = _cache.get<int>(PreferenceKeys.kPushExplainerShownAt);
      if (raw == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(raw);
    } catch (_) {
      // A corrupt entry means "never offered", which errs towards showing the
      // card once more rather than silencing it forever. Given the cost of the
      // opposite mistake — a rep who never receives anything — that is the right
      // direction to fail in.
      return null;
    }
  }

  Future<void> _stampOffered() => _cache.set(
        PreferenceKeys.kPushExplainerShownAt,
        _now().millisecondsSinceEpoch,
      );
}
