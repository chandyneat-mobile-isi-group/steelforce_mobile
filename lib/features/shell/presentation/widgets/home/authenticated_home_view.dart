import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:steelforce/core/config/app_config.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/platform/device/device_insets.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_keys.dart';
import 'package:steelforce/features/shell/presentation/screens/kpi_screen.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/home_welcome_header.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/monthly_target/monthly_target_card.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/my_work/my_work_grid_section.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/connectivity_banner.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_plan_visit_card.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_visit_card.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_working_card.dart';
import 'package:steelforce/shared/widgets/coming_soon.dart';

/// Home for a signed-in rep: the greeting, the monthly target, the connection
/// and continue-working cards, then the My Work grid.
class AuthenticatedHomeView extends StatelessWidget {
  const AuthenticatedHomeView({super.key, required this.fullName});

  /// The signed-in rep's name, for the greeting.
  final String fullName;

  void _openKpi(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocalizedBuilder(
          builder: (_) => AppConfig.kpiComingSoon
              ? ComingSoonScreen(appBarTitle: 'kpi.title'.tr)
              : const KpiScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget padded(Widget child) => Padding(
          padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
          child: child,
        );

    return SizedBox.expand(
      child: Column(
        children: [
          // Room for the app bar, which floats over the tab.
          SafeArea(bottom: false, child: SizedBox(height: context.rh(70))),
          Expanded(
            child: ListView(
              key: const ValueKey('authenticated_home_scroll_root'),
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                0,
                8.h,
                0,
                context.deviceInsets.scrollBottomInset(extra: 16.h),
              ),
              children: [
                HomeWelcomeHeader(fullName: fullName),
                // 16 + 20: room under the header, so the Offline bubble
                // never crowds the card.
                SizedBox(height: context.rh(36)),
                padded(
                  CoachKeys.wrap(
                    CoachKeys.monthlyTarget,
                    child: MonthlyTargetCard(
                      targetAmount: 1000000,
                      achievedAmount: 750000,
                      monthName: 'calendar.months.m${DateTime.now().month}'.tr,
                      onTap: () => _openKpi(context),
                    ),
                  ),
                ),
                SizedBox(height: context.rh(16)),
                padded(const ConnectivityBanner()),
                padded(const ContinueVisitCard()),
                padded(const ContinuePlanVisitCard()),
                padded(const ContinueWorkingCard()),
                SizedBox(height: 8.h),
                const MyWorkGridSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
