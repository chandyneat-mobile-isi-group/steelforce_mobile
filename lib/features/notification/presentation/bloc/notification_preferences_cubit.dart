import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/notification/domain/entities/notification_preferences.dart';
import 'package:steelforce/features/notification/domain/usecases/preferences_usecases.dart';

class NotificationPreferencesState extends Equatable {
  const NotificationPreferencesState({
    this.preferences = NotificationPreferences.unset,
    this.loading = true,
    this.saving = false,
    this.loadFailed = false,
    this.errorMessage,
  });

  final NotificationPreferences preferences;
  final bool loading;
  final bool saving;

  /// The document could not be loaded and nothing was cached, so the screen has
  /// nothing truthful to render.
  ///
  /// Distinct from an empty document: §13 says a rep who has never opened this
  /// screen still gets a full response with everything on, so "no categories"
  /// legitimately means "the server sent none" and must not be rendered as an
  /// error.
  final bool loadFailed;

  final String? errorMessage;

  bool get hasContent => preferences.categories.isNotEmpty;

  NotificationPreferencesState copyWith({
    NotificationPreferences? preferences,
    bool? loading,
    bool? saving,
    bool? loadFailed,
    String? errorMessage,
    bool clearError = false,
  }) =>
      NotificationPreferencesState(
        preferences: preferences ?? this.preferences,
        loading: loading ?? this.loading,
        saving: saving ?? this.saving,
        loadFailed: loadFailed ?? this.loadFailed,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );

  @override
  List<Object?> get props =>
      [preferences, loading, saving, loadFailed, errorMessage];
}

/// Drives the notification settings screen
/// (`docs/feature/notification/README.md` §13).
///
/// ## The screen is built from the server's answer
///
/// §13 requires the category list to come from `GET /preferences`, never from a
/// list compiled into the app — a category added server-side would otherwise
/// stay invisible until the next release. This cubit therefore holds the whole
/// document verbatim and the widget renders whatever is in it, including a
/// category code this build has never heard of.
///
/// ## Saves are pessimistic, unlike inbox mutations
///
/// The inbox queues its writes and reports success immediately, because a rep
/// acknowledging a route offline has genuinely done the work. Preferences do the
/// opposite: [toggleCategory] waits for the server and reverts on failure. A
/// whole-document `PUT` with no server-side merge cannot be safely replayed
/// later — a stale document would silently clobber a change the rep made on
/// another handset — so the honest thing is to fail visibly and let them retry.
class NotificationPreferencesCubit extends Cubit<NotificationPreferencesState> {
  NotificationPreferencesCubit({
    required LoadNotificationPreferences load,
    required GetCachedNotificationPreferences cached,
    required SaveNotificationPreferences save,
  })  : _load = load,
        _cached = cached,
        _save = save,
        super(const NotificationPreferencesState());

  final LoadNotificationPreferences _load;
  final GetCachedNotificationPreferences _cached;
  final SaveNotificationPreferences _save;

  /// Opens the screen with the cached document, then refreshes from the server.
  ///
  /// Both, in that order: the cache makes the screen open with content instead
  /// of a spinner, and the refresh is what makes a toggle changed on another
  /// handset appear here — preferences follow the rep across devices, so the
  /// cache is never authoritative.
  Future<void> load() async {
    final cached = await _cached();
    if (isClosed) return;
    if (cached != null) {
      emit(state.copyWith(preferences: cached, loading: false));
    }

    final result = await _load(const NoParams());
    if (isClosed) return;

    emit(result.when(
      success: (preferences) => state.copyWith(
        preferences: preferences,
        loading: false,
        loadFailed: false,
        clearError: true,
      ),
      failure: (failure) => state.copyWith(
        loading: false,
        // Only a hard failure when there is nothing at all to show. With a
        // cached document on screen the rep can read their real settings, and an
        // error page over them would be strictly less useful.
        loadFailed: cached == null,
        errorMessage: _messageFor(failure),
      ),
    ));
  }

