import 'package:equatable/equatable.dart';
import 'package:steelforce/features/my_visits/domain/usecases/fetch_visit_data.dart';

sealed class VisitState extends Equatable {
  const VisitState();
  @override
  List<Object?> get props => [];
}

final class VisitLoading extends VisitState {
  const VisitLoading();
}

final class VisitLoaded extends VisitState {
  const VisitLoaded(this.data);
  final VisitData data;
  @override
  List<Object?> get props => [data];
}

final class VisitError extends VisitState {
  const VisitError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
