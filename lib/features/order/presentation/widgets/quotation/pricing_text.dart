import 'package:steelforce/features/order/domain/entities/cart_item.dart';

/// How an amount is written when it may not exist yet.
///
/// One place, so the cart bar, the quotation preview, the detail screen and the
/// PDF cannot disagree about what a document without prices says.
///
/// The forbidden renderings are the point. A missing price must never appear as
/// `$0`, `0.00`, `N/A` or `Unknown`:
///
///  * `$0.00` is a **quoted price of zero** — a promise a depot can hold the
///    rep to, and the reason this helper exists.
///  * `N/A` and `Unknown` read as an error, as though selecting the material
///    had failed. It did not: the line is valid and the order can proceed.
///
/// So nothing is rendered at all: no amount, no placeholder, no label. The
/// line still shows its material, quantity and unit, which is what makes the
/// absence read as "not priced yet" rather than as an error. The figure
/// appears on its own once the quotation or order is updated with a price.
abstract final class PricingText {
  /// Whether an amount should be rendered at all.
  ///
  /// True for null and for anything at or below zero. `0.00` is not a price:
  /// on a quotation it is a *quoted price of zero*, a promise a depot can
  /// hold the rep to, so it is treated as absent rather than shown.
  static bool isHidden(double? amount) => amount == null || amount <= 0;

  /// The formatted amount, or **null when there is nothing to show**.
  ///
  /// Call sites branch on the null and omit the widget entirely rather than
  /// substituting a placeholder. A material with no price yet is a normal,
  /// valid line — the absence of a figure says that more quietly than any
  /// label, and the number appears on its own once HQ supplies it.
  static String? amountOrNull(double? amount,
      {int decimals = 2, String? currency}) {
    if (isHidden(amount)) return null;
    final formatted = amount!.toStringAsFixed(decimals);
    if (currency == null || currency == 'USD') {
      return '\$$formatted';
    }
    return '$formatted $currency';
  }

  /// The same, as an empty string, for the few slots that must be given a
  /// `String` and render nothing acceptably.
  static String amount(double? amount, {int decimals = 2, String? currency}) =>
      amountOrNull(amount, decimals: decimals, currency: currency) ?? '';

  /// A document roll-up: the summed amount, or null while **any** line is
  /// unpriced.
  ///
  /// A subtotal that silently drops a pending line is a smaller, wronger
  /// number than no subtotal at all — and it is the one the depot is shown.
  static String? totalOrNull(Iterable<CartItem> lines, double fallback,
          {int decimals = 2}) =>
      lines.hasPendingPricing
          ? null
          : amountOrNull(fallback, decimals: decimals);
}
