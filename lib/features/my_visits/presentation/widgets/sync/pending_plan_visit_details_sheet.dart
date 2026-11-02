import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/pending_plan_visit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/pending_plan_visits_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/sync/plan_visit_actions.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';
import 'package:steelforce/shared/widgets/brand_wallpaper_background.dart';
import 'package:steelforce/shared/widgets/info_section_card.dart';
import 'package:steelforce/shared/widgets/photo_gallery.dart';

/// Opens what one planned visit still holds on this device, over the Sync
/// Center. [context] must be under the [PendingPlanVisitsCubit].
Future<void> showPendingPlanVisitDetailsSheet(
    BuildContext context, String planId) {
  final cubit = context.read<PendingPlanVisitsCubit>();
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: PendingPlanVisitDetailsSheet(planId: planId),
    ),
  );
}

/// Each waiting step with when it was saved, the refusal if there is one,
/// and the photos themselves. Reads the visit from the cubit, so it stays
/// current while a sync runs, and closes once nothing is left waiting.
class PendingPlanVisitDetailsSheet extends StatefulWidget {
  const PendingPlanVisitDetailsSheet({super.key, required this.planId});
  final String planId;

  @override
  State<PendingPlanVisitDetailsSheet> createState() => _SheetState();
}

class _SheetState extends State<PendingPlanVisitDetailsSheet> {
  bool _closing = false;

  PendingPlanVisit? _visit(PendingPlanVisitsState state) =>
      state.visits.where((v) => v.planId == widget.planId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PendingPlanVisitsCubit, PendingPlanVisitsState>(
      listener: (_, state) {
        if (_closing || _visit(state) != null) return;
        _closing = true;
        Navigator.of(context).maybePop();
      },
      builder: (context, state) {
        final visit = _visit(state);
        if (visit == null) return const SizedBox.shrink();
        return Stack(
          children: [
            const Positioned.fill(
              child:
                  BrandWallpaperBackground(style: BrandWallpaperStyle.subtle),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(context.rw(16), context.rh(4),
                  context.rw(16), context.rh(16)),
              child: _Details(
                  visit: visit, busy: state.busy.contains(visit.planId)),
            ),
          ],
        );
      },
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.visit, required this.busy});
  final PendingPlanVisit visit;
  final bool busy;

  static String _label(PendingPlanStepKind kind) => switch (kind) {
        PendingPlanStepKind.checkIn => 'sync_center.plan.step.check_in',
        PendingPlanStepKind.inventory => 'sync_center.plan.step.inventory',
        PendingPlanStepKind.checkOut => 'sync_center.plan.step.check_out',
      };

  static IconData _icon(PendingPlanStepKind kind) => switch (kind) {
        PendingPlanStepKind.checkIn => Icons.login_rounded,
        PendingPlanStepKind.inventory => Icons.photo_camera_outlined,
        PendingPlanStepKind.checkOut => Icons.logout_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final time = DateFormat('d MMM, HH:mm', context.languageCode);
    final message = visit.messageKey;
    final photos = [
      for (final step in visit.steps)
        for (final (i, path) in step.photoPaths.indexed)
          GalleryPhoto(
            path: path,
            takenAt: step.savedAt.toLocal(),
            label: '${_label(step.kind).tr} ${i + 1}',
          ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          visit.depotName ?? 'sync_center.visit.unknown_shop'.tr,
          style: TextStyle(
            fontSize: context.rsp(17),
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        if (visit.needsAttention && message != null) ...[
          SizedBox(height: context.rh(12)),
          InfoSectionCard(
            icon: Icons.error_outline_rounded,
            title: 'sync_center.plan.needs_attention'.tr,
            children: [
              Text(message.tr,
                  style: TextStyle(
                      color: scheme.error, fontSize: context.rsp(12.5))),
            ],
          ),
        ],
        SizedBox(height: context.rh(12)),
        InfoSectionCard(
          icon: Icons.schedule_rounded,
          title: 'sync_center.visit.waiting'.tr,
          count: visit.steps.length,
          children: [
            for (final step in visit.steps)
              Padding(
                padding: EdgeInsets.symmetric(vertical: context.rh(4)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_icon(step.kind),
                        size: context.rr(16), color: colors.textSecondary),
                    SizedBox(width: context.rw(8)),
                    Expanded(
                      child: Text(
                        step.photoPaths.isEmpty
                            ? _label(step.kind).tr
                            : '${_label(step.kind).tr} · '
                                '${step.photoPaths.length}',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: context.rsp(12.5),
                            color: scheme.onSurface),
                      ),
                    ),
                    Text(
                      'sync_center.plan.saved_at'.trParams(
                          {'time': time.format(step.savedAt.toLocal())}),
                      style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: context.rsp(11.5)),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (photos.isNotEmpty) ...[
          SizedBox(height: context.rh(12)),
          InfoSectionCard(
            icon: Icons.photo_library_outlined,
            title: 'sync_center.visit.kind.photos'.tr,
            count: photos.length,
            children: [PhotoGallery(photos: photos)],
          ),
        ],
        SizedBox(height: context.rh(16)),
        PlanVisitActions(visit: visit, busy: busy),
      ],
    );
  }
}
