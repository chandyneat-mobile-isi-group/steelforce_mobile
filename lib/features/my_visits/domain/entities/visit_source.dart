/// Where a stop came from. Decided once, when the stop is created, and never
/// changes afterwards.
///
/// **This is not a status.** `VisitStatus` says what happened to the stop
/// (`pending → checkedIn → checkedOut`); this says who put it on the day. The
/// two are separate fields on purpose: "an ad hoc visit that has been checked
/// out" has to be representable, and folding `adHoc` into the status enum
/// would have made it impossible.
///
/// See `docs/feature/my-visits/ad-hoc-visits-mobile.md` §1.
enum VisitSource {
  /// Issued by the Call Plan. Every stop written before ad hoc visits existed
  /// is one of these, which is also what the server backfills them as.
  callPlan,

  /// Added by the rep in the field, mid-day, against a depot nobody planned.
  adHoc,
}
