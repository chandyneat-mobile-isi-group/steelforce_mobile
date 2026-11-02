import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/animated_card.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/presentation/screens/visit_plans/widgets/visit_plan_facts_line.dart';
import 'package:steelforce/features/my_visits/presentation/screens/visit_plans/widgets/visit_plan_card_actions.dart';
import 'package:steelforce/features/my_visits/presentation/screens/visit_plans/widgets/visit_plan_status_badge.dart';
import 'package:steelforce/features/my_visits/presentation/screens/visit_plans/widgets/visit_plan_sync_chip.dart';

/// One visit in the plan list, laid out like the stop card: depot name and
/// address, a status tag in the corner, then "territory · type · tier" with
/// the map and skip actions. A value the server sent as null reads "Null".
///
/// [onTap] opens the depot (where Start Visit lives) and [onSkip] skips.
/// While null the card does not react and that action is not drawn — never a
/// control that does nothing.
class VisitPlanCard extends StatelessWidget {
  const VisitPlanCard({super.key, required this.plan, this.onTap, this.onSkip});

  final VisitPlan plan;
  final ValueChanged<VisitPlan>? onTap;
  final ValueChanged<VisitPlan>? onSkip;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final status = visitPlanStatusStyle(context, plan);
    // Only an active (planned) visit is highlighted; every other status is a
    // plain grey tag.
    final tagColor = plan.status == VisitPlanStatus.planned
        ? status.color
        : colors.textSecondary;
    final radius = context.rr(16);
    final padEnd = context.rw(16);
    final padTop = context.rh(12);
    // A skipped visit is done with: its card does not open the depot, and
    // its skip mark shows the state in the warning colour without acting.
    final skipped = plan.status == VisitPlanStatus.skipped;
    // An ad hoc visit is the other solid tag, on navy, whatever its status:
    // the label says "Hoc Visit" first, then where the visit is.
    final solidTag = skipped
        ? (scheme.error, scheme.onError)
        : plan.isAdHoc
            ? (colors.brandNavy, Colors.white)
            : null;
    final tap = skipped ? null : onTap;
    final skip = onSkip;
    final secondary = TextStyle(
      color: colors.textSecondary,
      fontSize: context.rsp(11.5),
    );

    final body = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
          context.rw(16), padTop, padEnd, context.rh(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _orNull(plan.displayName),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: context.rsp(15),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: context.rh(4)),
                    // The plans API sends no address yet: reads "Null".
                    Text(_orNull(null),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: secondary),
                    // Steps worked offline and not on the server yet.
                    if (plan.syncState != PlanSyncState.synced) ...[
                      SizedBox(height: context.rh(4)),
                      VisitPlanSyncChip(plan: plan),
                    ],
                  ],
                ),
              ),
              SizedBox(width: context.rw(12)),
              // Pinned into the card's top-right corner, out over the padding
              // and inset by the 1px border, as on the stop card.
              Transform.translate(
                offset: Offset(
                  (Directionality.of(context) == TextDirection.rtl ? -1 : 1) *
                      (padEnd - 1),
                  -(padTop - 1),
                ),
                child: AnimatedContainer(
                  duration: AppDurations.medium,
                  curve: AppCurves.standard,
                  // "Hoc Visit · Checked in" is long; the name keeps the rest.
                  constraints: BoxConstraints(maxWidth: context.rw(170)),
                  padding: EdgeInsets.symmetric(
                      horizontal: context.rw(10), vertical: context.rh(5)),
                  decoration: BoxDecoration(
                    // Skipped is on solid red — the visit will not happen —
                    // and an ad hoc visit on solid navy, so both read at a
                    // glance.
                    color: solidTag?.$1 ?? tagColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadiusDirectional.only(
                      topEnd: Radius.circular(radius - 1),
                      bottomStart: Radius.circular(context.rr(12)),
                    ),
                  ),
                  child: Text(
                    status.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: solidTag?.$2 ?? tagColor,
                      fontSize: context.rsp(11),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.rh(2)),
          Row(
            children: [
              Expanded(
                // territory · channel · tier, as on the depot card.
                child: VisitPlanFactsLine(
                  plan: plan,
                  style: secondary.copyWith(fontWeight: FontWeight.w600),
                  orNull: _orNull,
                ),
              ),
              VisitPlanCardAction(
                icon: Icons.map_rounded,
                color: Colors.blue,
                tooltip: mapActionTooltip(plan),
                onTap: openPlanInMaps(plan),
              ),
              if (skipped)
                VisitPlanCardAction(
                  icon: Icons.cancel_rounded,
                  color: colors.warning,
                  tooltip: 'my_visits.plans.status.skipped'.tr,
                  dimWhenInert: false,
                )
              else if (skip != null)
                VisitPlanCardAction(
                  icon: Icons.cancel_rounded,
                  color: scheme.error,
                  tooltip: 'my_visits.plans.action.skip'.tr,
                  onTap: () => skip(plan),
                ),
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: context.rh(12)),
      child: AnimatedCard(
        onTap: tap == null ? null : () => tap(plan),
        color: colors.card,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(radius),
        restShadow: colors.cardShadow,
        enableHoverScale: tap != null,
        pressedScale: tap != null ? AppScale.pressedCard : 1.0,
        child: body,
      ),
    );
  }

  static String _orNull(String? value) {
    final text = value?.trim();
    return (text == null || text.isEmpty)
        ? 'my_visits.plans.field.null_value'.tr
        : text;
  }
}
