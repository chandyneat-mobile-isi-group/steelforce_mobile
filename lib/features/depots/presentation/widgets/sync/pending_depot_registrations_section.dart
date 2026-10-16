import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/domain/entities/pending_depot_registration.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_registration_queue_cubit.dart';
import 'package:steelforce/features/depots/presentation/widgets/sync/depot_registration_actions.dart';
import 'package:steelforce/features/depots/presentation/widgets/sync/depot_registration_status_view.dart';
import 'package:steelforce/features/depots/presentation/widgets/sync/pending_depot_registration_details_sheet.dart';
import 'package:steelforce/routes/app_routes.dart';

/// Depot registrations in the outbox, for the Sync Center. Tapping a card
/// opens what it holds; each card carries its actions.
///
/// Renders nothing when the outbox is empty, so the sheet's own empty state
/// stays the single "everything is synced" message.
class PendingDepotRegistrationsSection extends StatelessWidget {
  const PendingDepotRegistrationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DepotRegistrationQueueCubit,
        DepotRegistrationQueueState>(
      listenWhen: (a, b) => b.messageKey != null,
      // Through the root messenger, not `ScaffoldMessenger.of(context)`: this
      // fires from a long-lived cubit and can land while the Sync Center is
      // closing or the app is restarting, when a lookup from here throws.
      listener: (_, state) => rootMessengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text(state.messageKey!.tr))),
      builder: (context, state) {
        if (state.items.isEmpty) return const SizedBox.shrink();
        // Items arrive oldest first, which is the order they are sent in.
        final waiting = [
          for (final item in state.items)
            if (item.status == DepotRegistrationQueueStatus.queued) item.id,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'sync_center.depot.section_title'.tr,
              style: TextStyle(
                fontSize: context.rsp(13),
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: context.rh(8)),
            for (final item in state.items) ...[
              _RegistrationTile(
                item: item,
                position: waiting.length > 1 ? waiting.indexOf(item.id) + 1 : 0,
                waitingTotal: waiting.length,
              ),
              SizedBox(height: context.rh(10)),
            ],
          ],
        );
      },
    );
  }
}

class _RegistrationTile extends StatelessWidget {
  const _RegistrationTile({
    required this.item,
    this.position = 0,
    this.waitingTotal = 0,
  });
  final PendingDepotRegistration item;

  /// This row's place among those waiting to send, from 1; 0 hides it. Shown
  /// only when several wait, so a rep sees why the third has not gone yet.
  final int position;
  final int waitingTotal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final (label, color) =
        DepotRegistrationStatusView.chip(context, item.status);
    final name = item.depotName.isEmpty
        ? 'sync_center.depot.unnamed'.tr
        : item.depotName;

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
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
              label: name,
              hint: 'common.view_details'.tr,
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () =>
                    showPendingDepotRegistrationDetails(context, item.id),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            size: context.rr(16),
                            color: colors.textSecondary,
                          ),
                          SizedBox(width: context.rw(6)),
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: context.rsp(13.5),
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          _Chip(label: label, color: color),
                          SizedBox(width: context.rw(2)),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: context.rr(18),
                            color: colors.textSecondary,
                          ),
                        ],
                      ),
                      SizedBox(height: context.rh(6)),
                      _InfoLine(
                        icon: DepotRegistrationStatusView.icon(item.status),
                        color:
                            item.status.needsRep ? color : colors.textSecondary,
                        text: DepotRegistrationStatusView.explanation(item),
                      ),
                      if (position > 0) ...[
                        SizedBox(height: context.rh(4)),
                        _InfoLine(
                          icon: Icons.format_list_numbered_rounded,
                          color: colors.textSecondary,
                          text: 'sync_center.depot.queue_position'.trParams({
                            'position': position,
                            'total': waitingTotal,
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: context.rh(8)),
            DepotRegistrationActions(item: item),
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
