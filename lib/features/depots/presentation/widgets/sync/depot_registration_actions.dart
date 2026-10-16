import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/depots/domain/entities/pending_depot_registration.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_registration_queue_cubit.dart';

/// The rep's actions on one queued registration — on its Sync Center card
/// and in its details sheet: **Discard** (always), **Fix** (a SAP refusal
/// with its form kept), **Retry** (an unknown outcome, after a check) and
/// **Sync** (a row the engine sends by itself).
///
/// Sync sends everything waiting, not only this registration: the engine
/// keeps depots, visits and quotations in the order the server needs them.
class DepotRegistrationActions extends StatelessWidget {
  const DepotRegistrationActions({super.key, required this.item});
  final PendingDepotRegistration item;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DepotRegistrationQueueCubit>();
    final scheme = Theme.of(context).colorScheme;
    final syncing = context.select<DepotRegistrationQueueCubit, bool>(
      (c) => c.state.syncing,
    );
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: context.rw(4),
      runSpacing: context.rh(4),
      children: [
        // Discard is offered on every row, not only those needing the rep:
        // a row whose photographs never go up must not be able to hold the
        // rep's sign-out hostage.
        TextButton(
          onPressed: () => _confirmDiscard(context, cubit),
          child: Text(
            'common.discard'.tr,
            style: TextStyle(color: scheme.error),
          ),
        ),
        if (item.status == DepotRegistrationQueueStatus.rejected &&
            item.canReopen)
          FilledButton.tonalIcon(
            onPressed: () => cubit.reopen(item.id),
            icon: Icon(Icons.edit_outlined, size: context.rr(16)),
            label: Text('sync_center.depot.fix'.tr),
          ),
        if (item.status == DepotRegistrationQueueStatus.needsReview)
          FilledButton.tonalIcon(
            onPressed: () => _confirmRetry(context, cubit),
            icon: Icon(Icons.refresh_rounded, size: context.rr(16)),
            label: Text('common.retry'.tr),
          ),
        // A row needing the rep is never sent by a drain, so Sync would do
        // nothing for it; Fix / Retry are its way forward.
        if (!item.status.needsRep)
          FilledButton.tonalIcon(
            onPressed: syncing ? null : cubit.syncNow,
            icon: syncing
                ? SizedBox.square(
                    dimension: context.rr(14),
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.sync_rounded, size: context.rr(16)),
            label: Text(syncing ? 'sync.syncing'.tr : 'sync_center.sync'.tr),
          ),
      ],
    );
  }

  /// A resend here can create a second business partner in SAP, so the rep
  /// confirms they checked first. Not a formality: it is the duplicate check
  /// the endpoint itself cannot do.
  Future<void> _confirmRetry(
    BuildContext context,
    DepotRegistrationQueueCubit cubit,
  ) async {
    final ok = await _confirm(
      context,
      title: 'sync_center.depot.retry_confirm_title'.tr,
      body: 'sync_center.depot.retry_confirm_body'.tr,
      action: 'common.retry'.tr,
    );
    if (ok) await cubit.retry(item.id);
  }

  Future<void> _confirmDiscard(
    BuildContext context,
    DepotRegistrationQueueCubit cubit,
  ) async {
    final ok = await _confirm(
      context,
      title: 'sync_center.depot.discard_confirm_title'.tr,
      body: 'sync_center.depot.discard_confirm_body'.tr,
      action: 'common.discard'.tr,
    );
    if (ok) await cubit.discard(item.id);
  }

  static Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('common.cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
