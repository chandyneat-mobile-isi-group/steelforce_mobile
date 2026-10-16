import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/notification/domain/entities/push_registration.dart';
import 'package:steelforce/features/notification/domain/repositories/push_device_repository.dart';

/// Push-registration use cases (`docs/feature/notification/README.md` §4).
///
/// Grouped for the reason given at the top of `inbox_usecases.dart`. The rule
/// that matters — one use case per business action — holds: registering and
/// deregistering are opposite lifecycle events, and asking for the permission is
/// a third thing entirely, gated by a one-shot iOS prompt.

/// Registers or refreshes this installation.
///
/// §4.1 lists four callers, and all four are wired: after login, on every app
/// launch, from `onTokenRefresh`, and on a permission change. The endpoint is
/// idempotent on `deviceId`, so calling it too often costs one cheap round trip
/// — calling it too rarely is how a rep silently stops receiving anything.
class RegisterPushDevice implements UseCase<PushRegistrationResult?, NoParams> {
  const RegisterPushDevice(this._repository);

  final PushDeviceRepository _repository;

  @override
  ResultFuture<PushRegistrationResult?> call(NoParams params) =>
      _repository.register();
}

/// Deregisters this installation.
///
/// **Must run before the access token is discarded** (§4.4). Skipping it leaves
/// the platform pushing one rep's notifications at a handset that has since been
/// handed to somebody else.
class DeregisterPushDevice implements UseCase<void, NoParams> {
  const DeregisterPushDevice(this._repository);

  final PushDeviceRepository _repository;

  @override
  ResultFuture<void> call(NoParams params) => _repository.deregister();
}

/// Shows the OS permission prompt, then re-registers with the answer.
///
/// Called **only** from the in-app explainer (§14). iOS gives exactly one prompt
/// ever, and spending it on a rep who has not yet seen a route is how an app ends
/// up permanently silent.
class RequestPushPermission implements UseCase<PushPermissionStatus, NoParams> {
  const RequestPushPermission(this._repository);

  final PushDeviceRepository _repository;

  @override
  ResultFuture<PushPermissionStatus> call(NoParams params) =>
      _repository.requestPermission();
}

/// The OS permission as it stands right now.
///
/// Read rather than remembered: the rep can revoke it in system settings between
/// two launches, and a cached "granted" keeps a mute handset in the push
/// audience.
class GetPushPermissionStatus {
  const GetPushPermissionStatus(this._repository);

  final PushDeviceRepository _repository;

  Future<PushPermissionStatus> call() => _repository.permissionStatus();
}
