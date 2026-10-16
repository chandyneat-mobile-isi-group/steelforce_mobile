import 'package:equatable/equatable.dart';

/// Outcome of one inbox catch-up run
/// (`docs/feature/notification/README.md` §6.1).
class NotificationSyncResult extends Equatable {
  const NotificationSyncResult({
    this.received = 0,
    this.pages = 0,
    this.skipped = false,
    this.cursor,
  });

  /// Nothing was attempted — no session, or no connection. Deliberately not a
  /// failure: offline is a normal state, not an error state (ADR-002 §4), and
  /// the inbox the rep is looking at is still valid.
  static const NotificationSyncResult notAttempted =
      NotificationSyncResult(skipped: true);

  final int received;
  final int pages;
  final bool skipped;

  /// The cursor now stored for the next run — the server's own
  /// `metadata.syncTimestamp`, **never the device clock**.
  ///
  /// §6.1 calls sending the device clock "the single most common way an
  /// offline-first notification client breaks": a handset running ten minutes
  /// fast asks for changes since the future, receives nothing, stores that
  /// timestamp, and never syncs again — with no error anywhere to notice.
  final DateTime? cursor;

  @override
  List<Object?> get props => [received, pages, skipped, cursor];
}
