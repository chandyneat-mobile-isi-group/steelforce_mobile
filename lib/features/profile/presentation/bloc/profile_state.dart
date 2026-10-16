import 'package:equatable/equatable.dart';
import 'package:steelforce/features/profile/domain/entities/worker_profile.dart';

sealed class ProfileState extends Equatable {
  const ProfileState();
  @override
  List<Object?> get props => [];
}

final class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

final class ProfileLoaded extends ProfileState {
  const ProfileLoaded({
    required this.profile,
    this.isSaving = false,
    this.actionError,
  });

  final WorkerProfile profile;
  final bool isSaving;
  final String? actionError;

  ProfileLoaded copyWith({
    WorkerProfile? profile,
    bool? isSaving,
    String? Function()? actionError,
  }) {
    return ProfileLoaded(
      profile: profile ?? this.profile,
      isSaving: isSaving ?? this.isSaving,
      actionError: actionError != null ? actionError() : this.actionError,
    );
  }

  @override
  List<Object?> get props => [profile, isSaving, actionError];
}

final class ProfileLoggedOut extends ProfileState {
  const ProfileLoggedOut();
}

final class ProfileError extends ProfileState {
  const ProfileError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