  /// Flips one category's `isEnabled` or `pushEnabled`.
  ///
  /// A **locked** category is refused here rather than sent and rejected. §13
  /// says the server answers `422 Notification.CategoryNotMutable` instead of
  /// silently ignoring it, precisely so a toggle never snaps back with no
  /// explanation — and the cleanest way to honour that is for the toggle not to
  /// move in the first place, with the row rendered disabled and a tooltip
  /// saying why.
  Future<void> toggleCategory(
    String categoryCode, {
    bool? isEnabled,
    bool? pushEnabled,
  }) async {
    final current = state.preferences.categoryPreference(categoryCode);
    if (current == null || current.isLocked) return;

    final previous = state.preferences;
    final updated = previous.withCategory(
      categoryCode,
      isEnabled: isEnabled,
      pushEnabled: pushEnabled,
    );

    // Moved immediately so the switch animates under the rep's finger, then
    // reverted below if the server refuses. A switch that waits a round trip
    // before moving feels broken even when it works.
    emit(state.copyWith(
      preferences: updated,
      saving: true,
      clearError: true,
    ));

    await _persist(updated, revertTo: previous);
  }

  /// Sets or clears the quiet-hours window.
  ///
  /// Start and end move **together or not at all** — §13: one without the other
  /// answers `400 Notification.QuietHoursIncomplete`. Passing null for both
  /// clears the window.
  Future<void> setQuietHours({String? start, String? end}) async {
    final previous = state.preferences;

    // A half-set window is rejected here rather than sent. The rep gets a
    // message they can act on instead of a 400 whose `detail` is English
    // developer text.
    if ((start == null) != (end == null)) {
      emit(state.copyWith(
        errorMessage: 'notifications.settings.quiet_hours_incomplete'.tr,
      ));
      return;
    }

    final updated = start == null
        ? previous.copyWith(clearQuietHours: true)
        : previous.copyWith(quietHoursStart: start, quietHoursEnd: end);

    emit(state.copyWith(
      preferences: updated,
      saving: true,
      clearError: true,
    ));
    await _persist(updated, revertTo: previous);
  }

  /// Sets the days the quiet window applies to.
  ///
  /// An **empty list means every day**, not "no days" (§13), so clearing every
  /// chip is a valid and meaningful state rather than something to guard against.
  Future<void> setQuietDays(List<String> days) async {
    final previous = state.preferences;
    final updated = previous.copyWith(quietDays: days);
    emit(state.copyWith(
      preferences: updated,
      saving: true,
      clearError: true,
    ));
    await _persist(updated, revertTo: previous);
  }

  /// Sets the daily digest time, or clears it.
  Future<void> setDigestTime(String? time) async {
    final previous = state.preferences;
    final updated = previous.copyWith(digestTime: time);
    emit(state.copyWith(
      preferences: updated,
      saving: true,
      clearError: true,
    ));
    await _persist(updated, revertTo: previous);
  }

  void acknowledgeError() {
    if (state.errorMessage == null) return;
    emit(state.copyWith(clearError: true));
  }

  Future<void> _persist(
    NotificationPreferences updated, {
    required NotificationPreferences revertTo,
  }) async {
    final result = await _save(updated);
    if (isClosed) return;

    emit(result.when(
      // The echoed document, not the one that was sent: the server may have
      // normalised a value, and rendering what it actually stored keeps the
      // screen honest.
      success: (saved) => state.copyWith(preferences: saved, saving: false),
      failure: (failure) => state.copyWith(
        preferences: revertTo,
        saving: false,
        errorMessage: _messageFor(failure),
      ),
    ));
  }

  /// Client-raised failures carry English developer text and are translated
  /// here; server failures keep their message, already localised against the
  /// `Accept-Language` header the app sends.
  String _messageFor(Failure failure) => switch (failure) {
        NetworkFailure() => 'common.no_connection'.tr,
        ServerUnreachableFailure() => 'common.server_unreachable'.tr,
        _ => failure.message,
      };
}
