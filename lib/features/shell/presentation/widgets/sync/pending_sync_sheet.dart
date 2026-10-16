import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_registration_queue_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/pending_visit_sync_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/sync/pending_visits_section.dart';
import 'package:steelforce/features/depots/presentation/widgets/sync/pending_depot_registrations_section.dart';
import 'package:steelforce/features/order/domain/entities/quotation_sync_status.dart';
import 'package:steelforce/features/order/domain/entities/sync_queue_item.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/pending_sync_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/pending_sync_state.dart';
import 'package:steelforce/features/order/presentation/l10n/quotation_sync_error_l10n.dart';
import 'package:steelforce/features/order/presentation/l10n/quotation_sync_status_l10n.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/quotation_detail_screen.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// The "Sync Center" — a bottom sheet listing work on its way to the server:
/// depot registrations saved offline, visit check-ins and check-outs, and
/// quotations on their way to the Admin backend with what the backend or an
/// administrator said. The rep's actions:
/// **Sync Now**, per-item **Retry** / **Fix** / **Discard**, and **Review
/// prices** for a price-change conflict. Depot and visit cards also carry
/// **Sync** (the same send-everything drain) and open their details on tap.
/// Syncing itself is automatic; this is visibility and control, not the
/// trigger.
///
/// Uses the shell's cubits when [context] is under them. A screen pushed on
/// its own route (Profile) is not, so the sheet then makes its own, which
/// close with it.
Future<void> showPendingSyncSheet(BuildContext context) {
  final cubit = _readOrNull<PendingSyncCubit>(context);
  final depots = _readOrNull<DepotRegistrationQueueCubit>(context);
  return showModalBottomSheet<void>(
    constraints: const BoxConstraints(maxWidth: AppBottomSheet.maxWidth),
    context: context,
    isScrollControlled: true,
    backgroundColor: context.appColors.surfaceSoft,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => MultiBlocProvider(
      providers: [
        cubit != null
            ? BlocProvider.value(value: cubit)
            : BlocProvider(create: (_) => sl<PendingSyncCubit>()),
        depots != null
            ? BlocProvider.value(value: depots)
            : BlocProvider(create: (_) => sl<DepotRegistrationQueueCubit>()),
        BlocProvider(create: (_) => sl<PendingVisitSyncCubit>()..load()),
      ],
      child: const _SyncSheet(),
    ),
  );
}

T? _readOrNull<T extends StateStreamableSource<Object?>>(BuildContext context) {
  // `context.read`, not `BlocProvider.of`: the latter rethrows a missing
  // provider as a plain FlutterError, which this cannot tell apart.
  try {
    return context.read<T>();
  } on ProviderNotFoundException {
    return null;
  }
}

