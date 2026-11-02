import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/shell/presentation/bloc/work_mode_cubit.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/brand_chevron_mark.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/header_reveal.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/pending_sync_badge.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/work_mode/offline_sync_bubble.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/work_mode_button.dart';

/// The greeting at the top of Home: the ISI chevron, "Good morning" and
/// the rep's name on the hero photo, with the work-mode switch and the
/// pending-sync badge on the right.
class HomeWelcomeHeader extends StatelessWidget {
  const HomeWelcomeHeader({super.key, required this.fullName});

  /// The signed-in rep, not a fixture. This once read 'Sokha Novel' for every
  /// user — the same class of bug as the profile screen's "Alex Morgan".
  final String fullName;

  // cspell:ignore Sokha

  static String _greetingKey() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'common.good_morning';
    if (hour < 17) return 'common.good_afternoon';
    return 'common.good_evening';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          context.pagePadding, context.rh(4), context.pagePadding, 0),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                // The ISI chevron, as before "MY WORK" below.
                BrandChevronMark(height: context.rh(12)),
                SizedBox(width: 10.w),
                Expanded(child: _greeting(context)),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          // The mode first: it is always shown. Online, the badge beside it
          // appears when something is waiting to send. Offline, the badge
          // gives way to the Syncing Data popup pinned under the pill.
          //
          // One tree for both modes, so the mode button keeps its place (and
          // its own transition) while the badge and the popup slide in and
          // out around it.
          BlocSelector<WorkModeCubit, WorkModeState, bool>(
            bloc: sl<WorkModeCubit>(),
            selector: (state) => state.isOffline,
            builder: (context, offline) {
              final motion =
                  MediaQuery.maybeOf(context)?.disableAnimations ?? false
                      ? Duration.zero
                      : AppDurations.medium;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const WorkModeButton(),
                      HeaderReveal(
                        duration: motion,
                        axis: Axis.horizontal,
                        child: offline
                            ? null
                            : Padding(
                                padding: EdgeInsets.only(left: 6.w),
                                child: const PendingSyncBadge(),
                              ),
                      ),
                    ],
                  ),
                  HeaderReveal(
                    duration: motion,
                    axis: Axis.vertical,
                    child: offline ? const OfflineSyncBubble() : null,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _greeting(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _greetingKey().tr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: context.rsp(13),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: context.rsp(19),
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
