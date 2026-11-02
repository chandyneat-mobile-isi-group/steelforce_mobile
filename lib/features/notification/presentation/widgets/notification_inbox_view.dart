import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/notification/domain/entities/notification_message.dart';
import 'package:steelforce/features/notification/domain/entities/notification_query.dart';
import 'package:steelforce/features/notification/presentation/bloc/notification_inbox_cubit.dart';
import 'package:steelforce/features/notification/presentation/bloc/notification_inbox_state.dart';
import 'package:steelforce/features/notification/presentation/bloc/push_permission_cubit.dart';
import 'package:steelforce/features/notification/presentation/widgets/notification_inbox_list.dart';

/// The inbox body, shared by the bell sheet and the full-screen route: the
/// All / Unread switch, Mark all as read, and the list.
///
/// Expects a started [NotificationInboxCubit] and a [PushPermissionCubit]
/// above it — the permission explainer and declined banner sit here, beside
/// the notifications they are about (§14).
class NotificationInboxView extends StatelessWidget {
  const NotificationInboxView({
    super.key,
    this.onOpenNotification,
    this.onOpenSettings,
  });

  /// Called when a row is tapped, after it has been marked read. Navigation
  /// lives with the caller: only it knows whether a sheet must pop first.
  final void Function(NotificationMessage notification)? onOpenNotification;

  /// Opens the OS notification settings, for the declined banner.
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NotificationInboxCubit, NotificationInboxState>(
      // Only what the rep asked for is reported: a background catch-up failing
      // sets `status` and nothing else (ADR-002 §4).
      listenWhen: (previous, current) =>
          (current.errorMessage != null &&
              previous.errorMessage != current.errorMessage) ||
          (current.notice != null && previous.notice != current.notice),
      listener: (context, state) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
              SnackBar(content: Text(state.errorMessage ?? state.notice!)));
        context.read<NotificationInboxCubit>().acknowledgeError();
      },
      builder: (context, state) {
        final cubit = context.read<NotificationInboxCubit>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ScopeChip(
                  label: 'notifications.filter.all'.tr,
                  selected: state.query.scope == NotificationScope.inbox,
                  onTap: () => cubit.setScope(NotificationScope.inbox),
                ),
                _ScopeChip(
                  label: 'notifications.filter.unread'.tr,
                  selected: state.query.scope == NotificationScope.unread,
                  onTap: () => cubit.setScope(NotificationScope.unread),
                ),
                const Spacer(),
                if (state.items.any((n) => n.isUnread))
                  // Flexible: beside two chips on a narrow phone — or in
                  // Khmer — the label gives way rather than overflowing.
                  Flexible(
                    child: Tooltip(
                      message: 'notifications.mark_all_read'.tr,
                      child: TextButton(
                        onPressed: cubit.markAllRead,
                        style: TextButton.styleFrom(
                          minimumSize: Size(0, context.rh(40)),
                          padding:
                              EdgeInsets.symmetric(horizontal: context.rw(6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.done_all_rounded, size: context.rr(16)),
                            SizedBox(width: context.rw(4)),
                            Flexible(
                              child: Text(
                                'notifications.mark_all_read'.tr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: context.rsp(12),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: context.rh(8)),
            Expanded(
              child: BlocBuilder<PushPermissionCubit, PushPermissionState>(
                builder: (context, permission) => NotificationInboxList(
                  state: state,
                  permission: permission,
                  onOpen: onOpenNotification,
                  onOpenSettings: onOpenSettings,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: EdgeInsets.only(right: context.rw(8)),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: accent.withValues(alpha: 0.16),
        labelStyle: TextStyle(
          fontSize: context.rsp(12),
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          color: selected ? accent : context.appColors.textSecondary,
        ),
        side: BorderSide(
          color: selected
              ? accent.withValues(alpha: 0.5)
              : context.appColors.border,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: context.rw(8),
          vertical: context.rh(6),
        ),
      ),
    );
  }
}
