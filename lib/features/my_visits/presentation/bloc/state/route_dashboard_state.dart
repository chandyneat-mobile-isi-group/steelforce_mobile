import 'package:equatable/equatable.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_dashboard_summary.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';

sealed class RouteDashboardState extends Equatable {
  const RouteDashboardState();
  @override
  List<Object?> get props => [];
}

final class RouteDashboardLoading extends RouteDashboardState {
  const RouteDashboardLoading();
}

final class RouteDashboardLoaded extends RouteDashboardState {
  const RouteDashboardLoaded({required this.routes, required this.summary});
  final List<RoutePlan> routes;
  final RouteDashboardSummary summary;
  @override
  List<Object?> get props => [routes, summary];
}

final class RouteDashboardError extends RouteDashboardState {
  const RouteDashboardError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
