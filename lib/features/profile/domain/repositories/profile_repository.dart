import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/profile/domain/entities/profile_update.dart';
import 'package:steelforce/features/profile/domain/entities/worker_profile.dart';

/// Contract for reading/updating the signed-in worker's profile.
/// Implemented by `ProfileRepositoryImpl` in the data layer.
abstract class ProfileRepository {
  Future<Result<WorkerProfile>> getProfile();

  /// Sends [update] and returns the profile as the server now holds it.
  Future<Result<WorkerProfile>> updateProfile(ProfileUpdate update);

  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Clears the worker's session. Wire this to your `SessionManager`
  /// (see `RouteSyncCubit` for how the routes feature holds one) inside
  /// `ProfileRepositoryImpl`.
  Future<Result<void>> logout();
}
