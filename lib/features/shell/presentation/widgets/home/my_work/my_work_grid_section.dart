/// Home "My Work" section: header, full-width My Visits tile, then Depots and
/// Quotes & Orders side by side. Tile look lives in my_work_card.dart.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/animations/fade_slide_transition.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_keys.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/today_call_plan_count_cubit.dart';
import 'package:steelforce/features/shell/presentation/navigation/shell_tab_controller.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/my_work/my_work_card.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/my_work/my_work_section_header.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/my_work/today_call_plan_count_scope.dart';
import 'package:steelforce/shared/animations/work_icons.dart';

// Callers import the skeleton from this file; it now lives beside it.
export 'package:steelforce/features/shell/presentation/widgets/home/my_work/my_work_grid_skeleton.dart';

class MyWorkGridSection extends StatelessWidget {
  const MyWorkGridSection({super.key});

  // Style constants (design units).
  static const double _tileHeight = 120;
  static const double _gap = 12;
  static const double _visitsIconSize = 56;

  @override
  Widget build(BuildContext context) {
    return CoachKeys.wrap(
      CoachKeys.myWork,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.pagePadding,
          vertical: context.rh(_gap),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            MyWorkSectionHeader('shell.my_work'.tr, letterSpacing: 1.6),

            // ── Top: My Visits (Full Width) ──────────────────────────────
            SizedBox(
              height: context.rh(_tileHeight),
              width: double.infinity,
              child: FadeSlideIn(
                delay: FadeSlideIn.staggerDelay(1),
                child: CoachKeys.wrap(
                  CoachKeys.myVisits,
                  child: TodayCallPlanCountScope(
                    child: BlocBuilder<TodayCallPlanCountCubit, int?>(
                      builder: (context, count) => MyWorkCard(
                        label: 'shell.my_visits'.tr,
                        icon: Icons.assignment_turned_in_outlined,
                        kind: WorkIconKind.visits,
                        // Brand Guide §07 colours, one per card.
                        accent: AppColors.primary, // Apex Blue
                        tileHeight: context.rr(_visitsIconSize),
                        // Hidden until the first read, so it never flashes a
                        // wrong "0 today".
                        badgeText: count == null
                            ? null
                            : 'shell.badge_today'.trParams({'count': count}),
                        isActive: true,
                        onTap: () =>
                            sl<ShellTabController>().goTo(ShellTab.myVisits),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: context.rh(_gap)),

            // ── Bottom: Depots & Quotes/Orders ─────────────────────────
            SizedBox(
              height: context.rh(_tileHeight),
              child: Row(
                children: [
                  // Left: Depots
                  Expanded(
                    child: FadeSlideIn(
                      delay: FadeSlideIn.staggerDelay(2),
                      child: CoachKeys.wrap(
                        CoachKeys.myDepots,
                        child: MyWorkCard(
                          label: 'shell.my_depots'.tr,
                          icon: Icons.people_alt_outlined,
                          kind: WorkIconKind.depots,
                          accent: AppColors.success, // Sustainable Green
                          isActive: false,
                          onTap: () =>
                              sl<ShellTabController>().goTo(ShellTab.depots),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: context.rw(_gap)),

                  // Right: Quotes & Orders
                  Expanded(
                    child: FadeSlideIn(
                      delay: FadeSlideIn.staggerDelay(3),
                      child: CoachKeys.wrap(
                        CoachKeys.orders,
                        child: MyWorkCard(
                          label: 'shell.my_quotes_orders'.tr,
                          icon: Icons.description_outlined,
                          kind: WorkIconKind.quotesOrders,
                          accent: AppColors.brandBlaze, // Worksite Blaze
                          isActive: false,
                          onTap: () =>
                              sl<ShellTabController>().goTo(ShellTab.orders),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
