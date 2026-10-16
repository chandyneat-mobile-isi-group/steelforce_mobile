import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:steelforce/core/config/feature_flags.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/platform/device/device_insets.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_keys.dart';
import 'package:steelforce/features/shell/presentation/screens/kpi_coming_soon_screen.dart';
import 'package:steelforce/features/shell/presentation/screens/kpi_screen.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/home_welcome_section.dart';
import 'package:steelforce/features/shell/presentation/widgets/monthly_target_widget.dart';
import 'package:steelforce/features/shell/presentation/widgets/my_work_grid_section.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/connectivity_banner.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_visit_card.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working_card.dart';

/// The signed-in home tab: greeting, monthly target, connectivity and resume
/// cards, and the "My Work" grid, scrolling under the shell's app bar.
class AuthenticatedHomeTab extends StatelessWidget {
  const AuthenticatedHomeTab({super.key, required this.fullName});

  final String fullName;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: SizedBox(height: context.rh(70)),
          ),
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
                HomeWelcomeSection(fullName: fullName),
                SizedBox(height: context.rh(16)),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: context.pagePadding),
                  child: CoachKeys.wrap(
                    CoachKeys.monthlyTarget,
                    child: MonthlyTargetCard(
                      targetAmount: 1000000,
                      achievedAmount: 750000,
                      monthName: 'calendar.months.m${DateTime.now().month}'.tr,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LocalizedBuilder(
                              builder: (_) => FeatureFlags.kpi
                                  ? const KpiScreen()
                                  : const KpiComingSoonScreen(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: context.rh(16)),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: context.pagePadding),
                  child: const ConnectivityBanner(),
                ),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: context.pagePadding),
                  child: const ContinueVisitCard(),
                ),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: context.pagePadding),
                  child: const ContinueWorkingCard(),
                ),
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
