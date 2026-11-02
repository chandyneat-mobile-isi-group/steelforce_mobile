part of 'visit_plans_screen.dart';

/// What a visit card's actions do: open the depot, skip, show the map.
extension _VisitPlansActions on _VisitPlansScreenState {
  /// Today's list only: the server accepts a skip on the plan's own date.
  /// On success the today list has already reloaded; the calendar follows.
  Future<void> _skip(BuildContext context, VisitPlan plan) async {
    final today = context.read<VisitPlansCubit>();
    final calendar = context.read<VisitPlanCalendarCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final skipped = await showVisitPlanSkipSheet(
      context,
      plan: plan,
      submit: (reason) => today.skip(plan, reason),
    );
    if (!skipped) return;
    unawaited(calendar.load());
    messenger
        .showSnackBar(SnackBar(content: Text('my_visits.plans.skip.done'.tr)));
  }

  /// [startable] is the today list, the only one whose cards can start a
  /// visit — so only there does the details screen offer to.
  void _openDepot(BuildContext context, VisitPlan plan,
      {bool startable = false}) {
    final open = widget.onOpenPlan;
    if (open != null) return open(plan);
    unawaited(openVisitPlanDepot(context, plan,
        onCheckedIn: startable ? _reloadAfterCheckIn(context) : null));
  }

  VoidCallback _reloadAfterCheckIn(BuildContext context) {
    final today = context.read<VisitPlansCubit>();
    final calendar = context.read<VisitPlanCalendarCubit>();
    return () {
      unawaited(today.refresh());
      unawaited(calendar.load());
    };
  }

  /// Opens the picked day on the map, handed the visits the list is showing
  /// so the two cannot disagree. Always offered: the map has no pins until
  /// the plans API sends locations, and says so itself.
  void _openMap(BuildContext context, List<VisitPlan> plans, DateTime date) {
    Navigator.of(context).push(
      AppPageRoute<void>.sharedAxisVertical(
        builder: (_) => VisitPlansMapScreen(plans: plans, date: date),
      ),
    );
  }
}
