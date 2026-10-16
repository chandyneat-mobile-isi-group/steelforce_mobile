import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/notification/domain/entities/notification_action.dart';
import 'package:steelforce/features/notification/domain/entities/notification_message.dart';
import 'package:steelforce/features/notification/domain/entities/notification_query.dart';
import 'package:steelforce/features/notification/presentation/bloc/notification_inbox_cubit.dart';
import 'package:steelforce/features/notification/presentation/bloc/notification_inbox_state.dart';
import 'package:steelforce/features/notification/presentation/bloc/push_permission_cubit.dart';
import 'package:steelforce/features/notification/presentation/widgets/notification_category_style.dart';
import 'package:steelforce/features/notification/presentation/widgets/notification_tile.dart';
import 'package:steelforce/features/notification/presentation/widgets/push_permission_card.dart';

/// The inbox body, shared by the bell sheet and the full-screen route.
///
/// One widget for both because they are the same surface at two sizes — a sheet
/// on a phone tap, a screen when a deep link opens `app://notifications`. Two
/// copies would drift, and the swipe rules and empty states are exactly the
/// things that would drift silently.
///
/// Expects both a [NotificationInboxCubit] — already started — and a
/// [PushPermissionCubit] above it. The permission cubit is required rather than
/// optional because §14 puts the explainer and the declined banner *here*,
/// beside the notifications they are about, and a surface that silently omitted
/// them would be the one place a rep never learns why nothing is arriving.
class NotificationInboxView extends StatefulWidget {
  const NotificationInboxView({
    super.key,
    this.onOpenNotification,
    this.onOpenSettings,
  });

  /// Called when a row is tapped, after it has been marked read.
  ///
  /// Navigation lives with the caller: this widget does not know whether it is
  /// inside a sheet that must pop first or a screen that can push.
  final void Function(NotificationMessage notification)? onOpenNotification;

  /// Opens the OS notification settings for this app, for the declined banner.
  final VoidCallback? onOpenSettings;

  @override
  State<NotificationInboxView> createState() => _NotificationInboxViewState();
}

class _NotificationInboxViewState extends State<NotificationInboxView> {
  /// Which bucket the rep is filtering by, or null for everything.
  ///
  /// Held here rather than pushed into the cubit's query: the query carries a
  /// single wire category down to the repository and the remote, and a group is
  /// several of them. Filtering the loaded list keeps the whole change in
  /// presentation — no repository, no data source, no backend.
  NotificationFilterGroup? _group;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NotificationInboxCubit, NotificationInboxState>(
      // Only surface an error the rep asked for. A background catch-up failure
      // sets `status` and nothing else — interrupting somebody to report a sync
      // they did not request is noise, and offline is a normal state (ADR-002
      // §4).
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage &&
          current.errorMessage != null,
      listener: (context, state) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(state.errorMessage!)),
        );
        context.read<NotificationInboxCubit>().acknowledgeError();
      },
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CategoryChips(
              selected: _group,
              // Tapping the active chip clears it, matching the affordance the
              // depot filter sheet uses so the gesture means one thing
              // app-wide.
              onSelect: (group) =>
                  setState(() => _group = _group == group ? null : group),
              onClear: () => setState(() => _group = null),
            ),
            SizedBox(height: context.rh(8)),
            Expanded(
                child: _Body(
                    state: state,
                    items: _group == null
                        ? state.items
                        : state.items
                            .where((n) => _group!.contains(n.category))
                            .toList(growable: false),
                    onOpen: widget.onOpenNotification,
                    onOpenSettings: widget.onOpenSettings)),
          ],
        );
      },
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.selected,
    required this.onSelect,
    required this.onClear,
  });

  final NotificationFilterGroup? selected;
  final ValueChanged<NotificationFilterGroup> onSelect;

  /// Clears the group. Separate from [onSelect] because "All" is the absence
  /// of a group rather than one of them.
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.rh(38),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _Chip(
            label: 'notifications.filter.all'.tr,
            selected: selected == null,
            // Clears the *group*, not the cubit's query. The query is never
            // narrowed now — grouping happens over the loaded list — so
            // calling setCategory here would look right and do nothing.
            onTap: onClear,
          ),
          for (final group in NotificationFilterGroup.values)
            _Chip(
              label: group.label,
              color: group.color(context),
              selected: selected == group,
              onTap: () => onSelect(group),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;

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

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.items,
    required this.onOpen,
    required this.onOpenSettings,
  });

  final NotificationInboxState state;

  /// The rows to draw — [state.items] narrowed to the selected filter group.
  /// Passed in rather than read off `state` so the filter stays a presentation
  /// concern and `_Body` has one source of rows.
  final List<NotificationMessage> items;
  final void Function(NotificationMessage notification)? onOpen;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PushPermissionCubit, PushPermissionState>(
      builder: (context, permission) => _build(context, permission),
    );
  }

  Widget _build(BuildContext context, PushPermissionState permission) {
    final cubit = context.read<NotificationInboxCubit>();

    // The permission surfaces sit above the list rather than on their own
    // screen, which is what §14 describes: the explainer arrives in context,
    // beside the notifications it is asking to accelerate.
    final permissionHeader = _permissionHeader(context, permission);

    if (!state.loadedOnce) {
      return Center(
        child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary),
      );
    }

    return RefreshIndicator(
      onRefresh: cubit.refresh,
      child: items.isEmpty
          // `AlwaysScrollableScrollPhysics` is what keeps pull-to-refresh
          // working on an empty inbox — which is precisely when a rep is most
          // likely to pull, wondering where their route went.
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (permissionHeader != null) permissionHeader,
                SizedBox(height: context.rh(80)),
                _EmptyState(scope: state.query.scope),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              // +1 when a permission surface is present, so it scrolls with the
              // list instead of pinning and stealing height from it.
              itemCount: items.length + (permissionHeader == null ? 0 : 1),
              separatorBuilder: (_, __) => SizedBox(height: context.rh(2)),
              itemBuilder: (context, index) {
                if (permissionHeader != null) {
                  if (index == 0) return permissionHeader;
                  index -= 1;
                }
                final notification = items[index];
                return _SwipeableTile(
                  notification: notification,
                  actionInFlight: state.actionInFlightId == notification.id,
                  onOpen: onOpen,
                );
              },
            ),
    );
  }

  /// The §14 explainer, or the declined banner, or nothing.
  ///
  /// Resolved through `context.read` inside a guard rather than
  /// `context.watch<PushPermissionCubit?>()`: provider treats `T?` as a
  /// *different* type from `T`, so a nullable lookup never finds a
  /// `BlocProvider<PushPermissionCubit>` and would throw at runtime while
  /// analysing perfectly. Both call sites provide the cubit, so this is a plain
  /// lookup wrapped in a `BlocBuilder` for the rebuild.
  Widget? _permissionHeader(BuildContext context, PushPermissionState state) {
    if (state.showExplainer) {
      final permission = context.read<PushPermissionCubit>();
      return PushPermissionCard(
        onEnable: permission.accept,
        onDefer: permission.defer,
        busy: state.requesting,
      );
    }
    if (state.showDeclinedBanner) {
      return PushPermissionDeclinedBanner(onOpenSettings: onOpenSettings);
    }
    return null;
  }
}

