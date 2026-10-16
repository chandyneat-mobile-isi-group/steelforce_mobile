/// User actions the App Coach listens for to advance the tutorial.
///
/// Progression is event-driven: a step declares the [CoachAction] it expects,
/// and the coach only advances when that exact action is triggered by the real
/// UI (a tab switch, a button tap, …) — never by a bare "Next" button.
///
/// [none] marks informational steps (Welcome / overviews) that advance via
/// their CTA instead of waiting for a UI action.
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
}
