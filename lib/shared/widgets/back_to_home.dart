import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/shell/presentation/bloc/home_cubit.dart';
import 'package:steelforce/routes/app_routes.dart';

class BackToHomeButton extends StatelessWidget {
  const BackToHomeButton({
    super.key,
    this.label = 'Back to home',
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
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
            Text(
              label,
              style: TextStyle(
                color: colors.accentPurple,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
