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
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';

/// Opens the details of one visit waiting in the Sync Center, over the Sync
/// Center itself. [context] must be under the [PendingVisitSyncCubit].
Future<void> showPendingVisitDetailsSheet(BuildContext context, String stopId) {
  final cubit = context.read<PendingVisitSyncCubit>();
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: PendingVisitDetailsSheet(stopId: stopId),
    ),
  );
}

/// What one stop still holds on this device: its check-in and check-out
/// times, whether the check-out waits for the check-in, and each kind of
/// capture with its count — plus **Sync** and **Discard**.
///
/// Reads the stop from the cubit by id, so it stays current while a sync
/// runs, and closes itself once the stop has nothing left waiting (sent, or
/// discarded).
class PendingVisitDetailsSheet extends StatefulWidget {
  const PendingVisitDetailsSheet({super.key, required this.stopId});

  final String stopId;

  @override
  State<PendingVisitDetailsSheet> createState() =>
      _PendingVisitDetailsSheetState();
}

class _PendingVisitDetailsSheetState extends State<PendingVisitDetailsSheet> {
  bool _closing = false;

  void _closeIfGone(PendingVisitSyncState state) {
    if (_closing || !state.loaded || state.stop(widget.stopId) != null) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PendingVisitSyncCubit, PendingVisitSyncState>(
      listener: (_, state) => _closeIfGone(state),
      builder: (context, state) {
        final stop = state.stop(widget.stopId);
        if (stop == null) return const SizedBox.shrink();
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            context.rw(16),
            context.rh(4),
            context.rw(16),
            context.rh(16),
          ),
          child: _Details(stop: stop),
        );
      },
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.stop});
  final PendingVisitStop stop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final time = DateFormat('d MMM, HH:mm', context.languageCode);
    String at(DateTime? t) => t == null
        ? 'sync_center.visit.nothing_waiting'.tr
        : time.format(t.toLocal());

    final kinds = <(IconData, String, int)>[
      (
        Icons.shopping_cart_outlined,
        'sync_center.visit.kind.order_lines'.tr,
        stop.orderLines
      ),
      (
        Icons.inventory_2_outlined,
        'sync_center.visit.kind.stock_updates'.tr,
        stop.stockUpdates
      ),
      (
        Icons.assignment_return_outlined,
        'sync_center.visit.kind.returns'.tr,
        stop.returns
      ),
      (
        Icons.payments_outlined,
        'sync_center.visit.kind.collections'.tr,
        stop.collections
      ),
      (Icons.notes_rounded, 'sync_center.visit.kind.notes'.tr, stop.notes),
      (
        Icons.photo_camera_outlined,
        'sync_center.visit.kind.photos'.tr,
        stop.photos
      ),
    ].where((k) => k.$3 > 0).toList();

    final sectionStyle = TextStyle(
      fontSize: context.rsp(12.5),
      fontWeight: FontWeight.w800,
      color: colors.textSecondary,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'sync_center.visit.details_title'.tr,
          style: TextStyle(
            fontSize: context.rsp(12),
            color: colors.textSecondary,
          ),
        ),
        SizedBox(height: context.rh(4)),
        Text(
          pendingVisitShopName(context, stop),
          style: TextStyle(
            fontSize: context.rsp(17),
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        SizedBox(height: context.rh(16)),
        _Row(
          icon: Icons.login_rounded,
          label: 'sync_center.visit.check_in_label'.tr,
          value: at(stop.checkInAt),
          muted: stop.checkInAt == null,
        ),
        _Row(
          icon: Icons.logout_rounded,
          label: 'sync_center.visit.check_out_label'.tr,
          value: at(stop.checkOutAt),
          muted: stop.checkOutAt == null,
        ),
        if (stop.checkOutWaitsForCheckIn) ...[
          SizedBox(height: context.rh(4)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.format_list_numbered_rounded,
                size: context.rr(16),
                color: colors.textSecondary,
              ),
              SizedBox(width: context.rw(8)),
              Expanded(
                child: Text(
                  'sync_center.visit.after_check_in'.tr,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: context.rsp(12),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (kinds.isNotEmpty) ...[
          SizedBox(height: context.rh(16)),
          Text('sync_center.visit.captures_title'.tr, style: sectionStyle),
          SizedBox(height: context.rh(6)),
          for (final (icon, label, count) in kinds)
            _Row(icon: icon, label: label, value: '$count'),
        ],
        SizedBox(height: context.rh(16)),
        PendingVisitActions(stop: stop),
      ],
    );
  }
}

/// One label/value line. Wraps rather than clips: Khmer runs longer and
/// taller than English.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rh(6)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: context.rr(18), color: colors.textSecondary),
          SizedBox(width: context.rw(10)),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: context.rsp(13.5),
                color: scheme.onSurface,
                height: 1.3,
              ),
            ),
          ),
          SizedBox(width: context.rw(12)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: context.rsp(13.5),
                fontWeight: muted ? FontWeight.w500 : FontWeight.w700,
                color: muted ? colors.textSecondary : scheme.onSurface,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
