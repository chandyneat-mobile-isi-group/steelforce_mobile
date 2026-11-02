import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/authentication/domain/entities/auth_profile.dart';
import 'package:steelforce/features/authentication/domain/repositories/auth_repository.dart';

/// Re-reads the signed-in rep's profile from the server and caches it, so the
/// next offline boot restores the current one. Offline it answers the cached
/// profile.
class RefreshProfile extends UseCase<AuthProfile, NoParams> {
  const RefreshProfile(this._repository);

  final AuthRepository _repository;

  @override
  ResultFuture<AuthProfile> call(NoParams params) =>
      _repository.refreshProfile();
}
