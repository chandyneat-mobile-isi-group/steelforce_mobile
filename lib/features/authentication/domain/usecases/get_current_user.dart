import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/authentication/domain/entities/auth_profile.dart';
import 'package:steelforce/features/authentication/domain/repositories/auth_repository.dart';

/// Restores the cached session on boot.
///
/// Returns the full [AuthProfile] rather than the narrower `User`: the profile
/// carries the permission set, and without it a restored session knows *who*
/// the user is but not *what they may do* — so every permission-gated feature
/// would have to assume the worst (and skip) or the best (and fire a request
/// that comes back 403).
class GetCurrentUser extends UseCase<AuthProfile, NoParams> {
  const GetCurrentUser(this._repository);

  final AuthRepository _repository;

  @override
  ResultFuture<AuthProfile> call(NoParams params) =>
      _repository.getCurrentUser();
}
