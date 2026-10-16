import 'package:equatable/equatable.dart';

/// Where a line's discount came from.
///
/// The quotation is a document the depot keeps and argues from. "−10%" with
/// no attribution is the line a rep gets challenged on three weeks later —
/// "who gave me that, and does it still apply?" — and neither the rep nor the
/// office can answer it from the PDF as it stands today.
///
/// Each source has a different lifetime, which is the reason they are not one
/// field:
///
///  * [repDiscount] is one rep's decision on one quotation, and expires with it.
///  * [promotion] is a published campaign with dates; it will lapse.
///  * [priceTier] follows the quantity, so it changes if the order changes.
///  * [depotAgreement] is negotiated and standing.
///
/// Printing all four as an undifferentiated "Discount" tells the depot they
/// got a number, not what they can rely on next time.
enum DiscountSource {
  /// Granted by the representative on this quotation.
  repDiscount('Rep discount'),

  /// Earned from a running campaign. Carries the campaign's name.
  promotion('Promotion'),

  /// Volume break — the price falls at this quantity.
  priceTier('Volume price'),

  /// A standing negotiated rate for this depot.
  depotAgreement('Depot agreement');

  const DiscountSource(this.label);

  final String label;
}

/// What was taken off one quotation line, and on whose authority.
///
/// Free goods are carried here alongside the money, even though they are not a
/// discount, because on the printed row they answer the same question: what did
/// this depot get beyond the list price? Keeping them in separate structures
/// would mean the PDF stitching two sources together per row, and a line that
/// earned both would print them in whichever order the code happened to run.
class QuotationLineDiscount extends Equatable {
  const QuotationLineDiscount({
    required this.source,
    this.percent = 0,
    this.amount = 0,
    this.freeQuantity = 0,
    this.freeQuantityLabel,
    this.sourceDetail,
  });

  /// A line that got nothing. Prints as a dash rather than a zero — a zero in a
  /// discount column reads as "we considered it and gave you none", which is a
  /// different and more provocative statement than "not applicable".
  static const QuotationLineDiscount none =
      QuotationLineDiscount(source: DiscountSource.repDiscount);

  final DiscountSource source;

  /// Percentage off the line, 0 when the benefit was free goods only.
  final double percent;

  /// Money off the line, in the quotation's currency.
  final double amount;

  /// Units given free. Never folded into the paid quantity — a rep promising
  /// "300, and 15 come free" is making a checkable promise that "5% off" is not.
  final int freeQuantity;

  /// The rule that produced [freeQuantity], e.g. "Buy 40 Free 1". Printed so
  /// the depot can verify the entitlement rather than take it on trust.
  final String? freeQuantityLabel;

  /// The campaign or agreement name, where one applies.
  final String? sourceDetail;

  bool get isEmpty => percent <= 0 && amount <= 0 && freeQuantity <= 0;

  /// The attribution line, e.g. "Promotion · Camstar Free Goods".
  String get sourceText {
    final detail = sourceDetail?.trim();
    if (detail == null || detail.isEmpty) return source.label;
    return '${source.label} · $detail';
  }

  @override
  List<Object?> get props => [
        source,
        percent,
        amount,
        freeQuantity,
        freeQuantityLabel,
        sourceDetail,
      ];
}
