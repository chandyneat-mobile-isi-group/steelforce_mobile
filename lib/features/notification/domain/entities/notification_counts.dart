import 'package:equatable/equatable.dart';
import 'package:steelforce/features/notification/domain/entities/notification_category.dart';

/// The server's authoritative badge figures
/// (`docs/feature/notification/README.md` §7).
///
/// ## Reconcile, never increment
///
/// These are re-read on every foreground and after every sync rather than
/// adjusted locally. A local counter drifts the first time a push is dropped —
/// which §1 establishes as routine, not exceptional — and a badge nobody trusts
/// is a badge everybody ignores.
///
/// The one exception is the deliberately-optimistic local delta applied while a
/// `PATCH /read` is still in flight, so the number moves the instant the rep
/// taps. That is corrected by the next reconcile, which is why
/// [NotificationCounts.withUnread] clamps rather than trusting arithmetic.
class NotificationCounts extends Equatable {
  const NotificationCounts({
    this.unread = 0,
    this.actionRequired = 0,
    this.byCategory = const {},
    this.syncTimestamp,
  });

  /// Everything at zero — the correct state for a guest, and the correct
  /// starting state before the first reconcile. Never a loading placeholder:
  /// showing a stale badge is worse than showing none.
  static const NotificationCounts empty = NotificationCounts();

  /// Drives the bell / inbox tab badge.
  final int unread;

  /// Drives the **app-icon** badge, and nothing else drives it (§5.4).
  final int actionRequired;

  final Map<NotificationCategory, int> byCategory;

  /// The server's clock when the count was taken. Not a sync cursor — the
  /// inbox cursor comes from the list call's `metadata.syncTimestamp` (§6.1).
  final DateTime? syncTimestamp;

  bool get hasUnread => unread > 0;
  bool get hasOutstandingAction => actionRequired > 0;

  int forCategory(NotificationCategory category) => byCategory[category] ?? 0;

  /// [unread] adjusted by [delta], clamped at zero.
  ///
  /// Used for the optimistic tick when a rep opens an item. The clamp is not
  /// defensive padding: two surfaces can mark the same item read (the sheet and
  /// a deep-linked screen), and an unclamped decrement would render a negative
  /// badge before the next reconcile arrives to fix it.
  NotificationCounts withUnread(int delta) => NotificationCounts(
        unread: (unread + delta).clamp(0, 1 << 30),
        actionRequired: actionRequired,
        byCategory: byCategory,
        syncTimestamp: syncTimestamp,
      );

  @override
  List<Object?> get props =>
      [unread, actionRequired, byCategory, syncTimestamp];
}
