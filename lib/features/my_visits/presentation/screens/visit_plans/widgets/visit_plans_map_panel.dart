import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/presentation/screens/visit_plans/widgets/visit_plan_status_badge.dart';

/// Says plainly why the map has no pins, so an empty map does not read as a
/// day with nothing to visit.
class VisitPlansMapNotice extends StatelessWidget {
  const VisitPlansMapNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.all(context.rw(12)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(14)),
        boxShadow: colors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_off_outlined,
              color: colors.info, size: context.rw(20)),
          SizedBox(width: context.rw(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'my_visits.plans.map.pending_title'.tr,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: context.rsp(13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: context.rh(2)),
                Text(
                  'my_visits.plans.map.pending_hint'.tr,
                  style: TextStyle(
                      color: colors.textSecondary, fontSize: context.rsp(12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The day's visits under the map: name, depot code and status.
class VisitPlansMapPanel extends StatelessWidget {
  const VisitPlansMapPanel({super.key, required this.plans});

  final List<VisitPlan> plans;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      // A third of the screen at most: the map stays the subject.
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.34),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(context.rr(18))),
        boxShadow: colors.cardShadow,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(context.rw(16), context.rh(14),
                  context.rw(16), context.rh(6)),
              child: Text(
                'my_visits.plans.visit_count'
                    .trParams({'count': '${plans.length}'}),
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: context.rsp(14),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (plans.isEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                    context.rw(16), 0, context.rw(16), context.rh(16)),
                child: Text('my_visits.plans.empty_day.title'.tr,
                    style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: context.rsp(13))),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.only(bottom: context.rh(8)),
                  itemCount: plans.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: colors.divider),
                  itemBuilder: (context, i) => _Row(plan: plans[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.plan});

  final VisitPlan plan;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      key: ValueKey(plan.id),
      padding: EdgeInsets.symmetric(
          horizontal: context.rw(16), vertical: context.rh(10)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.displayName ?? 'my_visits.plans.unnamed_outlet'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: context.rsp(13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (plan.depotCode != null)
                  Text(plan.depotCode!,
                      style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: context.rsp(12))),
              ],
            ),
          ),
          SizedBox(width: context.rw(8)),
          VisitPlanStatusBadge(plan: plan),
        ],
      ),
    );
  }
}
