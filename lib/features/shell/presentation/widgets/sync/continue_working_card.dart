import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/resumable_visit_cubit.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/continue_work_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/pending_sync_cubit.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/quotation_detail_screen.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_work_resolver.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/presentation/l10n/quotation_sync_error_l10n.dart';

// Split from one 831-line file: the card itself lives here, the shared frame,
// buttons and actions in `continue_working_controls.dart`, and the
// all-drafts sheet in `continue_working_sheet.dart`. Parts, so the private
// widgets stay private to this card.
part 'continue_working_controls.dart';
part 'continue_working_sheet.dart';

/// Floating card featuring gold accent framing, dual-bordered icon badge,
/// subtle corner watermarks, and tactile 3D action controls.
class ContinueWorkingCard extends StatelessWidget {
  const ContinueWorkingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final activeShopId =
        context.watch<ResumableVisitCubit>().state.activeShopId;
    return BlocBuilder<ContinueWorkCubit, ContinueWorkState>(
      builder: (context, state) {
        if (!state.loaded) {
          return const _ContinueWorkingCardSkeleton();
        }

        final drafts = standaloneDrafts(state.drafts, activeShopId);
        final total = drafts.length + state.remoteDrafts.length;
        if (total == 0) {
          return const SizedBox.shrink();
        }
        // A backend-only draft has no local copy to render as a full card, so
        // anything other than exactly one local draft opens the sheet.
        if (total > 1 || drafts.isEmpty) {
          return _MultiDraftCard(count: total);
        }
        final draft = drafts.first;
        return _DraftCard(
          draft: draft,
          returned: state.isReturned(draft.id),
          returnReason: state.returnReasons[draft.id],
        );
      },
    );
  }
}

class _ContinueWorkingCardSkeleton extends StatelessWidget {
  const _ContinueWorkingCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final skeletonColor = scheme.onSurface.withValues(alpha: 0.12);

    return _CardShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: context.rr(20),
                height: context.rr(20),
                decoration: BoxDecoration(
                  color: skeletonColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: context.rw(8)),
              Expanded(
                child: Container(
                  height: context.rh(14),
                  decoration: BoxDecoration(
                    color: skeletonColor,
                    borderRadius: BorderRadius.circular(context.rr(4)),
                  ),
                ),
              ),
              SizedBox(width: context.rw(32)),
              Container(
                width: context.rr(20),
                height: context.rr(20),
                decoration: BoxDecoration(
                  color: skeletonColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          SizedBox(height: context.rh(12)),
          Container(
            width: context.rw(120),
            height: context.rh(12),
            decoration: BoxDecoration(
              color: skeletonColor,
              borderRadius: BorderRadius.circular(context.rr(4)),
            ),
          ),
          SizedBox(height: context.rh(6)),
          Container(
            width: context.rw(190),
            height: context.rh(12),
            decoration: BoxDecoration(
              color: skeletonColor,
              borderRadius: BorderRadius.circular(context.rr(4)),
            ),
          ),
          SizedBox(height: context.rh(16)),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: context.rh(40),
                  decoration: BoxDecoration(
                    color: skeletonColor,
                    borderRadius: BorderRadius.circular(context.rr(10)),
                  ),
                ),
              ),
              SizedBox(width: context.rw(10)),
              Expanded(
                child: Container(
                  height: context.rh(40),
                  decoration: BoxDecoration(
                    color: skeletonColor,
                    borderRadius: BorderRadius.circular(context.rr(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.draft,
    this.returned = false,
    this.returnReason,
  });
  final Quotation draft;

  /// An administrator sent this back from review.
  final bool returned;
  final String? returnReason;

  static const Color _goldBorderColor = Color(0xFFCBA135);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return _CardShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Dual-Bordered Icon Avatar Badge
              Container(
                padding: EdgeInsets.all(context.rr(6)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.1),
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
                  Icons.history_rounded,
                  size: context.rsp(18),
                  color: scheme.primary,
                ),
              ),
              SizedBox(width: context.rw(10)),
              Expanded(
                child: Text(
                  'sync.continue_previous'.tr,
                  style: TextStyle(
                    fontSize: context.rsp(14),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              _DiscardButton(draft: draft),
            ],
          ),
          SizedBox(height: context.rh(10)),
          // Traditional framed sub-container
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: context.rw(10), vertical: context.rh(8)),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(context.rr(8)),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'sync.quotation_n'.trParams({'id': draft.id}),
                  style: TextStyle(
                    fontSize: context.rsp(13),
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
                SizedBox(height: context.rh(3)),
                Text(
                  _subtitle(draft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.rsp(12),
                    color: colors.textSecondary,
                  ),
                ),
                if (returned) ...[
                  SizedBox(height: context.rh(6)),
                  _ReturnedNote(reason: returnReason),
                ],
              ],
            ),
          ),
          SizedBox(height: context.rh(14)),
          Row(
            children: [
              Expanded(
                child: _ThreeDOutlinedButton(
                  label: 'common.submit'.tr,
                  onPressed: () => _submit(context, draft),
                ),
              ),
              SizedBox(width: context.rw(10)),
              Expanded(
                child: _ThreeDFilledButton(
                  label: 'common.continue'.tr,
                  onPressed: () => _continue(context, draft),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MultiDraftCard extends StatelessWidget {
  const _MultiDraftCard({required this.count});
  final int count;

  static const Color _goldBorderColor = Color(0xFFCBA135);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return _CardShell(
      child: InkWell(
        onTap: () => _openDraftsSheet(context),
        borderRadius: BorderRadius.circular(context.rr(12)),
        child: Row(
          children: [
            // Dual-Bordered Icon Avatar Badge
            Container(
              padding: EdgeInsets.all(context.rr(8)),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.1),
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
                Icons.history_rounded,
                size: context.rsp(20),
                color: scheme.primary,
              ),
            ),
            SizedBox(width: context.rw(12)),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'sync.continue_working'.trParams({'count': count}),
                    style: TextStyle(
                      fontSize: context.rsp(14),
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  SizedBox(height: context.rh(2)),
                  Text(
                    'sync.unfinished_drafts'.tr,
                    style: TextStyle(
                      fontSize: context.rsp(12),
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: context.rsp(22),
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
