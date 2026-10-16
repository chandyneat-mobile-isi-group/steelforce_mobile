part of 'continue_working_card.dart';

/// Gold Framed Tactile Card Shell with Corner Watermarks
class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});
  final Widget child;

  static const Color _goldBorderColor = Color(0xFFCBA135);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12.r,
            offset: Offset(0, context.rh(6)),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.rr(17)),
        child: Stack(
          children: [
            // Top-Left Corner Decorative Circle Watermark
            Positioned(
              top: -context.rr(22),
              left: -context.rr(22),
              child: Container(
                width: context.rr(55),
                height: context.rr(55),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            // Bottom-Right Corner Decorative Circle Watermark
            Positioned(
              bottom: -context.rr(22),
              right: -context.rr(22),
              child: Container(
                width: context.rr(55),
                height: context.rr(55),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            // Card Content
            Padding(
              padding: EdgeInsets.all(context.rr(14)),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tactile 3D Filled Action Button
class _ThreeDFilledButton extends StatelessWidget {
  const _ThreeDFilledButton({
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.rr(10)),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.35),
            blurRadius: 6.r,
            offset: Offset(0, context.rh(3)),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: themeColor,
          padding: EdgeInsets.symmetric(vertical: context.rh(10)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.rr(10)),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: context.rsp(12.5),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Tactile 3D Outlined Action Button
class _ThreeDOutlinedButton extends StatelessWidget {
  const _ThreeDOutlinedButton({
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.rr(10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4.r,
            offset: Offset(0, context.rh(2)),
          ),
        ],
      ),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: themeColor,
          backgroundColor: scheme.surface,
          side: BorderSide(
            color: themeColor.withValues(alpha: 0.8),
            width: 1.2,
          ),
          padding: EdgeInsets.symmetric(vertical: context.rh(10)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.rr(10)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: context.rsp(12.5),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DiscardButton extends StatelessWidget {
  const _DiscardButton({required this.draft});
  final Quotation draft;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _confirmDiscard(context, draft),
      borderRadius: BorderRadius.circular(context.rr(20)),
      child: Container(
        padding: EdgeInsets.all(context.rr(4)),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.appColors.textSecondary.withValues(alpha: 0.08),
        ),
        child: Icon(
          Icons.close_rounded,
          size: context.rsp(16),
          color: context.appColors.textSecondary,
        ),
      ),
    );
  }
}

String _subtitle(Quotation q) {
  final who = q.shopName?.isNotEmpty == true
      ? q.shopName!
      : (q.leadDisplayName ?? 'orders.quotation_extra.walk_in'.tr);
  return 'sync.draft_meta'.trParams(
      {'who': who, 'count': q.lines.length, 'time': _timeAgo(q.updatedAt)});
}

String _timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'common.just_now'.tr;
  if (diff.inMinutes < 60) {
    return 'common.min_ago'.trParams({'minutes': diff.inMinutes});
  }
  if (diff.inHours < 24) {
    return 'common.hours_ago'.trParams({'hours': diff.inHours});
  }
  return 'common.days_ago'.trParams({'days': diff.inDays});
}

void _continueRemote(BuildContext context, QuotationSummary draft) {
  Navigator.of(context).push(MaterialPageRoute(
    settings: const RouteSettings(name: QuotationDetailScreen.routeName),
    builder: (_) => QuotationDetailScreen(quotationId: draft.id),
  ));
}

void _continue(BuildContext context, Quotation draft) {
  Navigator.of(context).push(MaterialPageRoute(
    settings: const RouteSettings(name: QuotationDetailScreen.routeName),
    builder: (_) => QuotationDetailScreen(quotation: draft),
  ));
}

void _submit(BuildContext context, Quotation draft) {
  context.read<PendingSyncCubit>().enqueue(draft.id);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('sync.queued_for_admin'.trParams({'id': draft.id})),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Future<void> _confirmDiscard(BuildContext context, Quotation draft) async {
  final cubit = context.read<ContinueWorkCubit>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('sync.discard_draft_title'.tr),
      content: Text('sync.discard_draft_body'.trParams({'id': draft.id})),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text('common.keep'.tr),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            'common.discard'.tr,
            style: TextStyle(
              color: Theme.of(dialogContext).colorScheme.error,
            ),
          ),
        ),
      ],
    ),
  );
  if (confirmed ?? false) await cubit.discard(draft.id);
}

void _openDraftsSheet(BuildContext context) {
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
      child: const _DraftsSheet(),
    ),
  );
}

/// "Returned by Admin", with the administrator's reason when they gave one —
/// the reason is the whole point of a return (quotation-orders/api/mobile.md).
class _ReturnedNote extends StatelessWidget {
  const _ReturnedNote({this.reason});
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = reason?.isNotEmpty == true
        ? 'sync.admin_reason'.trParams({'reason': reason})
        : 'sync.returned_by_admin'.tr;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.reply_rounded, size: context.rsp(14), color: colors.warning),
        SizedBox(width: context.rw(6)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: context.rsp(11.5),
              fontWeight: FontWeight.w600,
              color: colors.warning,
            ),
          ),
        ),
      ],
    );
  }
}
