import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/profile/domain/repositories/profile_repository.dart';

class LogoutWorker implements UseCase<void, NoParams> {
  const LogoutWorker(this._repository);
  final ProfileRepository _repository;

  @override
  Future<Result<void>> call(NoParams params) => _repository.logout();
}
