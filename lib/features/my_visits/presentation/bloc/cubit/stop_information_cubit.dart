import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/features/depots/domain/entities/depot_stop_information.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_stop_information_repository.dart';

/// Loads the outlet profile behind a stop, when the rep opens it.
///
/// Fetched here rather than with the route sync deliberately: a day's route can
/// be dozens of stops and a rep opens a handful, so pulling every outlet's
/// credit position up front would spend a market connection on data nobody
/// reads.
sealed class StopInformationState extends Equatable {
  const StopInformationState();
  @override
  List<Object?> get props => const [];
}

class StopInformationLoading extends StopInformationState {
  const StopInformationLoading();
}

class StopInformationReady extends StopInformationState {
  const StopInformationReady(this.information);
  final DepotStopInformation information;
  @override
  List<Object?> get props => [information];
}

/// The details could not be loaded. **The stop screen stays usable** — the
/// route sync already supplied the name, pin and geofence, and a rep standing
/// outside the shop needs those more than a credit limit.
class StopInformationUnavailable extends StopInformationState {
  const StopInformationUnavailable({
    required this.message,
    required this.isOffline,
  });

  final String message;

  /// Offline is a normal state, not an error state (ADR-0002 §4), so the UI
  /// says "not loaded" rather than showing a failure.
  final bool isOffline;

  @override
  List<Object?> get props => [message, isOffline];
}

class StopInformationCubit extends Cubit<StopInformationState> {
  StopInformationCubit(this._repository)
      : super(const StopInformationLoading());

  final DepotStopInformationRepository _repository;

  Future<void> load(String depotId) async {
    if (isClosed) return;
    emit(const StopInformationLoading());

    final result = await _repository.fetch(depotId);
    if (isClosed) return;

    emit(result.when(
      success: StopInformationReady.new,
      failure: (f) => StopInformationUnavailable(
        message: f.message,
        isOffline: f is NetworkFailure || f is ServerUnreachableFailure,
      ),
    ));
  }
}
