import 'package:drift/drift.dart';

/// The notification inbox, mirrored into the single encrypted database
/// (`docs/feature/notification/README.md` §1, ADR-001).
///
/// ## Why the inbox is stored at all
///
/// §1: *"The inbox is the notification. Push is only an accelerator."* Every
/// notification is written server-side before anything reaches Firebase, and a
/// push routinely never arrives — a flat battery, a coverage hole, an OEM
/// battery optimiser, a rotated token, or a P4 that is never pushed at all. So
/// the device keeps its own copy and reconciles it with
/// `GET /mobile/notifications`. A rep in a warehouse scrolls the same list they
/// had before they lost signal.
///
/// ## Encrypted, not cached
///
/// A notification body names a depot and a route. That is PII, so it belongs
/// in the encrypted Drift database and not in Hive
/// (`docs/skills/security.md` §3, `docs/blueprint/system-architecture.md` §3). The FCM payload is
/// deliberately thinner for the same reason (§9.2) — no prices, no credit
/// limits, no phone numbers — because a push renders on a locked screen in front
/// of whoever is holding the phone.
///
/// ## No foreign keys (ADR-011)
///
/// [Notifications.id] and the queue's `notification_id` are plain columns.
/// These tables mirror what the backend sent, and the backend enforced its own
/// relationships before transmitting. Re-declaring them on-device is what turned
/// ordinary conditions into data loss elsewhere in this schema: a push can land
/// before its catch-up page, so a queue row can legitimately reference a
/// notification this device has not stored yet, and aborting that write would
/// lose the rep's acknowledgement rather than harmlessly orphaning a row.

