import 'package:drift/drift.dart';

/// Depot (SAP business partner) registrations submitted while the server was
/// out of reach, waiting to be replayed.
///
/// A local-only outbox like `ad_hoc_visit_queue`, not a mirror table: it has no
/// server counterpart and carries none of the §3.1 syncable columns. The row is
/// deleted once the server holds the registration **and** every photograph.
///
/// It lives in the encrypted database because the payload is depot PII — owner
/// name, phone, address, coordinates (`docs/skills/security.md` §3).
@DataClassName('DepotRegistrationQueueRow')
class DepotRegistrationQueue extends Table {
  @override
  String get tableName => 'depot_registration_queue';

  /// Client-generated v4 uuid, minted when the rep confirms the submit.
  TextColumn get id => text()();

  /// The shop's name, so the Sync Center can list the row without decoding
  /// [payload].
  TextColumn get depotName => text()();

  /// The exact request body (`BusinessPartnerRequestModel.toJson`). The body is
  /// stored rather than the draft so a replay after an app upgrade sends what
  /// the rep confirmed, not a re-mapping under rules they never saw.
  TextColumn get payload => text()();

  /// The draft the payload was built from (`BpDepotDraft.toJson`), kept so a
  /// registration SAP refused can be reopened in the wizard and fixed instead
  /// of typed again. Null when there was no draft to keep.
  TextColumn get draftJson => text().nullable()();

  /// The photographs still to upload, as a JSON list of
  /// `{type, path, capturedAt}`. Shrinks as uploads land.
  TextColumn get attachments => text().withDefault(const Constant('[]'))();

  /// `DepotRegistrationQueueStatus` name: `queued`, `photosPending`,
  /// `needsReview` or `rejected`.
  TextColumn get status => text()();

  /// The platform id the server returned. Set once the registration landed;
  /// the photographs are filed against it.
  TextColumn get depotId => text().nullable()();

  /// The SAP number, empty while HQ approval is pending.
  TextColumn get depotNumber => text().nullable()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// When the next automatic attempt is allowed. Null means now.
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  /// What the rep is shown for a row that needs them. For a SAP refusal this is
  /// SAP's own wording ("payment term T015 not defined…"), which is the only
  /// actionable form of it.
  TextColumn get lastMessage => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
