import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/notifications/notification_deep_link.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/notification/domain/entities/notification_message.dart';
import 'package:steelforce/features/notification/presentation/bloc/notification_inbox_cubit.dart';
import 'package:steelforce/features/notification/presentation/bloc/notification_inbox_state.dart';
import 'package:steelforce/features/notification/presentation/bloc/push_permission_cubit.dart';
import 'package:steelforce/features/notification/presentation/widgets/notification_inbox_placeholders.dart';
import 'package:steelforce/features/notification/presentation/widgets/notification_tile.dart';
import 'package:steelforce/features/notification/presentation/widgets/push_permission_card.dart';

/// The rows, with pull-to-refresh and infinite scroll: nearing the end asks
/// the cubit for the next older page, which ignores the ask while one loads.
class NotificationInboxList extends StatelessWidget {
  const NotificationInboxList({
    super.key,
    required this.state,
    required this.permission,
    this.onOpen,
    this.onOpenSettings,
  });

  /// How close to the end, in pixels, the next page starts loading.
  static const double loadMoreExtent = 320;

  final NotificationInboxState state;
  final PushPermissionState permission;
  final void Function(NotificationMessage notification)? onOpen;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    if (!state.loadedOnce) {
      return Center(
        child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary),
      );
    }

    final cubit = context.read<NotificationInboxCubit>();
    final header = _permissionHeader(context);
    final items = state.items;

    return RefreshIndicator(
      onRefresh: cubit.refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (scroll) {
          if (scroll.metrics.extentAfter < loadMoreExtent) {
            cubit.loadMore();
          }
          return false;
        },
        child: ListView.builder(
          // Keeps pull-to-refresh working on an empty or short list.
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: items.length + (header == null ? 0 : 1) + 1,
          itemBuilder: (context, index) {
            if (header != null) {
              if (index == 0) return header;
              index -= 1;
            }
            if (index == items.length) return _footer(context, cubit);
            final notification = items[index];
            return Padding(
              padding: EdgeInsets.only(bottom: context.rh(2)),
              child: NotificationTile(
                key: ValueKey(notification.id),
                notification: notification,
                onTap: () => _open(context, cubit, notification),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Marks [notification] read, then hands it to [onOpen] — but only when its
  /// link names a screen this build has. No link: reading it was the whole
  /// action. An unknown one: the rep stays here and is told why nothing
  /// opened, rather than being dropped on a fallback screen.
  void _open(BuildContext context, NotificationInboxCubit cubit,
      NotificationMessage notification) {
    cubit.open(notification);
    final link = notification.deepLink;
    if (link == null) return;
    if (!NotificationDeepLink.isRoutable(link)) {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text('notifications.link_unsupported'.tr)));
      return;
    }
    onOpen?.call(notification);
  }

  /// Under the last row: the empty or failed state when there are no rows,
  /// otherwise the next-page spinner or the end-of-list note.
  Widget _footer(BuildContext context, NotificationInboxCubit cubit) {
    if (state.failedEmpty) return InboxLoadFailed(onRetry: cubit.refresh);
    // The first page is still on its way: not "nothing here" yet.
    if (state.loadingMore || (state.isEmpty && state.isSyncing)) {
      return const InboxLoadingMore();
    }
    // A list too short to scroll never sends a scroll notification, so the
    // footer coming into view asks for the next page itself — an empty local
    // list may still have older rows on the server.
    final canPage = state.hasMore && !state.pagingFailed && !state.isSyncing;
    if (canPage) _afterFrame(cubit.loadMore);
    if (state.isEmpty) return InboxEmpty(scope: state.query.scope);
    if (state.pagingFailed) {
      return InboxPagingFailed(onRetry: () => cubit.loadMore(retry: true));
    }
    if (!state.hasMore) return const InboxEndOfList();
    return SizedBox(height: context.rh(24));
  }

  static void _afterFrame(VoidCallback action) =>
      WidgetsBinding.instance.addPostFrameCallback((_) => action());

  /// The §14 explainer, or the declined banner, or nothing.
  Widget? _permissionHeader(BuildContext context) {
    if (permission.showExplainer) {
      final cubit = context.read<PushPermissionCubit>();
      return PushPermissionCard(
        onEnable: cubit.accept,
        onDefer: cubit.defer,
        busy: permission.requesting,
      );
    }
    if (permission.showDeclinedBanner) {
      return PushPermissionDeclinedBanner(onOpenSettings: onOpenSettings);
    }
    return null;
  }
}
