import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/notification/domain/repositories/notification_inbox_repository.dart';

/// Stores the next older inbox page for infinite scroll; the parameter is
/// `unreadOnly`. Succeeds with whether older pages remain.
class LoadOlderNotifications implements UseCase<bool, bool> {
  const LoadOlderNotifications(this._repository);

  final NotificationInboxRepository _repository;

  @override
  ResultFuture<bool> call(bool unreadOnly) =>
      _repository.loadOlder(unreadOnly: unreadOnly);
}
