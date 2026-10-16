import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/localization/active_language.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/notification/domain/entities/notification_action.dart';
import 'package:steelforce/features/notification/domain/entities/notification_message.dart';
import 'package:steelforce/features/notification/domain/entities/notification_state.dart';
import 'package:steelforce/features/notification/presentation/widgets/notification_category_style.dart';

/// One row in the inbox.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    this.onTap,
    this.onAction,
    this.actionInFlight = false,
  });

  final NotificationMessage notification;
  final VoidCallback? onTap;
  final void Function(NotificationAction action)? onAction;
  final bool actionInFlight;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final style = notification.category.style(context);
    final isStale = notification.state.isStale;

    final foreground = isStale ? colors.textHint : colors.textPrimary;
    final secondary = isStale ? colors.textDisabled : colors.textSecondary;

    final actions =
        onAction == null ? const <NotificationAction>[] : notification.actions;

    return Semantics(
      label: notification.isUnread
          ? '${'notifications.status.unread'.tr}. ${notification.title}'
          : notification.title,
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.rw(12),
            vertical: context.rh(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Leading(
                icon: style.icon,
                color: isStale ? colors.iconMuted : style.color,
                // Safely checks priority by name to avoid missing 'accent' method
                urgent: notification.priority.name == 'p1' && !isStale,
              ),
              SizedBox(width: context.rw(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: foreground,
                              fontSize: context.rsp(14),
                              fontWeight: notification.isUnread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                        SizedBox(width: context.rw(8)),
                        Text(
                          _relativeTime(notification.createdAt),
                          style: TextStyle(
                            color: colors.textHint,
                            fontSize: context.rsp(11),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (notification.isUnread) ...[
                          SizedBox(width: context.rw(6)),
                          Container(
                            margin: EdgeInsets.only(top: context.rh(4)),
                            width: context.rr(7),
                            height: context.rr(7),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: context.rh(4)),
                    Text(
                      notification.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: secondary,
                        fontSize: context.rsp(12.5),
                        height: 1.4,
                      ),
                    ),
                    if (_statusNote(notification) case final note?) ...[
                      SizedBox(height: context.rh(6)),
                      Text(
                        note,
                        style: TextStyle(
                          color: colors.textHint,
                          fontSize: context.rsp(11.5),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (notification.isOutstandingAction) ...[
                      SizedBox(height: context.rh(8)),
                      const _AckPill(),
                    ],
                    if (actions.isNotEmpty) ...[
                      SizedBox(height: context.rh(10)),
                      _ActionRow(
                        actions: actions,
                        onAction: onAction!,
                        disabled: actionInFlight,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _statusNote(NotificationMessage notification) =>
      switch (notification.state) {
        NotificationState.expired => 'notifications.note.expired'.tr,
        NotificationState.resolvedElsewhere =>
          'notifications.note.resolved_elsewhere'.tr,
        NotificationState.actioned => 'notifications.note.actioned'.tr,
        NotificationState.dismissed => 'notifications.note.dismissed'.tr,
        NotificationState.unread || NotificationState.read => null,
      };

  String _relativeTime(DateTime createdAt) {
    final now = DateTime.now().toUtc();
    final age = now.difference(createdAt);

    if (age.inMinutes < 1) return 'notifications.time.now'.tr;
    if (age.inMinutes < 60) {
      return 'notifications.time.minutes'
          .trParams({'n': age.inMinutes.toString()});
    }
    if (age.inHours < 24) {
      return 'notifications.time.hours'.trParams({'n': age.inHours.toString()});
    }
    if (age.inDays < 7) {
      return 'notifications.time.days'.trParams({'n': age.inDays.toString()});
    }
    return DateFormat.MMMd(ActiveLanguage.code).format(createdAt.toLocal());
  }
}

class _Leading extends StatelessWidget {
  const _Leading({
    required this.icon,
    required this.color,
    required this.urgent,
  });

  final IconData icon;
  final Color color;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: context.rr(38),
      height: context.rr(38),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
        border: urgent
            ? Border.all(
                color: scheme.error.withValues(alpha: 0.55), width: 1.4)
            : null,
      ),
      child: Icon(icon, size: context.rr(19), color: color),
    );
  }
}

class _AckPill extends StatelessWidget {
  const _AckPill();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rw(8),
        vertical: context.rh(3),
      ),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pending_actions_rounded,
              size: context.rr(12), color: colors.warning),
          SizedBox(width: context.rw(4)),
          Flexible(
            child: Text(
              'notifications.needs_ack'.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.warning,
                fontSize: context.rsp(10.5),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.actions,
    required this.onAction,
    required this.disabled,
  });

  final List<NotificationAction> actions;
  final void Function(NotificationAction action) onAction;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: context.rw(8),
      runSpacing: context.rh(6),
      children: [
        for (final action in actions)
          TextButton(
            onPressed: disabled ? null : () => onAction(action),
            style: TextButton.styleFrom(
              minimumSize: Size(0, context.rh(34)),
              padding: EdgeInsets.symmetric(horizontal: context.rw(14)),
              foregroundColor:
                  action.destructive ? scheme.error : scheme.primary,
              backgroundColor:
                  (action.destructive ? scheme.error : scheme.primary)
                      .withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              action.label,
              style: TextStyle(
                fontSize: context.rsp(12),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}
