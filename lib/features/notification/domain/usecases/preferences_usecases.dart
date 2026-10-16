import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/notification/domain/entities/notification_preferences.dart';
import 'package:steelforce/features/notification/domain/repositories/notification_preferences_repository.dart';

/// Notification-settings use cases (`docs/feature/notification/README.md` §13).
///
/// Grouped for the reason given at the top of `inbox_usecases.dart`.

/// Loads the settings document.
///
/// The screen is built from the response's `categories`, never from a list
/// compiled into the app — a category added server-side would otherwise stay
/// invisible until the next release (§13).
class LoadNotificationPreferences
    implements UseCase<NotificationPreferences, NoParams> {
  const LoadNotificationPreferences(this._repository);

  final NotificationPreferencesRepository _repository;

  @override
  ResultFuture<NotificationPreferences> call(NoParams params) =>
      _repository.load();
}

/// The cached document, without touching the network — for opening the screen
/// with content already on it instead of a spinner.
class GetCachedNotificationPreferences {
  const GetCachedNotificationPreferences(this._repository);

  final NotificationPreferencesRepository _repository;

  Future<NotificationPreferences?> call() => _repository.cached();
}

/// Saves the whole document.
///
/// Categories omitted from the payload are left alone server-side. Not queued for
/// offline replay, unlike inbox mutations — see
/// `NotificationPreferencesRepository.save` for why replaying a whole-document
/// overwrite would clobber another handset's changes.
class SaveNotificationPreferences
    implements UseCase<NotificationPreferences, NotificationPreferences> {
  const SaveNotificationPreferences(this._repository);

  final NotificationPreferencesRepository _repository;

  @override
  ResultFuture<NotificationPreferences> call(NotificationPreferences params) =>
      _repository.save(params);
}

/// Drops the cached document on sign-out — it is rep-scoped.
class ClearNotificationPreferences {
  const ClearNotificationPreferences(this._repository);

  final NotificationPreferencesRepository _repository;

  Future<void> call() => _repository.clear();
}
