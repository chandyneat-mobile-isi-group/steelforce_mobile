import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/domain/entities/pending_depot_registration.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_registration_queue_cubit.dart';
import 'package:steelforce/features/depots/presentation/widgets/sync/depot_registration_actions.dart';
import 'package:steelforce/features/depots/presentation/widgets/sync/depot_registration_status_view.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';

/// Opens what one queued registration holds, over the Sync Center. [context]
/// must be under the [DepotRegistrationQueueCubit].
Future<void> showPendingDepotRegistrationDetails(
  BuildContext context,
  String id,
) {
  final cubit = context.read<DepotRegistrationQueueCubit>();
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: PendingDepotRegistrationDetailsSheet(id: id),
    ),
  );
}

/// One registration in the outbox: the shop as the rep submitted it, its
/// status and what that means, when it was saved and last tried — plus the
/// card's own actions.
///
/// Reads the row from the cubit by id so it stays current, and closes itself
/// once the row leaves the outbox (sent, discarded, or reopened to fix).
class PendingDepotRegistrationDetailsSheet extends StatefulWidget {
  const PendingDepotRegistrationDetailsSheet({super.key, required this.id});

  final String id;

  @override
  State<PendingDepotRegistrationDetailsSheet> createState() =>
      _PendingDepotRegistrationDetailsSheetState();
}

class _PendingDepotRegistrationDetailsSheetState
    extends State<PendingDepotRegistrationDetailsSheet> {
  bool _closing = false;

  PendingDepotRegistration? _find(DepotRegistrationQueueState state) {
    for (final item in state.items) {
      if (item.id == widget.id) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DepotRegistrationQueueCubit,
        DepotRegistrationQueueState>(
      listener: (_, state) {
        if (_closing || !state.loaded || _find(state) != null) return;
        _closing = true;
        Navigator.of(context).maybePop();
      },
      builder: (context, state) {
        final item = _find(state);
        if (item == null) return const SizedBox.shrink();
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            context.rw(16),
            context.rh(4),
            context.rw(16),
            context.rh(16),
          ),
          child: _Details(item: item),
        );
      },
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.item});
  final PendingDepotRegistration item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final (label, color) =
        DepotRegistrationStatusView.chip(context, item.status);
    final time = DateFormat('d MMM, HH:mm', context.languageCode);
    final lat = item.latitude, lng = item.longitude;
    final kh = item.depotNameKh;
    final number = item.depotNumber;
    final lastAttempt = item.lastAttemptAt;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'sync_center.depot.detail.title'.tr,
          style: TextStyle(
            fontSize: context.rsp(12),
            color: colors.textSecondary,
          ),
        ),
        SizedBox(height: context.rh(4)),
        Text(
          item.depotName.isEmpty
              ? 'sync_center.depot.unnamed'.tr
              : item.depotName,
          style: TextStyle(
            fontSize: context.rsp(17),
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        if (kh != null && kh != item.depotName) ...[
          SizedBox(height: context.rh(2)),
          Text(
            kh,
            style: TextStyle(
              fontSize: context.rsp(14),
              color: colors.textSecondary,
            ),
          ),
        ],
        SizedBox(height: context.rh(12)),
        Container(
          padding: EdgeInsets.all(context.rr(12)),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                DepotRegistrationStatusView.icon(item.status),
                size: context.rr(18),
                color: color,
              ),
              SizedBox(width: context.rw(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: context.rsp(13),
                      ),
                    ),
                    SizedBox(height: context.rh(4)),
                    Text(
                      DepotRegistrationStatusView.explanation(item),
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: context.rsp(12.5),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: context.rh(12)),
        if (item.phone != null)
          _Row(
            icon: Icons.phone_outlined,
            label: 'sync_center.depot.detail.phone'.tr,
            value: item.phone!,
          ),
        if (item.address != null)
          _Row(
            icon: Icons.home_outlined,
            label: 'sync_center.depot.detail.address'.tr,
            value: item.address!,
          ),
        if (lat != null && lng != null)
          _Row(
            icon: Icons.my_location_rounded,
            label: 'sync_center.depot.detail.location'.tr,
            value: '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
          ),
        if (number != null && number.isNotEmpty)
          _Row(
            icon: Icons.tag_rounded,
            label: 'sync_center.depot.detail.depot_number'.tr,
            value: number,
          ),
        if (item.photosOutstanding > 0)
          _Row(
            icon: Icons.photo_library_outlined,
            label: 'sync_center.depot.detail.photos'.tr,
            value: '${item.photosOutstanding}',
          ),
        _Row(
          icon: Icons.schedule_rounded,
          label: 'sync_center.depot.detail.saved_at'.tr,
          value: time.format(item.createdAt.toLocal()),
        ),
        if (lastAttempt != null)
          _Row(
            icon: Icons.history_rounded,
            label: 'sync_center.depot.detail.last_attempt'.tr,
            value: time.format(lastAttempt.toLocal()),
          ),
        if (item.attempts > 0)
          _Row(
            icon: Icons.repeat_rounded,
            label: 'sync_center.depot.detail.attempts'.tr,
            value: '${item.attempts}',
          ),
        SizedBox(height: context.rh(16)),
        DepotRegistrationActions(item: item),
      ],
    );
  }
}

/// One label/value line. Wraps rather than clips: Khmer runs longer and
/// taller than English, and an address can be long.
class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

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
                color: colors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
          SizedBox(width: context.rw(12)),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: context.rsp(13.5),
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
