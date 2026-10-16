import 'package:steelforce/features/profile/data/models/worker_profile_model.dart';
import 'package:steelforce/features/profile/domain/entities/profile_update.dart';

/// The signed-in employee's own profile. Implemented by
/// `AuthBackedProfileDataSource`.
abstract class ProfileRemoteDataSource {
  Future<WorkerProfileModel> fetchProfile();

  /// `PUT /users/me/profile`. Returns the profile as the server now holds it.
  Future<WorkerProfileModel> updateProfile(ProfileUpdate update);

  Future<void> changePassword(
      {required String currentPassword, required String newPassword});

  Future<void> logout();
}