/// A row, swipeable to dismiss where the spec allows it.
///
/// §5.4: an item with `requires_ack` **cannot be dismissed** — the server
/// answers 409 — so those rows are not wrapped in a [Dismissible] at all. A
/// swipe that animates the row away and then springs it back is a worse
/// explanation than a swipe that simply does not engage.
class _SwipeableTile extends StatelessWidget {
  const _SwipeableTile({
    required this.notification,
    required this.actionInFlight,
    required this.onOpen,
  });

  final NotificationMessage notification;
  final bool actionInFlight;
  final void Function(NotificationMessage notification)? onOpen;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NotificationInboxCubit>();

    final tile = NotificationTile(
      notification: notification,
      actionInFlight: actionInFlight,
      onTap: () {
        // Read, then navigate. Reading is not acting (§8.3): opening the record
        // clears the unread dot and nothing more, so a route assignment still
        // counts against the badge until it is acknowledged.
        cubit.open(notification);
        onOpen?.call(notification);
      },
      onAction: (action) => _runAction(context, cubit, action),
    );

    if (!notification.isDismissible) return tile;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: _DismissBackground(),
      onDismissed: (_) => cubit.dismiss(notification),
      child: tile,
    );
  }

  /// Runs an inline action, confirming first when it is destructive.
  ///
  /// §12: `destructive: true` must be confirmed. Rejecting a quotation from a
  /// lock screen is one mis-tap from a decision nobody meant to make, and the
  /// cubit refuses an unconfirmed destructive action outright rather than
  /// trusting every call site to remember.
  Future<void> _runAction(
    BuildContext context,
    NotificationInboxCubit cubit,
    NotificationAction action,
  ) async {
    var confirmed = true;

    if (action.destructive) {
      confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text('notifications.confirm.title'.tr),
              content: Text('notifications.confirm.body'
                  .trParams({'action': action.label})),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text('common.cancel'.tr),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  ),
                  child: Text(action.label),
                ),
              ],
            ),
          ) ??
          false;
    }

    if (!confirmed) return;
    // The dialog awaited above may have outlived this element.
    if (!context.mounted) return;
    await cubit.runAction(notification, action, confirmed: confirmed);
  }
}

class _DismissBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerRight,
      padding: EdgeInsets.only(right: context.rw(20)),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.archive_rounded,
          color: scheme.error, size: context.rr(20)),
    );
  }
}

/// Per-tab empty copy.
///
/// Three messages rather than one, because "nothing here" means three different
/// things: an inbox with nothing new, no outstanding work (which is *good news*
/// and should read that way), and an empty history.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.scope});

  final NotificationScope scope;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final (icon, key) = switch (scope) {
      NotificationScope.inbox => (Icons.inbox_rounded, 'notifications.empty'),
      NotificationScope.actionNeeded => (
          Icons.task_alt_rounded,
          'notifications.empty_action_needed'
        ),
      NotificationScope.history => (
          Icons.history_rounded,
          'notifications.empty_history'
        ),
    };

    return Column(
      children: [
        Icon(icon, size: context.rr(40), color: colors.iconMuted),
        SizedBox(height: context.rh(12)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.rw(24)),
          child: Text(
            key.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textHint,
              fontSize: context.rsp(13),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
