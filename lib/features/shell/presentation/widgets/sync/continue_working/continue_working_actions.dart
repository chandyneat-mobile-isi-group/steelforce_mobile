import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/continue_work_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/pending_sync_cubit.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/quotation_detail_screen.dart';

// Shared UI actions and labels for the "Continue Working" card and drafts
// sheet: open, submit, and discard a draft. Each one hands off to a cubit or
// the navigator — no business rules live here.

/// "Shop · N items · time ago" line under a draft's quotation number.
String continueWorkingDraftSubtitle(Quotation q) {
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

/// Opens a backend-only draft on the document screen.
void continueRemoteDraft(BuildContext context, QuotationSummary draft) {
  Navigator.of(context).push(MaterialPageRoute(
    settings: const RouteSettings(name: QuotationDetailScreen.routeName),
    builder: (_) => QuotationDetailScreen(quotationId: draft.id),
  ));
}

/// Opens a local draft on the document screen.
void continueLocalDraft(BuildContext context, Quotation draft) {
  Navigator.of(context).push(MaterialPageRoute(
    settings: const RouteSettings(name: QuotationDetailScreen.routeName),
    builder: (_) => QuotationDetailScreen(quotation: draft),
  ));
}

/// Queues a local draft for admin review and confirms it with a snackbar.
void submitDraftForReview(BuildContext context, Quotation draft) {
  context.read<PendingSyncCubit>().enqueue(draft.id);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('sync.queued_for_admin'.trParams({'id': draft.id})),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Asks the rep to confirm, then discards the local draft.
Future<void> confirmDiscardDraft(BuildContext context, Quotation draft) async {
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
