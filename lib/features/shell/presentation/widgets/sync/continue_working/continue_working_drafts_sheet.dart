import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/continue_work_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/pending_sync_cubit.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_working_draft_row.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_working_drafts_sheet_skeleton.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_working_remote_draft_row.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';

/// Opens the all-drafts bottom sheet, handing it the caller's cubits.
void openContinueWorkingDraftsSheet(BuildContext context) {
  final continueCubit = context.read<ContinueWorkCubit>();
  final pendingCubit = context.read<PendingSyncCubit>();
  showModalBottomSheet<void>(
    constraints: const BoxConstraints(maxWidth: AppBottomSheet.maxWidth),
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: continueCubit),
        BlocProvider.value(value: pendingCubit),
      ],
      child: const ContinueWorkingDraftsSheet(),
    ),
  );
}

/// "Continue Working (N)" bottom sheet listing every local and backend draft.
/// Restyle the sheet frame, grabber, title, and empty state here.
class ContinueWorkingDraftsSheet extends StatelessWidget {
  const ContinueWorkingDraftsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(context.rr(24))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: context.rr(20),
              offset: Offset(0, -context.rh(4)),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: BlocBuilder<ContinueWorkCubit, ContinueWorkState>(
            builder: (context, state) {
              if (!state.loaded) {
                return const ContinueWorkingDraftsSheetSkeleton();
              }

              return Padding(
                padding: EdgeInsets.fromLTRB(context.rw(16), context.rh(14),
                    context.rw(16), context.rh(16)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: context.rw(44),
                        height: context.rh(5),
                        decoration: BoxDecoration(
                          color: colors.border,
                          borderRadius: BorderRadius.circular(context.rr(2.5)),
                        ),
                      ),
                    ),
                    SizedBox(height: context.rh(14)),
                    Text(
                      'sync.continue_working'
                          .trParams({'count': state.totalCount}),
                      style: TextStyle(
                        fontSize: context.rsp(17),
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    SizedBox(height: context.rh(12)),
                    if (state.totalCount == 0)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: context.rh(30)),
                        child: Center(
                          child: Text(
                            'sync.no_drafts_left'.tr,
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        ),
                      )
                    else
                      Flexible(child: _DraftsList(state: state)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Local drafts first, then backend-only drafts.
class _DraftsList extends StatelessWidget {
  const _DraftsList({required this.state});
  final ContinueWorkState state;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: state.totalCount,
      separatorBuilder: (_, __) => SizedBox(height: context.rh(10)),
      itemBuilder: (context, i) {
        if (i < state.drafts.length) {
          final draft = state.drafts[i];
          return ContinueWorkingDraftRow(
            draft: draft,
            returned: state.isReturned(draft.id),
            returnReason: state.returnReasons[draft.id],
          );
        }
        return ContinueWorkingRemoteDraftRow(
          draft: state.remoteDrafts[i - state.drafts.length],
        );
      },
    );
  }
}
