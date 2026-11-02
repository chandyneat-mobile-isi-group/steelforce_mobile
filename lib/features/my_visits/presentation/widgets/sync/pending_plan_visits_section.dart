import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/pending_plan_visit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/pending_plan_visits_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/sync/pending_plan_visit_details_sheet.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/sync/plan_visit_actions.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/sync/plan_sync_parts.dart';
import 'package:steelforce/routes/app_routes.dart';

/// Planned visits worked on this device — check-in, inventory photos,
/// check-out — that have not reached the server, for the Sync Center.
///
/// They go out on their own, and with the Center's **Sync Now**. A visit
/// the server refused offers **Send again**; any visit can be discarded.
/// Renders nothing when there is nothing waiting.
class PendingPlanVisitsSection extends StatelessWidget {
  const PendingPlanVisitsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PendingPlanVisitsCubit, PendingPlanVisitsState>(
      listenWhen: (a, b) => b.messageKey != null,
      listener: (_, state) => rootMessengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text(state.messageKey!.tr))),
      builder: (context, state) {
        if (state.visits.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'sync_center.plan.section_title'.tr,
              style: TextStyle(
                fontSize: context.rsp(13),
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: context.rh(8)),
            for (final visit in state.visits) ...[
              _PlanVisitTile(
                visit: visit,
                busy: state.busy.contains(visit.planId),
              ),
              SizedBox(height: context.rh(10)),
            ],
          ],
        );
      },
    );
  }
}

class _PlanVisitTile extends StatelessWidget {
  const _PlanVisitTile({required this.visit, required this.busy});
  final PendingPlanVisit visit;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final name = visit.depotName ?? 'sync_center.visit.unknown_shop'.tr;
    final status = visit.needsAttention ? scheme.error : colors.textSecondary;
    final message = visit.messageKey;

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: visit.needsAttention ? scheme.error : colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(context.rr(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              label: name,
              hint: 'common.view_details'.tr,
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () =>
                    showPendingPlanVisitDetailsSheet(context, visit.planId),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.event_available_outlined,
                              size: context.rr(16),
                              color: colors.textSecondary),
                          SizedBox(width: context.rw(6)),
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: context.rsp(13.5),
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          PlanSyncChip(
                            label: visit.needsAttention
                                ? 'sync_center.plan.needs_attention'.tr
                                : 'sync_center.visit.waiting'.tr,
                            color: status,
                          ),
                          SizedBox(width: context.rw(2)),
                          Icon(Icons.chevron_right_rounded,
                              size: context.rr(18),
                              color: colors.textSecondary),
                        ],
                      ),
                      if (visit.checkIn)
                        PlanSyncLine(Icons.login_rounded,
                            'sync_center.plan.check_in'.tr),
                      if (visit.photos > 0)
                        PlanSyncLine(
                          Icons.photo_camera_outlined,
                          'sync_center.plan.photos'
                              .trParams({'count': visit.photos}),
                        ),
                      if (visit.checkOut)
                        PlanSyncLine(Icons.logout_rounded,
                            'sync_center.plan.check_out'.tr),
                      if (visit.checkIn && visit.checkOut)
                        PlanSyncLine(Icons.format_list_numbered_rounded,
                            'sync_center.visit.after_check_in'.tr),
                      if (visit.needsAttention && message != null)
                        PlanSyncLine(Icons.error_outline_rounded, message.tr,
                            color: scheme.error),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: context.rh(8)),
            PlanVisitActions(visit: visit, busy: busy),
          ],
        ),
      ),
    );
  }
}
