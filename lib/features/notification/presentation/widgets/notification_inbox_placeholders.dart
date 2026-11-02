import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/notification/domain/entities/notification_query.dart';

/// "Nothing here", worded per list: no notifications at all reads differently
/// from no unread ones, which is good news.
class InboxEmpty extends StatelessWidget {
  const InboxEmpty({super.key, required this.scope});

  final NotificationScope scope;

  @override
  Widget build(BuildContext context) {
    final (icon, key) = switch (scope) {
      NotificationScope.inbox => (Icons.inbox_rounded, 'notifications.empty'),
      NotificationScope.unread => (
          Icons.mark_email_read_rounded,
          'notifications.empty_unread'
        ),
      NotificationScope.actionNeeded => (
          Icons.task_alt_rounded,
          'notifications.empty_action_needed'
        ),
      NotificationScope.history => (
          Icons.history_rounded,
          'notifications.empty_history'
        ),
    };
    return _Message(icon: icon, text: key.tr);
  }
}

/// Nothing stored and the refresh failed — not the same as an empty inbox.
class InboxLoadFailed extends StatelessWidget {
  const InboxLoadFailed({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Message(
      icon: Icons.cloud_off_rounded,
      text: 'notifications.load_failed'.tr,
      action: OutlinedButton.icon(
        onPressed: onRetry,
        icon: Icon(Icons.refresh_rounded, size: context.rr(18)),
        label: Text('common.retry'.tr),
        style: OutlinedButton.styleFrom(minimumSize: Size(0, context.rh(44))),
      ),
    );
  }
}

/// An older page failed: a quiet retry under the rows already shown.
class InboxPagingFailed extends StatelessWidget {
  const InboxPagingFailed({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onRetry,
        icon: Icon(Icons.refresh_rounded, size: context.rr(18)),
        label: Text('common.retry'.tr),
        style: TextButton.styleFrom(minimumSize: Size(0, context.rh(44))),
      ),
    );
  }
}

class InboxLoadingMore extends StatelessWidget {
  const InboxLoadingMore({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rh(16)),
      child: Center(
        child: SizedBox.square(
          dimension: context.rr(22),
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class InboxEndOfList extends StatelessWidget {
  const InboxEndOfList({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rh(16)),
      child: Text(
        'notifications.end_of_list'.tr,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: context.appColors.textHint,
          fontSize: context.rsp(12),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          context.rw(24), context.rh(72), context.rw(24), context.rh(24)),
      child: Column(
        children: [
          Icon(icon, size: context.rr(40), color: colors.iconMuted),
          SizedBox(height: context.rh(12)),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textHint,
              fontSize: context.rsp(13),
              height: 1.4,
            ),
          ),
          if (action != null) ...[
            SizedBox(height: context.rh(16)),
            action!,
          ],
        ],
      ),
    );
  }
}
