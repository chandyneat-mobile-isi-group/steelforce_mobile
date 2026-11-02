import 'package:flutter/material.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_keys.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/presentation/screens/visit_plans/widgets/visit_plan_card.dart';

/// Visit cards, built lazily in the server's order.
class VisitPlansDayList extends StatelessWidget {
  const VisitPlansDayList({
    super.key,
    required this.plans,
    this.onOpenPlan,
    this.onSkipPlan,
  });

  /// Non-empty; the server's order is kept.
  final List<VisitPlan> plans;
  final ValueChanged<VisitPlan>? onOpenPlan;

  /// Offered only on plans the server would accept a skip for. The caller
  /// passes it for today's list alone: skipping works only on the plan's date.
  final ValueChanged<VisitPlan>? onSkipPlan;

  @override
  Widget build(BuildContext context) {
    final firstPlanId = plans.first.id;

    return SliverList.builder(
      itemCount: plans.length,
      itemBuilder: (context, index) => _card(
        plans[index],
        isFirst: plans[index].id == firstPlanId,
      ),
    );
  }

  Widget _card(VisitPlan plan, {required bool isFirst}) {
    final card = VisitPlanCard(
      // The plan id, never the depot code: two visits can share a depot.
      key: ValueKey(plan.id),
      plan: plan,
      onTap: onOpenPlan,
      onSkip: plan.canSkip ? onSkipPlan : null,
    );
    // The visit lesson in the app coach points at the first card.
    return isFirst
        ? CoachKeys.wrap(CoachKeys.visitFirstStop, child: card)
        : card;
  }
}
