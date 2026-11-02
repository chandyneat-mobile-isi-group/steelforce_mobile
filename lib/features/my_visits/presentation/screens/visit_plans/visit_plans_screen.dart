import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/animations/page_transition.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/error/failure_message.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/visit_plan_calendar_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/visit_plans_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/visit_plan_calendar_state.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/visit_plans_state.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/open_visit_plan.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/visit_plan_day_request.dart';
import 'package:steelforce/features/my_visits/presentation/screens/visit_plans/visit_plans_map_screen.dart';
import 'package:steelforce/features/my_visits/presentation/screens/visit_plans/widgets/visit_plan_skip_sheet.dart';
import 'package:steelforce/features/my_visits/presentation/screens/visit_plans/widgets/visit_plans_body.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/calendar/calendar_widget_section.dart';
import 'package:steelforce/shared/widgets/brand_wallpaper_background.dart';

part 'visit_plans_actions.dart';

/// The Visits tab.
///
/// Two sources, one per job: the calendar's day counts come from
/// `GET /api/v1/mobile/plans` ([VisitPlanCalendarCubit]); the list under it is
/// today's plan from `GET /api/v1/mobile/plans/today` ([VisitPlansCubit]).
/// Picking another day in the calendar lists that day's visits from the
/// calendar's data; picking today returns to the today list.
///
/// A card tap opens its depot's details; Start Visit (today only) checks in
/// and carries on with the visit. [onOpenPlan] replaces the card tap, for
/// tests and other hosts.
class VisitPlansScreen extends StatefulWidget {
  const VisitPlansScreen({super.key, this.onOpenPlan});

  final ValueChanged<VisitPlan>? onOpenPlan;

  @override
  State<VisitPlansScreen> createState() => _VisitPlansScreenState();
}

class _VisitPlansScreenState extends State<VisitPlansScreen> {
  DateTime _focusedMonth = DateTime.now();
  final _dayRequest = sl<VisitPlanDayRequest>();

  @override
  void initState() {
    super.initState();
    unawaited(context.read<VisitPlansCubit>().load());
    unawaited(context.read<VisitPlanCalendarCubit>().load());
    _dayRequest.addListener(_showRequestedDay);
    _showRequestedDay();
  }

  @override
  void dispose() {
    _dayRequest.removeListener(_showRequestedDay);
    super.dispose();
  }

  /// A notification asked for a day (`visit-plans / 2026-10-22`): pick it.
  void _showRequestedDay() {
    final day = _dayRequest.take();
    if (day == null) return;
    context.read<VisitPlanCalendarCubit>().selectDate(day);
    setState(() => _focusedMonth = day);
  }

  Future<void> _refresh() => Future.wait([
        context.read<VisitPlansCubit>().refresh(),
        context.read<VisitPlanCalendarCubit>().load(),
      ]);

  void _snack(BuildContext context, Failure failure, VoidCallback retry) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(failure.userMessage,
            maxLines: 3, overflow: TextOverflow.ellipsis),
        action: SnackBarAction(label: 'common.retry'.tr, onPressed: retry),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final today = context.read<VisitPlansCubit>();
    final calendar = context.read<VisitPlanCalendarCubit>();
    final todayState = context.watch<VisitPlansCubit>().state;
    final calendarState = context.watch<VisitPlanCalendarCubit>().state;

    // Today's dot agrees with the list under it: both read `/plans/today`.
    int countOn(DateTime day) => DateUtils.isSameDay(day, calendar.today) &&
            todayState is VisitPlansLoaded
        ? todayState.overview.items.length
        : calendarState.countOn(day);

    final body = calendar.isTodaySelected
        ? todayVisitSlivers(context, todayState,
            onRetry: today.refresh,
            onOpenPlan: (plan) => _openDepot(context, plan, startable: true),
            onSkipPlan: (plan) => _skip(context, plan))
        : selectedDaySlivers(context, calendarState,
            onRetry: calendar.load,
            onOpenPlan: (plan) => _openDepot(context, plan));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BrandWallpaperBody(
        style: BrandWallpaperStyle.vivid,
        child: SafeArea(
          child: MultiBlocListener(
            listeners: [
              // A failed refresh keeps today's list and says so.
              BlocListener<VisitPlansCubit, VisitPlansState>(
                listenWhen: (p, c) =>
                    c is VisitPlansLoaded &&
                    c.refreshFailure != null &&
                    (p is! VisitPlansLoaded ||
                        p.refreshFailure != c.refreshFailure),
                listener: (context, state) => _snack(context,
                    (state as VisitPlansLoaded).refreshFailure!, today.refresh),
              ),
              // While today is picked the calendar failing only costs the
              // dots, so it is a snackbar, not an error screen.
              BlocListener<VisitPlanCalendarCubit, VisitPlanCalendarState>(
                listenWhen: (p, c) =>
                    c.status == VisitPlanCalendarStatus.failed &&
                    p.status != c.status &&
                    calendar.isTodaySelected,
                listener: (context, state) =>
                    _snack(context, state.failure!, calendar.load),
              ),
            ],
            child: RefreshIndicator(
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: colors.surfaceSoft,
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(context.rw(20), context.rh(12),
                        context.rw(20), context.rh(12)),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StopCalendarSection(
                            focusedMonth: _focusedMonth,
                            selectedDate: calendarState.selectedDate,
                            onMonthChanged: (m) =>
                                setState(() => _focusedMonth = m),
                            onDateSelected: calendar.selectDate,
                            stopCountForDate: countOn,
                            onOpenMap: () => _openMap(
                              context,
                              calendar.isTodaySelected
                                  ? switch (todayState) {
                                      VisitPlansLoaded(:final overview) =>
                                        overview.items,
                                      _ => const <VisitPlan>[],
                                    }
                                  : calendarState.selectedPlans,
                              calendarState.selectedDate,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ...body,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
