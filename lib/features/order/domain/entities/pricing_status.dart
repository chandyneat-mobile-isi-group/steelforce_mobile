/// Whether a line has an official price yet.
///
/// Material selection is independent of pricing: a rep may put any material in
/// the catalogue on a quotation, and HQ supplies the number afterwards. So a
/// line without a price is a **normal, valid state**, not an error and not a
/// blocked one.
///
/// The distinction this type exists to protect is between *no price yet* and
/// *a price of zero*. Those look identical once a missing amount has been
/// defaulted to `0.0`, and the second is a promise: a quotation reading
/// `$0.00` is one a depot can hold a rep to. Every display and every total
/// therefore branches on this rather than on the amount.
enum PricingStatus {
  /// HQ has supplied a price; the amounts are real and may be shown and summed.
  available,

  /// The material is selected and orderable, but no official price exists yet.
  /// Amounts are **null**, not zero, and render as "Waiting for HQ".
  waitingForHq;

  /// The wire form, matching the backend contract's `pricingStatus`.
  String get wireName => switch (this) {
        PricingStatus.available => 'available',
        PricingStatus.waitingForHq => 'waiting_for_hq',
      };

  /// Unknown values resolve to [waitingForHq] rather than [available].
  ///
  /// The safe direction: a status this build has not seen must never make the
  /// app print an amount it cannot vouch for.
  static PricingStatus parse(String? raw) =>
      raw?.trim().toLowerCase() == 'available'
          ? PricingStatus.available
          : PricingStatus.waitingForHq;

  bool get isPending => this == PricingStatus.waitingForHq;
}
