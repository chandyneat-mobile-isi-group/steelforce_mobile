import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/quotation_sync_status.dart';
import 'package:steelforce/features/order/domain/entities/sync_queue_item.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/pending_sync_cubit.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/quotation_detail_screen.dart';

/// The action row on a quotation card that needs the rep: **Discard**, then
/// **Review prices** for a price-change conflict or **Retry** otherwise.
class QuotationQueueActions extends StatelessWidget {
  const QuotationQueueActions({super.key, required this.item});
  final SyncQueueItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () =>
              context.read<PendingSyncCubit>().discard(item.quotationId),
          child: Text('common.discard'.tr,
              style: TextStyle(color: colors.textSecondary)),
        ),
        SizedBox(width: context.rw(4)),
        if (item.status == QuotationSyncStatus.conflict &&
            item.remoteQuotationId != null)
          // The contract requires the rep to see moved prices before
          // resubmitting, so this opens the document — where the
          // reprice → submit loop lives — instead of retrying blind.
          FilledButton.tonalIcon(
            onPressed: () => _openRemote(context, item),
            icon: Icon(Icons.price_change_outlined, size: context.rr(16)),
            label: Text('sync.review_prices'.tr),
          )
        else
          FilledButton.tonalIcon(
            onPressed: () =>
                context.read<PendingSyncCubit>().retry(item.quotationId),
            icon: Icon(Icons.refresh_rounded, size: context.rr(16)),
            label: Text('common.retry'.tr),
          ),
      ],
    );
  }

  static void _openRemote(BuildContext context, SyncQueueItem item) {
    Navigator.of(context).push(MaterialPageRoute(
      settings: const RouteSettings(name: QuotationDetailScreen.routeName),
      builder: (_) =>
          QuotationDetailScreen(quotationId: item.remoteQuotationId),
    ));
  }
}
