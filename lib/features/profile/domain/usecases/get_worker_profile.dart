import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/profile/domain/entities/worker_profile.dart';
import 'package:steelforce/features/profile/domain/repositories/profile_repository.dart';

class GetWorkerProfile implements UseCase<WorkerProfile, NoParams> {
  const GetWorkerProfile(this._repository);
  final ProfileRepository _repository;

  @override
  Future<Result<WorkerProfile>> call(NoParams params) =>
      _repository.getProfile();
}
