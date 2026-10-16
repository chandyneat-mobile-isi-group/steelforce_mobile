import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/resumable_visit_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/resume_workflow_dispatcher.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/ask_how_visit_ended.dart';

/// Visit-flow "Continue Previous Work" card — styled with gold accent framing,
/// dual-bordered icon badge, and corner watermarks.
class ContinueVisitCard extends StatelessWidget {
  const ContinueVisitCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ResumableVisitCubit, ResumableVisitState>(
      builder: (context, state) {
        final route = state.route;
        if (!state.loaded || route == null) return const SizedBox.shrink();
        return _VisitCard(route: route, workflow: state.workflow);
      },
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.route, this.workflow});
  final RoutePlan route;
  final ActiveWorkflow? workflow;

  static const Color _goldBorderColor = Color(0xFFCBA135);

  Future<void> _continue(BuildContext context) async {
    final cubit = context.read<ResumableVisitCubit>();
    await resumeActiveWorkflow(context, route, workflow);
    await cubit.refresh();
  }

  Future<void> _dismiss(BuildContext context) async {
    final cubit = context.read<ResumableVisitCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('sync.dismiss_checkin_title'.tr),
        content:
            Text('sync.dismiss_checkin_body'.trParams({'route': route.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('common.keep'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('common.dismiss'.tr,
                style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.dismiss();
  }

  /// The check-out sheet is the confirmation: the rep says how the visit
  /// ended, or closes it and nothing happens.
  Future<void> _checkOut(BuildContext context) async {
    final cubit = context.read<ResumableVisitCubit>();
    final decision = await askHowVisitEnded(context);
    if (decision != null) await cubit.checkOut(decision.choice);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final total = route.stops.length;
    final done = route.completedStops;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(context.rr(18)),
        border: Border.all(
          color: _goldBorderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12.r,
            offset: Offset(0, context.rh(4)),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.rr(17)),
        child: Stack(
          children: [
            // Top-Left Watermark Circle
            Positioned(
              top: -context.rr(22),
              left: -context.rr(22),
              child: Container(
                width: context.rr(55),
                height: context.rr(55),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.info.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            // Bottom-Right Watermark Circle
            Positioned(
              bottom: -context.rr(22),
              right: -context.rr(22),
              child: Container(
                width: context.rr(55),
                height: context.rr(55),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.info.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(context.rr(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Dual-bordered Icon Avatar Badge
                      Container(
                        padding: EdgeInsets.all(context.rr(8)),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.info.withValues(alpha: 0.12),
                          border: Border.all(
                            color: _goldBorderColor.withValues(alpha: 0.8),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4.r,
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
                              route.name,
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
                        onTap: () => _dismiss(context),
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
                  ),
                  SizedBox(height: context.rh(10)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'sync.checkin_progress'
                            .trParams({'done': done, 'total': total}),
                        style: TextStyle(
                          fontSize: context.rsp(12),
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(
                        '${((total > 0 ? done / total : 0) * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: context.rsp(12),
                          fontWeight: FontWeight.w700,
                          color: _goldBorderColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.rh(6)),
                  if (total > 0)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(context.rr(4)),
                      child: LinearProgressIndicator(
                        value: done / total,
                        minHeight: context.rh(6),
                        backgroundColor: colors.border.withValues(alpha: 0.5),
                        valueColor:
                            const AlwaysStoppedAnimation(_goldBorderColor),
                      ),
                    ),
                  SizedBox(height: context.rh(14)),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _checkOut(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.info,
                            side: BorderSide(
                                color: colors.info.withValues(alpha: 0.5)),
                            padding:
                                EdgeInsets.symmetric(vertical: context.rh(10)),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(context.rr(10)),
                            ),
                          ),
                          child: Text(
                            'sync.check_out'.tr,
                            style: TextStyle(
                              fontSize: context.rsp(12.5),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: context.rw(10)),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _continue(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.info,
                            padding:
                                EdgeInsets.symmetric(vertical: context.rh(10)),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(context.rr(10)),
                            ),
                          ),
                          icon: Icon(Icons.play_arrow_rounded,
                              size: context.rsp(18)),
                          label: Text(
                            'common.continue'.tr,
                            style: TextStyle(
                              fontSize: context.rsp(12.5),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
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
