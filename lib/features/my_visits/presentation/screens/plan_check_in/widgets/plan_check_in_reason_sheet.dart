import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_check_in.dart';
import 'package:steelforce/features/my_visits/presentation/screens/plan_check_in/widgets/plan_check_in_reason_tile.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';

/// Asks why the rep is checking in away from the depot: one preset reason,
/// nothing to type. Null when the rep backs out. [distanceMeters] is how far
/// the fix is from the depot, when known.
Future<PlanCheckInReason?> showPlanCheckInReasonSheet(
  BuildContext context, {
  double? distanceMeters,
  required double radiusMeters,
}) =>
    showAppBottomSheet<PlanCheckInReason>(
      context: context,
      builder: (_) => _ReasonSheet(
          distanceMeters: distanceMeters, radiusMeters: radiusMeters),
    );

class _ReasonSheet extends StatefulWidget {
  const _ReasonSheet(
      {required this.distanceMeters, required this.radiusMeters});

  final double? distanceMeters;
  final double radiusMeters;

  @override
  State<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<_ReasonSheet> {
  PlanCheckInReason? _picked;

  static IconData _icon(PlanCheckInReason r) => switch (r) {
        PlanCheckInReason.traffic => Icons.traffic_rounded,
        PlanCheckInReason.customerRequest => Icons.support_agent_rounded,
        PlanCheckInReason.depotMoved => Icons.wrong_location_outlined,
        PlanCheckInReason.gpsAccuracy => Icons.gps_not_fixed_rounded,
        PlanCheckInReason.roadBlocked => Icons.do_not_disturb_on_outlined,
        PlanCheckInReason.other => Icons.more_horiz_rounded,
      };

  static String _distance(double m) =>
      m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    String t(String key) => 'my_visits.plans.check_in.reason_sheet.$key'.tr;
    final distance = widget.distanceMeters;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          context.rw(20), context.rh(4), context.rw(20), context.rh(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              padding: EdgeInsets.all(context.rr(14)),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.location_off_rounded,
                  size: context.rr(30), color: colors.warning),
            ),
          ),
          SizedBox(height: context.rh(12)),
          Text(
            distance == null
                ? t('title_unknown')
                : t('title').trParams({'distance': _distance(distance)}),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: context.rsp(17),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: context.rh(6)),
          Text(
            t('body').trParams({'radius': '${widget.radiusMeters.round()}'}),
            textAlign: TextAlign.center,
            style: TextStyle(
                color: colors.textSecondary, fontSize: context.rsp(13)),
          ),
          SizedBox(height: context.rh(16)),
          for (final reason in PlanCheckInReason.selectable) ...[
            PlanCheckInReasonTile(
              icon: _icon(reason),
              label: 'my_visits.plans.check_in.reason.${reason.name}'.tr,
              selected: _picked == reason,
              onTap: () => setState(() => _picked = reason),
            ),
            SizedBox(height: context.rh(8)),
          ],
          SizedBox(height: context.rh(8)),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.fromHeight(context.rh(48)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('common.cancel'.tr),
                ),
              ),
              SizedBox(width: context.rw(10)),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _picked == null
                      ? null
                      : () => Navigator.of(context).pop(_picked),
                  icon: const Icon(Icons.login_rounded),
                  label: Text(t('confirm')),
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(context.rh(48)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
