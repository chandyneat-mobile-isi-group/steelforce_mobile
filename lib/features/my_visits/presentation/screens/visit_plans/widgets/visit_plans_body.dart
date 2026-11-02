import 'package:flutter/material.dart';
import 'package:steelforce/features/my_visits/presentation/screens/visit_plans/widgets/visit_plans_summary_card.dart';
import 'package:steelforce/features/my_visits/presentation/screens/visit_plans/widgets/visit_plan_status_order.dart';
import 'package:steelforce/core/error/failure_message.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/visit_plan_calendar_state.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/visit_plans_state.dart';
import 'package:steelforce/features/my_visits/presentation/screens/visit_plans/widgets/visit_plans_day_list.dart';
import 'package:steelforce/features/my_visits/presentation/screens/visit_plans/widgets/visit_plans_status_views.dart';

/// The slivers below the calendar when **today** is picked: visits from
/// `GET /api/v1/mobile/plans/today`.
List<Widget> todayVisitSlivers(
  BuildContext context,
  VisitPlansState state, {
  required VoidCallback onRetry,
  ValueChanged<VisitPlan>? onOpenPlan,
  ValueChanged<VisitPlan>? onSkipPlan,
}) =>
    switch (state) {
      VisitPlansLoading() => [_box(context, const VisitPlansSkeleton())],
      VisitPlansFailure(:final failure) => [
          _fill(_error(failure, onRetry)),
        ],
      VisitPlansEmpty() => [
          _fill(VisitPlansMessage(
            icon: Icons.event_available_rounded,
            title: 'my_visits.plans.empty.title'.tr,
            hint: 'my_visits.plans.empty.hint'.tr,
          )),
        ],
      VisitPlansLoaded(:final overview) => [
          // Offline: the list is the device's copy, and says from when.
          if (overview.savedAt case final at?)
            _box(context, VisitPlansSavedNotice(savedAt: at)),
          // The day's progress: done, remaining, skipped, missed.
          _box(
              context,
              Padding(
                padding: EdgeInsets.only(bottom: context.rh(12)),
                child: VisitPlansSummaryCard(overview: overview),
              )),
          _list(context, overview.items, onOpenPlan, onSkipPlan),
        ],
    };

/// The slivers below the calendar when **another day** is picked: that day's
/// visits from the month the calendar loaded (`GET /api/v1/mobile/plans`).
List<Widget> selectedDaySlivers(
  BuildContext context,
  VisitPlanCalendarState state, {
  required VoidCallback onRetry,
  ValueChanged<VisitPlan>? onOpenPlan,
}) {
  final plans = state.selectedPlans;
  if (plans.isNotEmpty) return [_list(context, plans, onOpenPlan)];
  return switch (state.status) {
    VisitPlanCalendarStatus.loading => [
        _box(context, const VisitPlansSkeleton())
      ],
    VisitPlanCalendarStatus.failed => [_fill(_error(state.failure, onRetry))],
    VisitPlanCalendarStatus.loaded => [
        _fill(VisitPlansMessage(
          icon: Icons.event_busy_rounded,
          title: 'my_visits.plans.empty_day.title'.tr,
          hint: 'my_visits.plans.empty_day.hint'.tr,
        )),
      ],
  };
}

Widget _error(Failure? failure, VoidCallback onRetry) => VisitPlansMessage(
      icon: failure is NetworkFailure
          ? Icons.wifi_off_rounded
          : Icons.error_outline_rounded,
      title: 'my_visits.plans.error.title'.tr,
      hint: failure?.userMessage ?? 'common.generic_error'.tr,
      actionLabel: 'common.retry'.tr,
      onAction: onRetry,
      isError: true,
    );

Widget _box(BuildContext context, Widget child) => SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: context.rw(20)),
      sliver: SliverToBoxAdapter(child: child),
    );

Widget _fill(Widget child) =>
    SliverFillRemaining(hasScrollBody: false, child: child);

Widget _list(BuildContext context, List<VisitPlan> plans,
        ValueChanged<VisitPlan>? onOpenPlan,
        [ValueChanged<VisitPlan>? onSkipPlan]) =>
    SliverPadding(
      padding: EdgeInsets.fromLTRB(
          context.rw(20), 0, context.rw(20), context.rh(24)),
      // Active first, down to Checked in, Skipped, then Completed.
      sliver: VisitPlansDayList(
          plans: orderVisitsByStatus(plans),
          onOpenPlan: onOpenPlan,
          onSkipPlan: onSkipPlan),
    );
