import 'package:equatable/equatable.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/authentication/domain/repositories/auth_repository.dart';

class Logout extends UseCase<void, LogoutParams> {
  const Logout(this._repository);
  final AuthRepository _repository;

  @override
  ResultFuture<void> call(LogoutParams params) =>
      _repository.logout(allDevices: params.allDevices);
}

class LogoutParams extends Equatable {
  const LogoutParams({this.allDevices = false});

  /// Ends every session the user holds, not just this device's.
  ///
  /// The server keeps up to five concurrent sessions per user, so signing out
  /// on a phone leaves the others alive by design. Pass true after a password
  /// change or a suspected compromise, where leaving them alive is the bug.
  final bool allDevices;

  @override
  List<Object?> get props => [allDevices];
}
