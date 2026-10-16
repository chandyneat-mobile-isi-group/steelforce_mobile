import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/profile/data/datasources/auth_backed_profile_data_source.dart';
import 'package:steelforce/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:steelforce/features/profile/domain/entities/profile_failure_codes.dart';
import 'package:steelforce/features/profile/domain/entities/profile_update.dart';
import 'package:steelforce/features/profile/domain/entities/worker_profile.dart';
import 'package:steelforce/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({required ProfileRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  final ProfileRemoteDataSource _remoteDataSource;

  @override
  Future<Result<WorkerProfile>> getProfile() =>
      _guard(_remoteDataSource.fetchProfile);

  @override
  Future<Result<WorkerProfile>> updateProfile(ProfileUpdate update) async {
    // The server rejects an empty update; refusing it here saves the round
    // trip and gives the same answer.
    if (update.isEmpty) {
      return const Failed(ServerFailure(
        message: 'Nothing to save.',
        statusCode: 400,
        code: ApiErrorCodes.profileUpdateEmpty,
      ));
    }
    return _guard(() => _remoteDataSource.updateProfile(update));
  }

  @override
  Future<Result<void>> changePassword(
          {required String currentPassword, required String newPassword}) =>
      _guard(() => _remoteDataSource.changePassword(
          currentPassword: currentPassword, newPassword: newPassword));

  @override
  Future<Result<void>> logout() => _guard(_remoteDataSource.logout);

  /// One mapping for every call, so no screen ever renders an exception's
  /// `toString()`.
  Future<Result<T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Success(await call());
    } on ApiException catch (e) {
      if (e.error.code == ApiErrorCodes.network) {
        return const Failed(NetworkFailure());
      }
      return Failed(ServerFailure(
        message: e.error.message ?? 'Something went wrong. Please try again.',
        statusCode: e.error.statusCode,
        code: e.error.code,
      ));
    } on AvatarUnreadableException {
      return const Failed(ServerFailure(
        message: 'That picture could not be read.',
        code: ProfileFailureCodes.avatarUnreadable,
      ));
    } on ServerException catch (e) {
      return Failed(
          ServerFailure(message: e.message, statusCode: e.statusCode));
    }
  }
}
