import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/press_scale.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:url_launcher/url_launcher.dart';

/// A round icon action on a visit card, matching the stop card's.
///
/// `PressScale` rather than an `InkWell`: it sits inside the card's own tap
/// target, and the scale shows which of the two the finger hit.
class VisitPlanCardAction extends StatelessWidget {
  const VisitPlanCardAction({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onTap,
    this.dimWhenInert = true,
  });

  final IconData icon;
  final Color color;
  final String tooltip;

  /// Null draws the action dimmed and inert.
  final VoidCallback? onTap;

  /// False keeps an inert action in full [color]: a state shown, not an
  /// action offered — the skip mark on a visit already skipped.
  final bool dimWhenInert;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final tint =
        enabled || !dimWhenInert ? color : color.withValues(alpha: 0.35);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: PressScale(
          onTap: onTap,
          enabled: enabled,
          child: Container(
            // ≥48dp touch target around the 34dp disc.
            padding: EdgeInsets.all(context.rr(7)),
            child: Container(
              padding: EdgeInsets.all(context.rr(6)),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: enabled ? 0.12 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: context.rr(22), color: tint),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the visit's location in the maps app. Null when the plan has none,
/// so the caller can draw the button disabled instead of failing on tap.
VoidCallback? openPlanInMaps(VisitPlan plan) {
  final lat = plan.latitude;
  final lng = plan.longitude;
  if (lat == null || lng == null) return null;
  return () async {
    final url =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (kDebugMode) debugPrint('Could not open maps: ${e.runtimeType}');
    }
  };
}

/// The tooltip for the map action, which says why it is off when it is.
String mapActionTooltip(VisitPlan plan) => plan.hasLocation
    ? 'my_visits.plans.action.open_map'.tr
    : 'my_visits.plans.action.no_location'.tr;

/// The Start Visit button of [VisitPlanStartBar], under a plan's depot
/// details. A visit already checked in reads "Continue visit".
class VisitPlanStartButton extends StatelessWidget {
  const VisitPlanStartButton({
    super.key,
    required this.plan,
    required this.onPressed,
    this.checkedIn = false,
  });

  final VisitPlan plan;
  final VoidCallback onPressed;

  /// Checked in since [plan] was loaded, so it reads "Continue visit".
  final bool checkedIn;

  @override
  Widget build(BuildContext context) {
    final resume = checkedIn || plan.status == VisitPlanStatus.checkedIn;
    return SizedBox(
      width: double.infinity,
      height: context.rh(44),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(
            resume ? Icons.arrow_forward_rounded : Icons.play_arrow_rounded,
            size: context.rr(20)),
        label: Text(
          (resume
                  ? 'my_visits.plans.action.continue_visit'
                  : 'my_visits.plans.action.start_visit')
              .tr,
          style: TextStyle(
              fontSize: context.rsp(13.5), fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.rr(12))),
        ),
      ),
    );
  }
}