/// One inbox item — the local mirror of the §5 notification object.
///
/// Read patterns are (a) newest-first within a state set, and (b) outstanding
/// actions pinned to the top, so the indexes cover `created_at` and the
/// `(state, requires_ack)` pair the inbox query filters on.
@TableIndex(name: 'idx_notifications_created', columns: {#createdAt})
@TableIndex(name: 'idx_notifications_state', columns: {#state, #requiresAck})
@TableIndex(name: 'idx_notifications_category', columns: {#category})
@DataClassName('NotificationRow')
class Notifications extends Table {
  @override
  String get tableName => 'notifications';

  /// The server's `notification_id`, and **the upsert key**.
  ///
  /// §16: upserts must be keyed on this so a catch-up that overlaps a push
  /// already handled cannot produce a duplicate row. It is also why this table
  /// does not carry a client-generated id — nothing here originates on the
  /// device.
  TextColumn get id => text()();

  /// `ROUTE.ASSIGNED` — the dotted canonical form. §18 records that the FCM
  /// payload also ships the flattened `ROUTE_ASSIGNED` as `type` pending
  /// sign-off; the mapper normalises to this one so the column has one shape.
  TextColumn get eventCode => text()();

  /// Wire category code (`ASSIGNMENT`), not an enum index.
  ///
  /// Stored as the code so a category the backend adds later round-trips
  /// through this database untouched. An `IntColumn` holding an enum index
  /// would silently remap every row the day somebody inserts a value into the
  /// middle of the enum — the exact failure `core/utils/enum_parse.dart` was
  /// written to describe.
  TextColumn get category => text()();

  /// `P1`–`P4`, stored as the code for the same reason as [category].
  TextColumn get priority => text()();

  /// Server-localised copy. Rendered as-is — never run through `.tr`.
  ///
  /// Note the consequence: these were localised against the `Accept-Language`
  /// header in force when they were pulled. A rep who switches to Khmer sees
  /// existing rows in the old language until the next full catch-up, which is
  /// why `catchUp(full: true)` exists.
  TextColumn get title => text()();
  TextColumn get body => text()();

  TextColumn get imageUrl => text().nullable()();

  /// `app://routes/{id}`, **as the backend built it** (§11). Never assembled
  /// locally. Null for an event that points at no single record.
  TextColumn get deepLink => text().nullable()();

  /// The item cannot be dismissed and stays outstanding until `POST /action`.
  BoolColumn get requiresAck => boolean().withDefault(const Constant(false))();

  DateTimeColumn get expiresAt => dateTime().nullable()();

  /// Server-supplied shade-grouping key (`Assignment:{routeId}`). Never used for
  /// local deduplication — that is [id]'s job.
  TextColumn get groupKey => text().nullable()();

  /// The server's outstanding-action count at the moment this row was raised.
  /// A snapshot for the app-icon badge, not a running total — §7 requires
  /// reconciling against `GET /unread-count` rather than trusting this.
  IntColumn get badge => integer().nullable()();

  /// The inline action buttons, as the raw JSON array the API sent.
  ///
  /// Stored verbatim rather than normalised into a child table. Actions are
  /// immutable, are never queried across notifications, and are read only when
  /// one row is rendered — so a join would cost a table and a migration to
  /// answer a question nothing asks.
  TextColumn get actionsJson => text().nullable()();

  /// The event's own payload (`entity_type`, `entity_id`, …) as a JSON object of
  /// **string values only**, mirroring the string-only FCM `data` block so one
  /// notification does not parse differently depending on which path delivered
  /// it (§9.1).
  TextColumn get dataJson => text().nullable()();

  /// `unread` / `read` / `actioned` / `dismissed` / `expired` /
  /// `resolved_elsewhere` — the §5.1 lifecycle.
  ///
  /// **Nothing is ever deleted.** Every terminal state stays here so a rep who
  /// half-remembers being told something can find it in history.
  TextColumn get state => text()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get deliveredAt => dateTime().nullable()();
  DateTimeColumn get readAt => dateTime().nullable()();
  DateTimeColumn get actionedAt => dateTime().nullable()();

  /// True when this row was written from an **FCM payload** rather than from the
  /// inbox endpoint, so it is missing whatever the push deliberately withholds.
  ///
  /// The push carries no prices, no credit limits and no depot phone numbers
  /// (§9.2), and no `actions` array — a partial row can therefore render a
  /// heading and a body but must not be treated as the whole record. The next
  /// catch-up overwrites it and clears this flag.
  ///
  /// Without the flag, a push-written row is indistinguishable from a complete
  /// one and the missing action buttons look like a notification that simply
  /// offers none.
  BoolColumn get partial => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Server-side changes captured while offline, awaiting replay
/// (`docs/feature/notification/README.md` §8.5).
///
/// This is the **outbox** for the notification feature. `notifications` above is
/// a pull-only mirror and carries no `SyncableTable` bookkeeping of its own,
/// because the thing that needs pushing is not the row's current shape — it is
/// the discrete act the rep performed. A queue row is that act.
///
/// The pairing is load-bearing and transactional: ADR-006 and
/// `docs/blueprint/sync-architecture.md` §2 require a write to a syncable table to enqueue its
/// sync row **in the same Drift transaction**. Here that means a state change on
/// `notifications` and its queue row commit together or not at all. A visible
/// state change with no queued call is a route the supervisor still believes was
/// never acknowledged.
@TableIndex(
    name: 'idx_notification_queue_notification', columns: {#notificationId})
@DataClassName('NotificationActionQueueRow')
class NotificationActionQueue extends Table {
  @override
  String get tableName => 'notification_action_queue';

  /// Client-generated, so an offline capture needs no server round trip to
  /// exist (`docs/blueprint/local-storage-architecture.md` §3).
  TextColumn get id => text()();

  /// Empty for a `read_all`, which is not scoped to one item.
  TextColumn get notificationId => text()();

  /// `read` / `action` / `dismiss` / `read_all`.
  ///
  /// Kept as distinct kinds rather than one generic mutation because §8.3 warns
  /// that wiring "the rep scrolled past it" to `/action` silently breaks the
  /// escalation chain the assignment flow depends on. One column that could mean
  /// either is how that mistake gets made.
  TextColumn get kind => text()();

  /// Which button was pressed. Null when the rep acted inside the record rather
  /// than from a notification button, which §8.3 explicitly allows.
  TextColumn get actionId => text().nullable()();

  /// Category scope for a `read_all`, so the replay clears what the rep could
  /// see rather than what they could not (§8.2).
  TextColumn get category => text().nullable()();

  /// When the rep did it — not when the queue drained.
  ///
  /// Advisory to the server, which records its own clock, and used only to order
  /// a replayed queue. Still worth capturing honestly: three routes acknowledged
  /// offline and synced at 18:00 should not all be ordered as 18:00.
  DateTimeColumn get occurredAt => dateTime()();

  /// Drain attempts so far. Diagnostics only — a permanently failing row should
  /// not look identical to a fresh one in a log.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// The inbox sync cursor and the last reconciled badge figures.
///
/// ## Why the cursor lives in the database and not in Hive
///
/// It has to be dropped in the same breath as the notifications it describes.
/// A cursor that survives a cleared inbox asks the server for "changes since"
/// a point whose rows are gone, and the delta comes back empty — leaving a
/// permanently blank inbox with no error anywhere. Keeping both in one database
/// makes clearing them one transaction.
///
/// ## The cursor is the server's clock, never the device's
///
/// §6.1 calls sending the device clock *"the single most common way an
/// offline-first notification client breaks"*: a handset running ten minutes
/// fast asks for changes since the future, receives nothing, stores that
/// timestamp, and never syncs again. [syncTimestamp] therefore only ever holds
/// a value read back from `metadata.syncTimestamp`.
@DataClassName('NotificationSyncMetaRow')
class NotificationSyncMeta extends Table {
  @override
  String get tableName => 'notification_sync_meta';

  /// Always `inbox` today. A keyed table rather than a single-row one so a
  /// second stream (a digest cursor, say) needs no migration.
  TextColumn get entity => text()();

  /// The server's own clock from the last successful list call. Sent back as
  /// `since`. **Never** `DateTime.now()`.
  DateTimeColumn get syncTimestamp => dateTime().nullable()();

  /// Last reconciled `unread` — drives the bell badge.
  IntColumn get unread => integer().withDefault(const Constant(0))();

  /// Last reconciled `action_required` — drives the **app-icon** badge, and
  /// nothing else does (§5.4).
  IntColumn get actionRequired => integer().withDefault(const Constant(0))();

  /// `{"ASSIGNMENT": 2, "ORDER": 7}` — the per-category counts, for section
  /// badges. JSON because the key set is server-defined and grows without an
  /// app release.
  TextColumn get byCategoryJson => text().nullable()();

  /// When the counts above were last reconciled.
  ///
  /// Persisted so a cold start can render the last known badge immediately
  /// instead of flashing zero, and so a stale figure is identifiable as stale
  /// rather than merely old.
  DateTimeColumn get countsAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {entity};
}
