/// The outbound (device → Admin backend) lifecycle of a quotation, tracked
/// independently of [QuotationStatus] (draft/saved/converted) so the existing
/// quotation persistence stays untouched.
///
/// Flow (states are never skipped):
///   pendingSync → syncing → accepted   (in Admin Review, or past it)
///                        └→ rejected   (backend refused it — rep must act)
///                        └→ failed     (transport failure after max retries)
///                        └→ conflict   (prices moved — rep must look first)
///   accepted → returned                (administrator sent it back)
///   accepted → rejected                (administrator rejected it)
///
/// The app never sends to SAP; an administrator does that from the portal.
///
/// `draft`/`readyToSubmit` describe a quotation that has NOT yet been enqueued;
/// they exist so the same enum can label a quotation at any point in its life.
enum QuotationSyncStatus {
  draft,
  readyToSubmit,
  pendingSync,
  syncing,
  submitted,
  accepted,
  rejected,
  failed,
  conflict,
  returned;

  /// Waiting in, or actively moving through, the outbound queue.
  bool get isPending =>
      this == pendingSync || this == syncing || this == submitted;

  /// Handed to the Admin backend — no further pushing, only reading back.
  bool get isTerminal => this == accepted;

  /// Stuck and needs the user to decide (retry / resolve) — surfaced in the
  /// Pending Sync center, never auto-resolved.
  bool get needsUserAction =>
      this == failed ||
      this == rejected ||
      this == conflict ||
      this == returned;

  /// A locally-editable quotation not yet handed to the sync queue — what the
  /// Continue-Working card offers to resume.
  bool get isDraft => this == draft || this == readyToSubmit;

  // No `label` here. It used to return English literals — user-facing copy in
  // the domain layer, which ADR-003/FS-NN-6 keep out and FS-LOC-1 forbids
  // outright, and which rendered English status chips to Khmer readers.
  // The localized names live in `QuotationSyncStatusL10n`
  // (`presentation/l10n/quotation_sync_status_l10n.dart`), reading
  // `orders.sync_status.*`.

  static QuotationSyncStatus fromName(String? name) =>
      values.asNameMap()[name] ?? draft;
}