class _SyncSheet extends StatelessWidget {
  const _SyncSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: BlocBuilder<PendingSyncCubit, PendingSyncState>(
          builder: (context, state) {
            final depots = context.watch<DepotRegistrationQueueCubit>().state;
            final visitState = context.watch<PendingVisitSyncCubit>().state;
            final visits = visitState.pending;
            final scheme = Theme.of(context).colorScheme;
            final colors = context.appColors;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _grabber(colors.border),
                  SizedBox(height: context.rh(12)),
                  Row(
                    children: [
                      Expanded(
                        child: Text('sync.center_title'.tr,
                            style: TextStyle(
                                fontSize: context.rsp(17),
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface)),
                      ),
                      if (state.counts.pending > 0 ||
                          depots.sending > 0 ||
                          !visits.isEmpty)
                        // Any send in progress — this button's, a card's
                        // Sync, or an automatic drain — runs the same queue.
                        _SyncNowButton(
                          isSyncing: state.isSyncing ||
                              depots.syncing ||
                              visitState.syncing,
                        ),
                    ],
                  ),
                  SizedBox(height: context.rh(4)),
                  Text(
                    'sync.auto_sync_hint'.tr,
                    style: TextStyle(
                        color: colors.textSecondary, fontSize: context.rsp(12)),
                  ),
                  SizedBox(height: context.rh(2)),
                  Text(
                    'sync.counts'.trParams({
                      'pending': state.counts.pending,
                      'failed': state.counts.failed,
                      'conflict': state.counts.conflict,
                    }),
                    style: TextStyle(
                        color: colors.textSecondary, fontSize: context.rsp(12)),
                  ),
                  SizedBox(height: context.rh(12)),
                  if (state.items.isEmpty &&
                      depots.items.isEmpty &&
                      visits.isEmpty)
                    const _EmptyQueue()
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        // Slots 0 and 1 are the depot and visit sections,
                        // which render nothing when empty.
                        itemCount: state.items.length + 2,
                        separatorBuilder: (_, i) =>
                            SizedBox(height: i < 2 ? 0 : context.rh(10)),
                        itemBuilder: (context, i) => switch (i) {
                          0 => const PendingDepotRegistrationsSection(),
                          1 => const PendingVisitsSection(),
                          2 => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'sync_center.quotation.section_title'.tr,
                                  style: TextStyle(
                                    fontSize: context.rsp(13),
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                SizedBox(height: context.rh(8)),
                                _QueueTile(item: state.items[0]),
                              ],
                            ),
                          _ => _QueueTile(item: state.items[i - 2]),
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _grabber(Color color) => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

class _SyncNowButton extends StatelessWidget {
  const _SyncNowButton({required this.isSyncing});
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isSyncing
          ? null
          : () {
              context.read<PendingSyncCubit>().syncNow();
              context.read<DepotRegistrationQueueCubit>().syncNow();
            },
      style: FilledButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      icon: isSyncing
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : Icon(Icons.sync_rounded, size: context.rr(16)),
      label: Text(isSyncing ? 'sync.syncing'.tr : 'sync.sync_now'.tr),
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({required this.item});
  final SyncQueueItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final color = _statusColor(context, item.status);
    return Container(
      padding: EdgeInsets.all(context.rr(12)),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.shopName?.isNotEmpty == true
                      ? item.shopName!
                      : 'sync.quotation_ref'.trParams({'id': item.quotationId}),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: context.rsp(13.5),
                      color: scheme.onSurface),
                ),
              ),
              _StatusChip(status: item.status, color: color),
            ],
          ),
          SizedBox(height: context.rh(4)),
          Text(
            [
              if (item.itemCount != null)
                'sync.items'.trParams({'count': item.itemCount}),
              if (item.total != null)
                NumberFormat.currency(
                        locale: context.languageCode, symbol: r'$')
                    .format(item.total),
              if (item.attemptCount > 0)
                'sync.attempt'.trParams({'count': item.attemptCount}),
            ].join(' · '),
            style: TextStyle(
                color: colors.textSecondary, fontSize: context.rsp(11.5)),
          ),
          if (item.remoteNumber != null) ...[
            SizedBox(height: context.rh(6)),
            _InfoLine(
              icon: Icons.check_circle_rounded,
              color: colors.success,
              text: 'sync.admin_document'.trParams({
                'id': item.remoteNumber,
                'status': item.remoteStatus == null
                    ? ''
                    : localizedRemoteStatus(item.remoteStatus!),
              }),
            ),
          ],
          if (item.decisionReason?.isNotEmpty == true) ...[
            SizedBox(height: context.rh(6)),
            _InfoLine(
              icon: Icons.chat_bubble_outline_rounded,
              color: colors.warning,
              text:
                  'sync.admin_reason'.trParams({'reason': item.decisionReason}),
            ),
          ],
          if (item.status.needsUserAction &&
              item.status != QuotationSyncStatus.returned) ...[
            SizedBox(height: context.rh(6)),
            _InfoLine(
              icon: Icons.error_outline_rounded,
              color: scheme.error,
              text: localizedSyncError(item.errorCode),
            ),
          ],
          if (item.status.needsUserAction) ...[
            SizedBox(height: context.rh(8)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => context
                      .read<PendingSyncCubit>()
                      .discard(item.quotationId),
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
                    icon:
                        Icon(Icons.price_change_outlined, size: context.rr(16)),
                    label: Text('sync.review_prices'.tr),
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: () => context
                        .read<PendingSyncCubit>()
                        .retry(item.quotationId),
                    icon: Icon(Icons.refresh_rounded, size: context.rr(16)),
                    label: Text('common.retry'.tr),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static void _openRemote(BuildContext context, SyncQueueItem item) {
    Navigator.of(context).push(MaterialPageRoute(
      settings: const RouteSettings(name: QuotationDetailScreen.routeName),
      builder: (_) =>
          QuotationDetailScreen(quotationId: item.remoteQuotationId),
    ));
  }

  static Color _statusColor(BuildContext context, QuotationSyncStatus status) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return switch (status) {
      QuotationSyncStatus.accepted => colors.success,
      QuotationSyncStatus.failed ||
      QuotationSyncStatus.rejected =>
        scheme.error,
      QuotationSyncStatus.conflict ||
      QuotationSyncStatus.returned =>
        colors.warning,
      QuotationSyncStatus.syncing ||
      QuotationSyncStatus.submitted =>
        scheme.primary,
      _ => colors.textSecondary,
    };
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.color});
  final QuotationSyncStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      // `status.label(context)` — the enum's `label` was a String getter, not a
      // method, so this did not compile at all; the sheet could not build.
      // Now read from `orders.sync_status.*`, which was already translated in
      // both language files and had no caller.
      child: Text(
        status.localizedLabel,
        style: TextStyle(
            color: color,
            fontSize: context.rsp(10.5),
            fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(
      {required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: context.rr(14), color: color),
        SizedBox(width: context.rw(6)),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  color: color, fontSize: context.rsp(11.5), height: 1.3)),
        ),
      ],
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_done_rounded,
                size: context.rr(40), color: colors.success),
            SizedBox(height: context.rh(10)),
            Text('sync.everything_synced'.tr,
                style: TextStyle(
                    color: scheme.onSurface, fontWeight: FontWeight.w700)),
            SizedBox(height: context.rh(4)),
            Text('sync.none_waiting'.tr,
                style: TextStyle(
                    color: colors.textSecondary, fontSize: context.rsp(12))),
          ],
        ),
      ),
    );
  }
}
