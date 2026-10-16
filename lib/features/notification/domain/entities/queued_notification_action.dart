import 'package:equatable/equatable.dart';

/// What kind of server-side change a queued row represents.
///
/// Read, action and dismiss are separate kinds rather than one "mutation"
/// because they are semantically different and the difference is load-bearing:
/// §8.3 warns that wiring "the rep scrolled past it" to `/action` silently
/// breaks the supervisor escalation chain the whole assignment flow depends on.
/// Collapsing them into one type is exactly how that mistake gets made.
enum NotificationMutationKind {
  /// `PATCH /{id}/read` — idempotent, and the first read timestamp wins.
  read('read'),

  /// `POST /{id}/action` — the only thing that closes an item requiring
  /// acknowledgement.
  action('action'),

  /// `DELETE /{id}` — a state change, not a deletion. Answers 409 when the item
  /// requires acknowledgement.
  dismiss('dismiss'),

  /// `PATCH /read-all`, optionally scoped to one category.
  readAll('read_all');

  const NotificationMutationKind(this.code);

  final String code;

  static NotificationMutationKind fromCode(String? code) {
    if (code == null) return read;
    for (final value in values) {
      if (value.code == code) return value;
    }
    // A queue row written by a newer build. Treating it as a read is the least
    // damaging misinterpretation available: read is idempotent and closes
    // nothing, so a wrong guess costs a redundant call rather than an
    // escalation that never fires.
    return read;
  }
}

/// One outstanding server-side change captured while offline
/// (`docs/feature/notification/README.md` §8.5).
///
/// ## Why this is queued rather than fired and forgotten
///
/// A rep reads and acknowledges notifications in a warehouse with no signal for
/// hours. The local state change must be immediate — it is what they see — and
/// the server call has to survive until a connection returns. Dropping it means
/// the escalation chain fires against a rep who already did the work.
///
/// The queue is drained on reconnect, and the rules for each outcome are
/// specific (§8.5):
///
///  * **`204`** — done, remove the row.
///  * **`409 Notification.AlreadyResolved`** — somebody else decided first.
///    Remove the row and **tell the rep**; §13.6 requires a clear resolution
///    message, never a silent discard. Do not retry.
///  * **transient** — stop draining and keep the whole queue for the next
///    reconnect. Continuing past a network failure would spend the rest of the
///    queue against the same dead connection.
///  * **anything else permanent** — remove the row; replaying a request the
///    server rejects on its merits will never succeed.
///
/// Replaying an action the server already recorded answers `204`, so a queue
/// draining after reconnect never stalls on its own success.
class QueuedNotificationAction extends Equatable {
  const QueuedNotificationAction({
    required this.id,
    required this.notificationId,
    required this.kind,
    required this.occurredAt,
    this.actionId,
    this.category,
    this.attempts = 0,
  });

  /// Client-generated queue row id, so an offline capture needs no server round
  /// trip to exist (`docs/blueprint/local-storage-architecture.md` §3).
  final String id;

  /// The notification this change applies to. Empty for
  /// [NotificationMutationKind.readAll], which is not scoped to one item.
  final String notificationId;

  final NotificationMutationKind kind;

  /// Which button the rep pressed, for [NotificationMutationKind.action].
  ///
  /// Optional by design: §8.3 says to omit it when the rep acted inside the
  /// record rather than from a notification button. Sending an id the
  /// notification does not offer answers `400 Notification.ActionNotOffered`.
  final String? actionId;

  /// Category scope for [NotificationMutationKind.readAll], so the button
  /// clears what the rep could see rather than what they could not (§8.2).
  final String? category;

  /// When the rep actually did it — **not** when the queue drained.
  ///
  /// Advisory to the server, which records its own clock, and used only to
  /// order a replayed queue. It is still worth capturing honestly: a rep who
  /// acknowledges three routes offline and syncs at 18:00 should not have all
  /// three stamped 18:00 in the ordering.
  final DateTime occurredAt;

  /// Drain attempts so far. Retained for diagnostics and to keep a permanently
  /// failing row from looking identical to a fresh one in a log.
  final int attempts;

  QueuedNotificationAction withAttempt() => QueuedNotificationAction(
        id: id,
        notificationId: notificationId,
        kind: kind,
        actionId: actionId,
        category: category,
        occurredAt: occurredAt,
        attempts: attempts + 1,
      );

  @override
  List<Object?> get props =>
      [id, notificationId, kind, actionId, category, occurredAt, attempts];
}
