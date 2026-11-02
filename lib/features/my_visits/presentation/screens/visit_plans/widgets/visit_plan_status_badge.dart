import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';

/// Colour, icon and label for a [VisitPlanStatus].
///
/// Each status carries an icon as well as a colour, so the distinction does
/// not depend on colour vision or on a sunlit screen. [today] is for tests.
({Color color, IconData icon, String label}) visitPlanStatusStyle(
    BuildContext context, VisitPlan plan,
    {DateTime? today}) {
  String label(String key) => 'my_visits.plans.status.$key'.tr;
  final style = _statusStyle(context, plan, today: today);
  // An ad hoc visit (`visitType: AdHoc`) says so in front of every status
  // after Draft — "Hoc Visit · Checked in" — so it never reads as planned.
  if (!plan.isAdHoc || plan.status == VisitPlanStatus.draft) return style;
  return (
    color: style.color,
    icon: style.icon,
    label: '${label('ad_hoc')} · ${style.label}',
  );
}

({Color color, IconData icon, String label}) _statusStyle(
    BuildContext context, VisitPlan plan,
    {DateTime? today}) {
  final colors = context.appColors;
  final scheme = Theme.of(context).colorScheme;
  String label(String key) => 'my_visits.plans.status.$key'.tr;
  return switch (plan.status) {
    // Planned today is the visit the rep can act on now: it reads "Active".
    VisitPlanStatus.planned when _isToday(plan, today ?? DateTime.now()) => (
        color: colors.success,
        icon: Icons.play_circle_outline_rounded,
        label: label('active')
      ),
    // Planned for another day stays "Planned".
    VisitPlanStatus.planned => (
        color: colors.info,
        icon: Icons.event_rounded,
        label: label('planned')
      ),
    VisitPlanStatus.checkedIn => (
        color: colors.warning,
        icon: Icons.login_rounded,
        label: label('checked_in')
      ),
    VisitPlanStatus.completed => (
        color: colors.success,
        icon: Icons.check_circle_rounded,
        label: label('completed')
      ),
    VisitPlanStatus.skipped => (
        color: colors.slate,
        icon: Icons.redo_rounded,
        label: label('skipped')
      ),
    VisitPlanStatus.missed => (
        color: scheme.error,
        icon: Icons.event_busy_rounded,
        label: label('missed')
      ),
    // An ad hoc visit still in Draft (`visitType: AdHoc`) is the rep's own
    // unplanned visit: it reads "Hoc Visit", in navy.
    VisitPlanStatus.draft when plan.isAdHoc => (
        color: colors.brandNavy,
        icon: Icons.add_location_alt_rounded,
        label: label('ad_hoc')
      ),
    VisitPlanStatus.draft => (
        color: colors.accentPurple,
        icon: Icons.edit_note_rounded,
        label: label('draft')
      ),
    VisitPlanStatus.cancelled => (
        color: colors.textHint,
        icon: Icons.cancel_outlined,
        label: label('cancelled')
      ),
    VisitPlanStatus.expired => (
        color: colors.textHint,
        icon: Icons.history_toggle_off_rounded,
        label: label('expired')
      ),
    VisitPlanStatus.unknown => (
        color: colors.textSecondary,
        icon: Icons.help_outline_rounded,
        label: plan.rawStatus.isEmpty ? label('unknown') : plan.rawStatus,
      ),
  };
}

/// True when [plan] is assigned to [today]'s calendar day. A plan with no
/// date is taken as today's: only the today list can carry one, the
/// calendar cannot place it.
bool _isToday(VisitPlan plan, DateTime today) {
  final date = plan.assignmentDate;
  return date == null ||
      (date.year == today.year &&
          date.month == today.month &&
          date.day == today.day);
}

/// The status pill on a visit card.
class VisitPlanStatusBadge extends StatelessWidget {
  const VisitPlanStatusBadge({super.key, required this.plan});

  final VisitPlan plan;

  @override
  Widget build(BuildContext context) {
    final style = visitPlanStatusStyle(context, plan);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: context.rw(8), vertical: context.rh(4)),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(context.rr(10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: context.rw(13), color: style.color),
          SizedBox(width: context.rw(4)),
          Flexible(
            child: Text(
              style.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: style.color,
                fontSize: context.rsp(11),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
