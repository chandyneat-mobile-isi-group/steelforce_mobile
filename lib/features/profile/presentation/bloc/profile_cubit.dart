import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/session/unsent_work.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/profile/domain/entities/profile_update.dart';
import 'package:steelforce/features/profile/domain/usecases/change_password.dart';
import 'package:steelforce/features/profile/domain/usecases/get_worker_profile.dart';
import 'package:steelforce/features/profile/domain/usecases/logout_worker.dart';
import 'package:steelforce/features/profile/domain/usecases/update_worker_profile.dart';
import 'package:steelforce/features/profile/presentation/bloc/profile_state.dart';

/// Loads and mutates the signed-in worker's profile. Single-cubit shape,
/// mirroring `RouteDashboardCubit`.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required GetWorkerProfile getWorkerProfile,
    required UpdateWorkerProfile updateWorkerProfile,
    required ChangePassword changePassword,
    required LogoutWorker logoutWorker,
    UnsentWorkService? unsentWork,
  })  : _unsentWork = unsentWork,
        _getWorkerProfile = getWorkerProfile,
        _updateWorkerProfile = updateWorkerProfile,
        _changePassword = changePassword,
        _logoutWorker = logoutWorker,
        super(const ProfileLoading());

  final GetWorkerProfile _getWorkerProfile;
  final UpdateWorkerProfile _updateWorkerProfile;
  final ChangePassword _changePassword;
  final LogoutWorker _logoutWorker;
  final UnsentWorkService? _unsentWork;

  /// Items saved on this device that the server does not have yet, by kind.
  /// Sign-out wipes the device, so it is refused while this is not empty.
  Future<List<UnsentWorkCount>> unsentWork() async {
    final service = _unsentWork;
    if (service == null) return const [];
    // The total is what gates sign-out; the breakdown only describes it. If a
    // source could not describe its items, the difference still shows.
    final total = await service.count();
    final parts = await service.breakdown();
    final described = parts.fold<int>(0, (sum, p) => sum + p.unsent);
    return [
      ...parts,
      if (total > described)
        UnsentWorkCount(UnsentWorkKind.other, total - described),
    ];
  }

  /// Loads the profile. A refresh keeps the profile on screen while it
  /// runs — only a first load shows the spinner.
  Future<void> load() async {
    final current = state;
    if (current is! ProfileLoaded) emit(const ProfileLoading());
    final result = await _getWorkerProfile(const NoParams());
    if (isClosed) return;
    result.when(
      success: (profile) => emit(ProfileLoaded(profile: profile)),
      failure: (f) => current is ProfileLoaded
          ? emit(current.copyWith(actionError: () => f.message))
          : emit(ProfileError(f.message)),
    );
  }

  /// Saves [update] and returns null on success, or the failure for the edit
  /// sheet to show **in place** — the sheet stays open so nothing typed is
  /// lost to a dropped connection.
  Future<Failure?> updateProfile(ProfileUpdate update) async {
    final current = state;
    if (current is! ProfileLoaded) return null;
    emit(current.copyWith(isSaving: true, actionError: () => null));
    final result = await _updateWorkerProfile(update);
    if (isClosed) return null;
    return result.when(
      success: (profile) {
        emit(ProfileLoaded(profile: profile));
        return null;
      },
      failure: (f) {
        emit(current.copyWith(isSaving: false));
        return f;
      },
    );
  }

  Future<bool> changePassword(
      {required String currentPassword, required String newPassword}) async {
    final current = state;
    if (current is! ProfileLoaded) return false;
    emit(current.copyWith(isSaving: true, actionError: () => null));
    final result = await _changePassword(
      ChangePasswordParams(
          currentPassword: currentPassword, newPassword: newPassword),
    );
    return result.when(
      success: (_) {
        emit(current.copyWith(isSaving: false));
        return true;
      },
      failure: (f) {
        emit(current.copyWith(isSaving: false, actionError: () => f.message));
        return false;
      },
    );
  }

  /// Returns true on success so the caller can proceed to clear the app's
  /// auth session (see `ProfileScreen`, which follows this with an
  /// `AuthBloc` `LogoutRequested` to clear the real token store and
  /// trigger navigation to login).
  Future<bool> logout() async {
    final result = await _logoutWorker(const NoParams());
    return result.when(
      success: (_) {
        emit(const ProfileLoggedOut());
        return true;
      },
      failure: (f) {
        emit(ProfileError(f.message));
        return false;
      },
    );
  }
}
