import 'package:steelforce/core/localization/active_language.dart';
import 'package:steelforce/core/platform/storage/local_files.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/quotation_line_discount.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/pricing_text.dart';

class QuotationPdfService {
  /// Builds the quotation document.
  ///
  /// [discountsByLineId] attributes each line's discount to whoever granted it,
  /// keyed by `CartItem.id`. Optional: a line with no entry and a non-zero
  /// `discountPercent` is attributed to the representative, which is what an
  /// ad-hoc discount on a quotation is by definition. A caller that knows
  /// better — because it holds the promotion evaluations, or read a volume
  /// break off the pricing response — passes the real source instead.
  Future<pw.Document> generateQuotationDocument({
    required String quotationNumber,
    required String depotName,
    required List<CartItem> items,
    required double subtotal,
    required double discount,
    required double tax,
    required double total,
    Map<String, QuotationLineDiscount> discountsByLineId = const {},
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          _buildHeader(quotationNumber, depotName),
          pw.SizedBox(height: 16),
          _buildItemsTable(items, discountsByLineId),
          pw.SizedBox(height: 16),
          _buildSummary(subtotal, discount, tax, total,
              pending: items.hasPendingPricing),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _buildHeader(String quotationNumber, String depotName) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'ISI STEEL SALES QUOTATION',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Depot: $depotName'),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Quotation #: $quotationNumber',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Date: ${DateTime.now().toString().split(' ')[0]}'),
          ],
        ),
      ],
    );
  }

  /// Resolves what came off a line, falling back to the rep when nothing is
  /// supplied.
  ///
  /// The fallback is not a guess dressed up as a fact: on this platform an
  /// unattributed percentage on a quotation line *is* a rep discount, because
  /// it is the only kind the app lets somebody type by hand. Promotions and
  /// volume breaks arrive already labelled.
  QuotationLineDiscount _discountFor(
    CartItem item,
    Map<String, QuotationLineDiscount> supplied,
  ) {
    final known = supplied[item.id];
    if (known != null) return known;

    if (item.discountPercent <= 0) return QuotationLineDiscount.none;

    return QuotationLineDiscount(
      source: DiscountSource.repDiscount,
      percent: item.discountPercent,
      amount: item.isPricePending ? 0 : item.lineDiscount,
    );
  }

  pw.Widget _buildItemsTable(
    List<CartItem> items,
    Map<String, QuotationLineDiscount> discounts,
  ) {
    final headers = [
      'Image / Drawing',
      'Product Details',
      'Qty',
      'Unit Price',
      'Discount',
      'Total',
    ];

    return pw.TableHelper.fromTextArray(
      headers: headers,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      cellAlignment: pw.Alignment.centerLeft,
      cellHeight: 50,
      columnWidths: {
        0: const pw.FixedColumnWidth(72),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1.1),
        // Wider than the money columns: it carries two short lines of text, and
        // an attribution that wraps mid-word is worse than no attribution.
        4: const pw.FlexColumnWidth(1.9),
        5: const pw.FlexColumnWidth(1.2),
      },
      data: items.map((item) {
        // Image resolution logic
        pw.Widget imageCell;
        if (item.isCustomized &&
            item.drawingImagePath != null &&
            localFileExists(item.drawingImagePath!)) {
          try {
            final imageBytes = readLocalFileSync(item.drawingImagePath!)!;
            imageCell = pw.Container(
              height: 45,
              width: 62,
              alignment: pw.Alignment.center,
              child: pw.Image(
                pw.MemoryImage(imageBytes),
                fit: pw.BoxFit.contain,
              ),
            );
          } catch (_) {
            imageCell = pw.Text('[Drawing Error]');
          }
        } else {
          imageCell = pw.Text('[Standard]');
        }

        // Details column formatting
        // Resolved through [ActiveLanguage] rather than a `BuildContext`: the
        // PDF is composed outside the widget tree, and a Khmer session must
        // produce a Khmer document (LOCALIZATION.md §8) rather than silently
        // falling back to the English material description.
        final detailText =
            StringBuffer(ActiveLanguage.resolve(item.product.displayName));
        if (item.isCustomized) {
          detailText.write('\n(Customized Request)');
          if (item.measurements != null) {
            detailText
                .write('\nSpecs: ${item.measurements!.toSummaryString()}');
          }
          if (item.appearance != null && item.appearance!.isNotEmpty) {
            detailText.write('\nFinish: ${item.appearance}');
          }
          if (item.customizationDescription != null &&
              item.customizationDescription!.isNotEmpty) {
            detailText.write('\nNotes: ${item.customizationDescription}');
          }
        }

        return [
          imageCell,
          pw.Text(detailText.toString(),
              style: const pw.TextStyle(fontSize: 9)),
          _quantityCell(item, _discountFor(item, discounts)),
          // Blank rather than `\$0.00`: a quotation is a document the depot
          // keeps, and a zero on it is a price they can hold the rep to.
          pw.Text(PricingText.amount(item.unitPriceOrNull),
              style: const pw.TextStyle(fontSize: 9)),
          _discountCell(_discountFor(item, discounts),
              pending: item.isPricePending),
          pw.Text(PricingText.amount(item.lineTotalOrNull),
              style: const pw.TextStyle(fontSize: 9)),
        ];
      }).toList(),
    );
  }

  /// Quantity, with any free units earned on their own line beneath it.
  ///
  /// Free goods belong next to the number they change, not in the money
  /// column, and they are never added into the paid quantity — the two are
  /// carried separately all the way from the promotion tier onto this page.
  pw.Widget _quantityCell(CartItem item, QuotationLineDiscount discount) {
    if (discount.freeQuantity <= 0) {
      return pw.Text(
        '${item.quantity.toStringAsFixed(0)} ${item.unit}',
        style: const pw.TextStyle(fontSize: 9),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          '${item.quantity.toStringAsFixed(0)} ${item.unit}',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.Text(
          '+${discount.freeQuantity} free',
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.green800,
          ),
        ),
      ],
    );
  }

  /// What came off this line, and on whose authority.
  ///
  /// Three lines at most, in decreasing order of what a depot checks first:
  /// the percentage, the money it is worth, then who granted it. An empty
  /// discount prints an em dash rather than a zero — "0%" reads as a refusal,
  /// which is a more provocative thing to print than "not applicable".
  ///
  /// [pending] suppresses the money but keeps the percentage and the source. A
  /// line whose price has not come back still has a known entitlement, and
  /// hiding the whole cell would make the promotion look like it had lapsed.
  pw.Widget _discountCell(
    QuotationLineDiscount discount, {
    required bool pending,
  }) {
    if (discount.isEmpty) {
      return pw.Text('—',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600));
    }

    final lines = <pw.Widget>[];

    if (discount.percent > 0) {
      lines.add(pw.Text(
        '-${discount.percent.toStringAsFixed(0)}%',
        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
      ));
    }

    if (!pending && discount.amount > 0) {
      lines.add(pw.Text(
        '-${PricingText.amount(discount.amount)}',
        style: const pw.TextStyle(fontSize: 8.5),
      ));
    }

    // The rule only. The free units themselves print in the Qty column, next
    // to the number they change — a depot reading "300 Bag / +15 free" is
    // reading a delivery note, where the same fact in the money column would
    // need arithmetic to check.
    final rule = discount.freeQuantityLabel;
    if (discount.freeQuantity > 0 && rule != null && rule.isNotEmpty) {
      lines.add(pw.Text(
        rule,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      ));
    }

    // The attribution. Grey and small so it reads as a footnote to the number
    // above rather than competing with it — but present on every discounted
    // line, which is the entire point of the column.
    lines.add(pw.Text(
      discount.sourceText,
      style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
    ));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: lines,
    );
  }

  /// [pending] blanks every figure rather than printing a total that is
  /// missing a line. A quotation is a document a depot keeps, so a subtotal
  /// that silently omits an unpriced material is the worst of the options.
  pw.Widget _buildSummary(
      double subtotal, double discount, double tax, double total,
      {required bool pending}) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 220,
        child: pw.Column(
          children: [
            _summaryRow('Subtotal', pending ? null : subtotal),
            if (!pending) _summaryRow('Total discount', -discount),
            _summaryRow('Tax (10%)', pending ? null : tax),
            pw.Divider(),
            _summaryRow('Total Amount', pending ? null : total, isBold: true),
            if (!pending && discount > 0) ...[
              pw.SizedBox(height: 6),
              // Points at the column rather than repeating it. The breakdown
              // already exists per line; restating it here would be a second
              // place to keep in step, and the two would disagree the first
              // time a line was edited.
              pw.Text(
                'See the Discount column for how each line was reduced.',
                style:
                    const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  pw.Widget _summaryRow(String label, double? value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            PricingText.amount(value),
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
