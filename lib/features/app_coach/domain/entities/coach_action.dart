/// User actions the App Coach listens for to advance the tutorial.
///
/// Progression is event-driven: a step declares the [CoachAction] it expects,
/// and the coach only advances when that exact action is triggered by the real
/// UI (a tab switch, a button tap, …) — never by a bare "Next" button.
///
/// [none] marks informational steps (Welcome / overviews) that advance via
/// their CTA instead of waiting for a UI action.
///
/// ## Opening, succeeding, failing
///
/// An operation is reported in up to three separate actions, and they are not
/// interchangeable:
///
/// * **opened** (`startCreateDepot`, `openVisitDetails`) — a screen came up.
///   Never evidence that anything was saved.
/// * **…Succeeded** — sent only *after* the app confirmed the result: the
///   repository returned success, the stop's status changed. Never on tap.
/// * **…Failed** — the operation came back with an error. Holds the step in
///   place and shows its retry guidance; it can never advance the coach.
enum CoachAction {
  none,
  openHome,
  viewTarget,
  openQuickActions,
  createLead,
  openMyLeads,
  openMyVisits,
  openDepots,
  openOrders,
  completeTutorial,

  // ── Depots ─────────────────────────────────────────────────────────
  /// The depot registration wizard opened.
  startCreateDepot,

  /// The wizard moved forward to a step — only after that step validated.
  depotFormAddress,
  depotFormContact,
  depotFormSalesTerms,
  depotFormDocuments,
  depotFormReview,

  /// Next or Submit was refused by the form's own validation.
  depotFormInvalid,
  createDepotSucceeded,
  createDepotFailed,
  openDepotDetails,

  // ── Quotations ─────────────────────────────────────────────────────
  startCreateQuotation,

  /// A product line got a quantity in the quotation builder.
  quotationItemAdded,
  createQuotationSucceeded,
  createQuotationFailed,
  openQuotationDetails,
  submitQuotationSucceeded,
  submitQuotationFailed,

  // ── Sales orders ───────────────────────────────────────────────────
  startCreateOrder,
  createOrderSucceeded,
  createOrderFailed,

  // ── Visits ─────────────────────────────────────────────────────────
  openVisitDetails,
  startCheckIn,
  checkInSucceeded,
  checkInFailed,

  /// The post-check-in inventory visibility step (the visit's evidence
  /// capture — this app has no questionnaire-style survey).
  openVisitSurvey,
  submitVisitSurveySucceeded,
  submitVisitSurveyFailed,
  openVisitCompletion,
  completeVisitSucceeded,
  completeVisitFailed,
}
