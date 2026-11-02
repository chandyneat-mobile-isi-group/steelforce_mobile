import 'package:flutter/material.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/pending_plan_visits_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/pending_visit_sync_cubit.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_registration_queue_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/pending_sync_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/pending_sync_state.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/pending_sync_sheet.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// A steel-framed "Pending Sync" pill badge with dual-ring avatar styling.
class PendingSyncBadge extends StatelessWidget {
  const PendingSyncBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PendingSyncCubit, PendingSyncState>(
      builder: (context, state) {
        final depots = context.watch<DepotRegistrationQueueCubit>().state;
        // Counted as the Sync Center lists them: a card per visit.
        final visits = context.watch<PendingVisitSyncCubit>().state.pending;
        final plans = context.watch<PendingPlanVisitsCubit>().state.visits;
        final outstanding = state.counts.outstanding +
            depots.outstanding +
            visits.stops.length +
            (visits.otherRecords > 0 ? 1 : 0) +
            plans.length;
        if (outstanding == 0) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        final hasProblems = state.counts.failed > 0 ||
            state.counts.conflict > 0 ||
            depots.needingRep > 0 ||
            plans.any((p) => p.needsAttention);
        final accent = hasProblems ? scheme.error : scheme.primary;

        return InkWell(
          onTap: () => showPendingSyncSheet(context),
          borderRadius: BorderRadius.circular(context.rr(24)),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: context.rw(10), vertical: context.rh(6)),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(context.rr(24)),
              border: Border.all(color: AppColors.steelRim, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8.r,
                  offset: Offset(0, context.rh(3)),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dual-Bordered Icon Container
                Container(
                  padding: EdgeInsets.all(context.rr(5)),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.12),
                    border: Border.all(
                      color: AppColors.steelRim.withValues(alpha: 0.8),
                      width: 1,
                    ),
                  ),
                  child: state.isSyncing
                      ? SizedBox(
                          width: context.rr(14),
                          height: context.rr(14),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: accent),
                        )
                      : Icon(Icons.sync_rounded,
                          size: context.rsp(14), color: accent),
                ),
                SizedBox(width: context.rw(8)),
                Text(
                  'sync.pending_badge'.trParams({'count': outstanding}),
                  style: TextStyle(
                    color: accent,
                    fontSize: context.rsp(12.5),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (hasProblems) ...[
                  SizedBox(width: context.rw(6)),
                  Icon(Icons.error_rounded,
                      size: context.rsp(15), color: scheme.error),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
