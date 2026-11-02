import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/resumable_visit_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/continue_work_cubit.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_work_resolver.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_working_card_skeleton.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_working_draft_card.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_working_multi_draft_card.dart';

// Split from one 831-line file into the `continue_working/` folder: this file
// only picks which card to show. The frame lives in
// `continue_working_card_shell.dart`, the buttons in
// `continue_working_buttons.dart`, the draft actions in
// `continue_working_actions.dart`, and the all-drafts sheet in
// `continue_working_drafts_sheet.dart`.

/// Floating card featuring steel accent framing, dual-bordered icon badge,
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
          return const ContinueWorkingCardSkeleton();
        }

        final drafts = standaloneDrafts(state.drafts, activeShopId);
        final total = drafts.length + state.remoteDrafts.length;
        if (total == 0) {
          return const SizedBox.shrink();
        }
        // A backend-only draft has no local copy to render as a full card, so
        // anything other than exactly one local draft opens the sheet.
        if (total > 1 || drafts.isEmpty) {
          return ContinueWorkingMultiDraftCard(count: total);
        }
        final draft = drafts.first;
        return ContinueWorkingDraftCard(
          draft: draft,
          returned: state.isReturned(draft.id),
          returnReason: state.returnReasons[draft.id],
        );
      },
    );
  }
}
