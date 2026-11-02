import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Header row of the "Continue visit" card: pin badge, title, route name, and
/// the dismiss "x".
class ContinueVisitHeader extends StatelessWidget {
  const ContinueVisitHeader({
    super.key,
    required this.routeName,
    required this.onDismiss,
  });
  final String routeName;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        // Dual-bordered Icon Avatar Badge
        Container(
          padding: EdgeInsets.all(context.rr(8)),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.info.withValues(alpha: 0.12),
            border: Border.all(
              color: AppColors.steelRim.withValues(alpha: 0.8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: context.rr(4),
                offset: Offset(0, context.rh(2)),
              ),
            ],
          ),
          child: Icon(
            Icons.pin_drop_rounded,
            size: context.rsp(18),
            color: colors.info,
          ),
        ),
        SizedBox(width: context.rw(10)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'sync.continue_previous'.tr,
                style: TextStyle(
                  fontSize: context.rsp(13.5),
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              SizedBox(height: context.rh(2)),
              Text(
                routeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: context.rsp(12),
                  fontWeight: FontWeight.w600,
                  color: colors.info,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: onDismiss,
          borderRadius: BorderRadius.circular(context.rr(20)),
          child: Padding(
            padding: EdgeInsets.all(context.rr(4)),
            child: Icon(
              Icons.close_rounded,
              size: context.rsp(18),
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
