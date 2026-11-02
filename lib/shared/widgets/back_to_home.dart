import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/shell/presentation/navigation/shell_tab_controller.dart';
import 'package:steelforce/routes/app_routes.dart';

class BackToHomeButton extends StatelessWidget {
  const BackToHomeButton({
    super.key,
    this.label,
    this.onTap,
  });

  /// Overrides the default, translated "Back to Home" label.
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = label ?? 'common.back_to_home'.tr;

    // It usually sits in an app bar's actions, which do not bound its width:
    // Khmer at a large text scale would push it off screen. Capped, and the
    // full label stays available to the tooltip and to screen readers.
    return Tooltip(
      message: text,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: text,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap ??
              () {
                // 1. Force the tab controller to reset to Home Tab (index 0)
                try {
                  sl<ShellTabController>().goTo(0);
                } catch (_) {}

                // 2. Clear stack and go to MainShell
                navigatorKey.currentState?.pushNamedAndRemoveUntil(
                  Static.main,
                  (route) => false,
                );
              },
          borderRadius: BorderRadius.circular(20.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: colors.accentPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: colors.accentPurple.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.home_rounded,
                  color: colors.accentPurple,
                  size: 16.sp,
                ),
                SizedBox(width: 4.w),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width / 3,
                  ),
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.accentPurple,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
