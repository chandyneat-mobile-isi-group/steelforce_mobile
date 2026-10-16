import 'package:equatable/equatable.dart';
import 'package:steelforce/features/notification/domain/entities/notification_category.dart';
import 'package:steelforce/features/notification/domain/entities/notification_state.dart';

/// Which slice of the inbox a surface is showing
/// (`docs/feature/notification/README.md` §6).
///
/// Modelled as three named tabs rather than a free-form state filter because
/// that is what the spec's UI actually asks for, and because two of them are
/// not expressible as a single `state` value: **Action needed** is
/// `actionRequired=true` across several states, and **History** is the union of
/// every closed state.
enum NotificationScope {
  /// Everything currently live — unread and read.
  inbox,

  /// `actionRequired=true`. Pinned to the top, and its items are not
  /// swipeable (§5.4).
  actionNeeded,

  /// Dismissed, expired, actioned and resolved-elsewhere. §5.1: nothing is ever
  /// deleted, so this tab is the whole reason those states are kept.
  history,
}

/// A filter over the local inbox mirror.
///
/// Deliberately expressed against **local** storage, not as query parameters.
/// The catch-up call pulls everything since the cursor and the device filters
/// what it already holds, so switching a filter chip never needs a network
/// round trip and works identically offline — which is the whole point of
/// treating the inbox as the system of record (§1).
class NotificationQuery extends Equatable {
  const NotificationQuery({
    this.scope = NotificationScope.inbox,
    this.category,
    this.limit = defaultLimit,
  });

  /// One screenful plus enough headroom that the first scroll does not hit the
  /// end. Not a server page size — the local mirror holds everything already
  /// synced, and this only bounds how much is rendered at once.
  static const int defaultLimit = 60;

  final NotificationScope scope;

  /// Null means every category. A concrete value backs the filter chips.
  final NotificationCategory? category;

  final int limit;

  /// The states this scope admits.
  ///
  /// Returned as a set rather than branched on at the call site so the DAO, the
  /// cubit and any future surface cannot disagree about what "history" means.
  Set<NotificationState> get states => switch (scope) {
        NotificationScope.inbox => const {
            NotificationState.unread,
            NotificationState.read,
          },
        // Action-needed is not a state filter — an item awaiting
        // acknowledgement can be unread or read and is still outstanding
        // (§5.4, "reading is not acting"). The state set here only excludes the
        // closed ones; `requiresAck` does the real work.
        NotificationScope.actionNeeded => const {
            NotificationState.unread,
            NotificationState.read,
          },
        NotificationScope.history => const {
            NotificationState.actioned,
            NotificationState.dismissed,
            NotificationState.expired,
            NotificationState.resolvedElsewhere,
          },
      };

  /// True when this scope shows only items that still require acknowledgement.
  bool get requiresAckOnly => scope == NotificationScope.actionNeeded;

  NotificationQuery copyWith({
    NotificationScope? scope,
    NotificationCategory? category,
    bool clearCategory = false,
    int? limit,
  }) =>
      NotificationQuery(
        scope: scope ?? this.scope,
        // "All" is a real selection, and `copyWith(category: null)` cannot
        // express it — hence the explicit flag.
        category: clearCategory ? null : (category ?? this.category),
        limit: limit ?? this.limit,
      );

  @override
  List<Object?> get props => [scope, category, limit];
}
