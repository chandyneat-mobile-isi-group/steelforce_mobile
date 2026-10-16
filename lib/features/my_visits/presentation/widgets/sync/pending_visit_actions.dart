import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/my_visits/domain/entities/pending_visit_sync.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/pending_visit_sync_cubit.dart';

/// The shop name a pending visit is shown under: the Khmer name in Khmer when
/// there is one, otherwise the English name, otherwise "not on this device".
String pendingVisitShopName(BuildContext context, PendingVisitStop stop) {
  final kh = stop.shopNameKh;
  if (context.languageCode == 'km' && kh != null && kh.isNotEmpty) return kh;
  final name = stop.shopName;
  return name == null || name.isEmpty
      ? 'sync_center.visit.unknown_shop'.tr
      : name;
}

/// **Discard** and **Sync** for one visit waiting in the Sync Center — on its
/// card and in its details sheet.
///
/// Sync sends everything waiting, not just this stop: a check-out may never
/// overtake its check-in, and the orders taken at the shop go in between.
class PendingVisitActions extends StatelessWidget {
  const PendingVisitActions({super.key, required this.stop});

  final PendingVisitStop stop;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PendingVisitSyncCubit>();
    final scheme = Theme.of(context).colorScheme;
    return BlocBuilder<PendingVisitSyncCubit, PendingVisitSyncState>(
      buildWhen: (a, b) =>
          a.syncing != b.syncing ||
          a.discarding.contains(stop.stopId) !=
              b.discarding.contains(stop.stopId),
      builder: (context, state) {
        final discarding = state.discarding.contains(stop.stopId);
        final busy = state.syncing || discarding;
        return Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: context.rw(4),
          runSpacing: context.rh(4),
          children: [
            if (cubit.canDiscard)
              TextButton(
                onPressed: busy ? null : () => _confirmDiscard(context, cubit),
                child: Text(
                  'common.discard'.tr,
                  style: TextStyle(color: busy ? null : scheme.error),
                ),
              ),
            if (cubit.canSync)
              FilledButton.tonalIcon(
                onPressed: busy ? null : cubit.syncNow,
                icon: state.syncing
                    ? SizedBox.square(
                        dimension: context.rr(14),
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.sync_rounded, size: context.rr(16)),
                label: Text(
                  state.syncing ? 'sync.syncing'.tr : 'sync_center.sync'.tr,
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDiscard(
    BuildContext context,
    PendingVisitSyncCubit cubit,
  ) async {
    final shop = pendingVisitShopName(context, stop);
    final body = stop.checkInAt != null
        ? 'sync_center.visit.discard_confirm_body_check_in'
            .trParams({'shop': shop})
        : stop.checkOutAt != null
            ? 'sync_center.visit.discard_confirm_body_check_out'
                .trParams({'shop': shop})
            : 'sync_center.visit.discard_confirm_body_records'
                .trParams({'shop': shop, 'count': stop.recordCount});
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text('sync_center.visit.discard_confirm_title'.tr),
          content: SingleChildScrollView(child: Text(body)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('common.cancel'.tr),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('common.discard'.tr),
            ),
          ],
        );
      },
    );
    if (ok ?? false) await cubit.discard(stop.stopId);
  }
}
