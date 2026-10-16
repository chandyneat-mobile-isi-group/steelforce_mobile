part of 'continue_working_card.dart';

class _DraftsSheet extends StatelessWidget {
  const _DraftsSheet();

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
              blurRadius: 20.r,
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
                return const _DraftsSheetSkeleton();
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
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          itemCount: state.totalCount,
                          separatorBuilder: (_, __) =>
                              SizedBox(height: context.rh(10)),
                          itemBuilder: (context, i) {
                            if (i < state.drafts.length) {
                              final draft = state.drafts[i];
                              return _DraftRow(
                                draft: draft,
                                returned: state.isReturned(draft.id),
                                returnReason: state.returnReasons[draft.id],
                              );
                            }
                            return _RemoteDraftRow(
                              draft:
                                  state.remoteDrafts[i - state.drafts.length],
                            );
                          },
                        ),
                      ),
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

class _DraftsSheetSkeleton extends StatelessWidget {
  const _DraftsSheetSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final skeletonColor = scheme.onSurface.withValues(alpha: 0.12);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          context.rw(16), context.rh(14), context.rw(16), context.rh(24)),
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
          SizedBox(height: context.rh(16)),
          Container(
            width: context.rw(160),
            height: context.rh(18),
            decoration: BoxDecoration(
              color: skeletonColor,
              borderRadius: BorderRadius.circular(context.rr(4)),
            ),
          ),
          SizedBox(height: context.rh(16)),
          ...List.generate(
            2,
            (index) => Container(
              margin: EdgeInsets.only(bottom: context.rh(10)),
              height: context.rh(70),
              decoration: BoxDecoration(
                color: skeletonColor,
                borderRadius: BorderRadius.circular(context.rr(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({
    required this.draft,
    this.returned = false,
    this.returnReason,
  });
  final Quotation draft;
  final bool returned;
  final String? returnReason;

  static const Color _goldBorderColor = Color(0xFFCBA135);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.all(context.rr(12)),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(context.rr(12)),
        border: Border.all(color: _goldBorderColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6.r,
            offset: Offset(0, context.rh(3)),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'sync.quotation_n'.trParams({'id': draft.id}),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: context.rsp(13.5),
              color: scheme.primary,
            ),
          ),
          SizedBox(height: context.rh(2)),
          Text(
            _subtitle(draft),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: context.rsp(11.5), color: colors.textSecondary),
          ),
          if (returned) ...[
            SizedBox(height: context.rh(6)),
            _ReturnedNote(reason: returnReason),
          ],
          SizedBox(height: context.rh(10)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _confirmDiscard(context, draft),
                child: Text(
                  'common.discard'.tr,
                  style: TextStyle(
                    fontSize: context.rsp(12),
                    color: colors.textSecondary,
                  ),
                ),
              ),
              SizedBox(width: context.rw(4)),
              _ThreeDOutlinedButton(
                label: 'common.submit'.tr,
                onPressed: () => _submit(context, draft),
              ),
              SizedBox(width: context.rw(8)),
              _ThreeDFilledButton(
                label: 'common.continue'.tr,
                onPressed: () {
                  Navigator.of(context).pop();
                  _continue(context, draft);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A still-editable document on the Admin backend with no copy on this device.
/// It is edited and submitted on the document screen, online — there is no
/// local draft to submit from here, and no local discard for it.
class _RemoteDraftRow extends StatelessWidget {
  const _RemoteDraftRow({required this.draft});
  final QuotationSummary draft;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.all(context.rr(12)),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(context.rr(12)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'sync.quotation_n'.trParams({'id': draft.number}),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: context.rsp(13.5),
              color: scheme.primary,
            ),
          ),
          SizedBox(height: context.rh(2)),
          Text(
            'sync.on_admin_server'.trParams({
              'who': draft.depotName,
              'count': draft.lineCount,
              'status': localizedRemoteStatus(draft.status),
            }),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: context.rsp(11.5), color: colors.textSecondary),
          ),
          SizedBox(height: context.rh(10)),
          Align(
            alignment: Alignment.centerRight,
            child: _ThreeDFilledButton(
              label: 'common.continue'.tr,
              onPressed: () {
                Navigator.of(context).pop();
                _continueRemote(context, draft);
              },
            ),
          ),
        ],
      ),
    );
  }
}
