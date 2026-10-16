/// The business activity a rep is currently inside during an in-progress
/// visit, layered on top of the route/stop lifecycle ([VisitStatus]). This is
/// *navigation* state — "where the rep stopped" — not business state; it drives
/// the Home "Continue Working" card and where **Continue** resumes to.
///
/// Ordered along the guided field flow: check-in → stock count → quotation /
/// sales order → check-out. Persisted by its [storageKey] in the
/// `workflow_state` table; keep the keys stable.
enum VisitWorkflow {
  checkIn('check_in'),
  stockCount('stock_count'),
  quotation('quotation'),
  salesOrder('sales_order'),
  checkOut('check_out');

  const VisitWorkflow(this.storageKey);

  /// Stable identifier persisted to SQLite. Never localize/rename these.
  final String storageKey;

  /// Localization key for the human-readable activity label (see
  /// `assets/lang/*.json` → `my_visits.workflow.*`).
  String get labelKey => 'my_visits.workflow.$storageKey';

  /// True when this activity lives in the Order feature (Quotation / Sales
  /// Order) rather than the guided visit screens — used to decide whether
  /// **Continue** resumes into the route flow or the order flow.
  bool get isBusinessTask =>
      this == VisitWorkflow.quotation || this == VisitWorkflow.salesOrder;

  /// Parses a persisted [storageKey] back to a value, tolerating unknown/legacy
  /// keys by returning `null` (the resume logic treats that as "route only").
  static VisitWorkflow? fromKey(String? key) {
    if (key == null) return null;
    for (final w in VisitWorkflow.values) {
      if (w.storageKey == key) return w;
    }
    return null;
  }
}
