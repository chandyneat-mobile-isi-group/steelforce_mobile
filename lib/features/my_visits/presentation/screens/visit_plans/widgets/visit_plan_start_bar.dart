import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/open_visit_plan.dart';
import 'package:steelforce/features/my_visits/presentation/screens/visit_plans/widgets/visit_plan_card_actions.dart';

/// Start Visit at the bottom of a depot's details, opened from a plan card.
///
/// Remembers a check-in made from here: [plan] was loaded before it, so a
/// second tap would otherwise ask for the check-in again. After one, the
/// button reads "Continue visit" and goes straight to the visit's next step.
class VisitPlanStartBar extends StatefulWidget {
  const VisitPlanStartBar({
    super.key,
    required this.plan,
    required this.onCheckedIn,
  });

  final VisitPlan plan;

  /// Reloads the plan lists behind the details screen.
  final VoidCallback onCheckedIn;

  @override
  State<VisitPlanStartBar> createState() => _VisitPlanStartBarState();
}

class _VisitPlanStartBarState extends State<VisitPlanStartBar> {
  bool _checkedIn = false;
  bool _busy = false;

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    await startVisitPlan(
      context,
      widget.plan,
      checkedIn: _checkedIn,
      onCheckedIn: () {
        widget.onCheckedIn();
        if (mounted) setState(() => _checkedIn = true);
      },
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.canvas,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(context.pagePadding, context.rh(10),
              context.pagePadding, context.rh(10)),
          child: VisitPlanStartButton(
            plan: widget.plan,
            checkedIn: _checkedIn,
            // One flow at a time: a double tap must not open two check-ins.
            onPressed: _start,
          ),
        ),
      ),
    );
  }
}
