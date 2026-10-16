import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/profile/domain/entities/profile_update.dart';
import 'package:steelforce/features/profile/domain/entities/worker_profile.dart';
import 'package:steelforce/features/profile/domain/repositories/profile_repository.dart';

class UpdateWorkerProfile implements UseCase<WorkerProfile, ProfileUpdate> {
  const UpdateWorkerProfile(this._repository);
  final ProfileRepository _repository;

  @override
  Future<Result<WorkerProfile>> call(ProfileUpdate params) =>
      _repository.updateProfile(params);
}
