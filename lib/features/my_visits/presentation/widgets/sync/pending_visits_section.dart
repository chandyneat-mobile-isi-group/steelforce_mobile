import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/pending_visit_sync.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/pending_visit_sync_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/sync/pending_visit_actions.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/sync/pending_visit_details_sheet.dart';
import 'package:steelforce/routes/app_routes.dart';

/// Visit work saved on this device that has not reached the server, for the
/// Sync Center — one card per stop with anything waiting (a check-in, a
/// check-out, or only stock counts, notes, photos, …), in the order they are
/// sent.
///
/// Tapping a card opens its details. Each card offers **Sync** (sends
/// everything waiting, in order) and **Discard** (throws the stop's unsent
/// work away so the visit can be done again).
///
/// Renders nothing when there is nothing waiting, so the sheet's own empty
/// state stays the single "everything is synced" message.
class PendingVisitsSection extends StatelessWidget {
  const PendingVisitsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PendingVisitSyncCubit, PendingVisitSyncState>(
      listenWhen: (a, b) => b.messageKey != null,
      // Through the root messenger, as the depot section does: the outcome can
      // land while a details sheet over this one is closing.
      listener: (_, state) => rootMessengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text(state.messageKey!.tr))),
      buildWhen: (a, b) => a.pending != b.pending,
      builder: (context, state) {
        final pending = state.pending;
        if (pending.isEmpty) return const SizedBox.shrink();
        final colors = context.appColors;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'sync_center.visit.section_title'.tr,
              style: TextStyle(
                fontSize: context.rsp(13),
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: context.rh(8)),
            for (final stop in pending.stops) ...[
              PendingVisitTile(stop: stop),
              SizedBox(height: context.rh(10)),
            ],
            if (pending.otherRecords > 0) ...[
              _InfoLine(
                icon: Icons.inventory_2_outlined,
                color: colors.textSecondary,
                text: 'sync_center.visit.other_records'
                    .trParams({'count': pending.otherRecords}),
              ),
              SizedBox(height: context.rh(10)),
            ],
          ],
        );
      },
    );
  }
}

/// One stop waiting in the Sync Center.
class PendingVisitTile extends StatelessWidget {
  const PendingVisitTile({super.key, required this.stop});
  final PendingVisitStop stop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final time = DateFormat('d MMM, HH:mm', context.languageCode);
    final checkIn = stop.checkInAt;
    final checkOut = stop.checkOutAt;
    final shop = pendingVisitShopName(context, stop);
    final radius = BorderRadius.circular(14);

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(context.rr(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              label: shop,
              hint: 'common.view_details'.tr,
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => showPendingVisitDetailsSheet(context, stop.stopId),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.place_outlined,
                              size: context.rr(16),
                              color: colors.textSecondary),
                          SizedBox(width: context.rw(6)),
                          Expanded(
                            child: Text(
                              shop,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: context.rsp(13.5),
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          _Chip(
                            label: 'sync_center.visit.waiting'.tr,
                            color: colors.textSecondary,
                          ),
                          SizedBox(width: context.rw(2)),
                          Icon(Icons.chevron_right_rounded,
                              size: context.rr(18),
                              color: colors.textSecondary),
                        ],
                      ),
                      if (checkIn != null) ...[
                        SizedBox(height: context.rh(6)),
                        _InfoLine(
                          icon: Icons.login_rounded,
                          color: colors.textSecondary,
                          text: 'sync_center.visit.check_in'.trParams(
                              {'time': time.format(checkIn.toLocal())}),
                        ),
                      ],
                      if (checkOut != null) ...[
                        SizedBox(height: context.rh(6)),
                        _InfoLine(
                          icon: Icons.logout_rounded,
                          color: colors.textSecondary,
                          text: 'sync_center.visit.check_out'.trParams(
                              {'time': time.format(checkOut.toLocal())}),
                        ),
                      ],
                      if (stop.checkOutWaitsForCheckIn) ...[
                        SizedBox(height: context.rh(6)),
                        _InfoLine(
                          icon: Icons.format_list_numbered_rounded,
                          color: colors.textSecondary,
                          text: 'sync_center.visit.after_check_in'.tr,
                        ),
                      ],
                      if (stop.captureCount > 0) ...[
                        SizedBox(height: context.rh(6)),
                        _InfoLine(
                          icon: Icons.inventory_2_outlined,
                          color: colors.textSecondary,
                          text: 'sync_center.visit.captures_waiting'
                              .trParams({'count': stop.captureCount}),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: context.rh(8)),
            PendingVisitActions(stop: stop),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: context.rsp(10.5),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.color,
    required this.text,
  });
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
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: context.rsp(11.5),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
