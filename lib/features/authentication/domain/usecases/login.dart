import 'package:equatable/equatable.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/authentication/domain/entities/auth_profile.dart';
import 'package:steelforce/features/authentication/domain/repositories/auth_repository.dart';

class Login extends UseCase<AuthProfile, LoginParams> {
  const Login(this._repository);
  final AuthRepository _repository;

  @override
  ResultFuture<AuthProfile> call(LoginParams params) => _repository.login(
        identifier: params.identifier,
        password: params.password,
        pushToken: params.pushToken,
        rememberDevice: params.rememberDevice,
      );
}

class LoginParams extends Equatable {
  const LoginParams({
    required this.identifier,
    required this.password,
    this.pushToken,
    this.rememberDevice = true,
  });

  /// Personnel number or e-mail address — one field, either value.
  final String identifier;
  final String password;

  /// FCM token, when messaging has been granted. Sent so the server can push
  /// to this installation; omitted rather than sent empty.
  final String? pushToken;

  /// A remembered device is protected from being retired first when the user
  /// exceeds their five concurrent sessions. A convenience, not a privilege:
  /// it grants nothing and extends no lifetime.
  final bool rememberDevice;

  @override
  List<Object?> get props => [identifier, password, rememberDevice];
}
