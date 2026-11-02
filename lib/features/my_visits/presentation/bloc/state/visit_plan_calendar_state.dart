import 'package:equatable/equatable.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plans_overview.dart';

enum VisitPlanCalendarStatus { loading, loaded, failed }

/// The Visits calendar, from `GET /api/v1/mobile/plans?period=ThisMonth`: the
/// day the rep picked, and the month's plans behind its day counts.
///
/// One class rather than a sealed family because [selectedDate] must survive
/// every load state — picking a day while the month is still loading is fine.
class VisitPlanCalendarState extends Equatable {
  const VisitPlanCalendarState({
    required this.selectedDate,
    this.status = VisitPlanCalendarStatus.loading,
    this.month,
    this.failure,
  });

  /// Midnight of the picked day. Today shows the `/plans/today` list instead.
  final DateTime selectedDate;
  final VisitPlanCalendarStatus status;

  /// The last month that loaded. Kept through a failed refresh.
  final VisitPlansOverview? month;
  final Failure? failure;

  /// How many visits the calendar dot shows for [day]; 0 before it loads.
  int countOn(DateTime day) => month?.plansOn(day).length ?? 0;

  List<VisitPlan> get selectedPlans => month?.plansOn(selectedDate) ?? const [];

  VisitPlanCalendarState copyWith({
    DateTime? selectedDate,
    VisitPlanCalendarStatus? status,
    VisitPlansOverview? month,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      VisitPlanCalendarState(
        selectedDate: selectedDate ?? this.selectedDate,
        status: status ?? this.status,
        month: month ?? this.month,
        failure: clearFailure ? null : failure ?? this.failure,
      );

  @override
  List<Object?> get props => [selectedDate, status, month, failure];
}
