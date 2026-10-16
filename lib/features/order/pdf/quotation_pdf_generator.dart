import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/pdf/document/pdf_document_builder.dart';
import 'package:steelforce/core/pdf/document/pdf_shaped_text.dart';
import 'package:steelforce/core/pdf/document/pdf_theme.dart';
import 'package:steelforce/features/order/pdf/quotation_pdf_data.dart';

/// Lays out the enterprise quotation document in clean Swiss / modern corporate
/// style for ISI Steel with brand green accents.
///
/// Pure layout: it takes a [QuotationPdfData] and the shared [PdfBuildContext]
/// and returns a [pw.Document].
///
/// Uses [pw.MultiPage] so multi-line quotations paginate automatically, with
/// the table header repeated and page numbers in the footer.
///
/// ## Complex script rendering
///
/// Every text site goes through [PdfShapedText]: Latin strings render as
/// normal vector text; strings containing Khmer are shaped by Flutter's text
/// engine and embedded as print-resolution images.
class QuotationPdfGenerator extends PdfDocumentBuilder {
  QuotationPdfGenerator(this.data);

  final QuotationPdfData data;

  final PdfShapedText _shaped = PdfShapedText();

  @override
  String get documentName => 'ISI_Quotation';

  String _l(String key, String fallback) {
    final value = key.tr;
    return value == key ? fallback : value;
  }

  /// Shaping-aware replacement for `pw.Text` — identical style surface.
  pw.Widget _t(
    String text, {
    required double fontSize,
    required PdfColor color,
    bool bold = false,
    double letterSpacing = 0,
    double lineSpacing = 0,
    double? maxWidth,
  }) =>
      _shaped.text(
        text,
        fontSize: fontSize,
        color: color,
        bold: bold,
        letterSpacing: letterSpacing,
        lineSpacing: lineSpacing,
        maxWidth: maxWidth,
      );

  @override
  Future<pw.Document> build(PdfBuildContext context) async {
    final theme = context.theme;
    final logoSvg = context.assets.logoSvg;
    final doc = pw.Document(
      title: 'ISI Steel Quotation ${data.quotationNumber}',
      author: 'ISI Steel',
      creator: 'SteelForce',
    );

    final currency = NumberFormat.currency(
      symbol: data.currencySymbol,
      decimalDigits: 2,
    );
    final dateFmt = DateFormat('dd MMM yyyy');

    // Pass 1 — build and discard every section once so PdfShapedText records
    // each string that needs Khmer shaping, then rasterize them all.
    _header(theme, logoSvg, dateFmt);
    _continuationBanner(theme);
    _informationCards(theme, dateFmt);
    _lineItemsTable(theme, currency);
    _commercialSummaryRow(theme, currency);
    _termsAndConditionsBlock(theme);
    _signatureBlock(theme, dateFmt);
    _footerBrand(theme);
    _pageLabel(theme);
    await _shaped.warmPending();

    // Pass 2 — the real document; every shaped string now hits the cache.
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          theme: context.pdfTheme,
          margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 32),
        ),
        header: (ctx) => ctx.pageNumber == 1
            ? _header(theme, logoSvg, dateFmt)
            : _continuationBanner(theme),
        footer: (ctx) => _footer(theme, ctx),
        build: (ctx) => [
          pw.SizedBox(height: theme.gapMd),
          _informationCards(theme, dateFmt),
          pw.SizedBox(height: theme.gapLg),
          _lineItemsTable(theme, currency),
          pw.SizedBox(height: theme.gapLg),
          _commercialSummaryRow(theme, currency),
          pw.SizedBox(height: theme.gapLg),
          _termsAndConditionsBlock(theme),
          pw.SizedBox(height: theme.gapXl),
          _signatureBlock(theme, dateFmt),
        ],
      ),
    );

    return doc;
  }

  // ── 1. Header (Executive & Compact) ───────────────────────────────────
  pw.Widget _header(PdfTheme theme, String? logoSvg, DateFormat dateFmt) {
    final validUntilStr = data.validUntil != null
        ? dateFmt.format(data.validUntil!)
        : dateFmt.format(data.createdDate.add(const Duration(days: 7)));

    return pw.Container(
      padding: pw.EdgeInsets.only(bottom: theme.gapSm + 2),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: theme.brandGreenDark, width: 1.5),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Left: Company Branding
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoSvg != null) ...[
                pw.SvgImage(svg: logoSvg, height: 32),
                pw.SizedBox(height: 3),
              ] else ...[
                pw.Text(
                  'ISI STEEL',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: theme.brandGreenDark,
                  ),
                ),
                pw.SizedBox(height: 2),
              ],
              _t(
                'Industrial Steel & Construction Materials',
                fontSize: 8.5,
                color: theme.muted,
                letterSpacing: 0.2,
                maxWidth: 260,
              ),
            ],
          ),

          // Right: Document Title & Metadata
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _t(
                _l('orders.quotation.pdf.title', 'QUOTATION'),
                fontSize: 22,
                bold: true,
                color: theme.brandGreenDark,
                letterSpacing: 1.5,
                maxWidth: 220,
              ),
              pw.SizedBox(height: 3),
              pw.RichText(
                text: pw.TextSpan(
                  style: pw.TextStyle(fontSize: 8.5, color: theme.muted),
                  children: [
                    const pw.TextSpan(text: 'Quotation No: '),
                    pw.TextSpan(
                      text: data.quotationNumber,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: theme.ink,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 2),
              pw.RichText(
                text: pw.TextSpan(
                  style: pw.TextStyle(fontSize: 8, color: theme.muted),
                  children: [
                    const pw.TextSpan(text: 'Date: '),
                    pw.TextSpan(
                      text: dateFmt.format(data.createdDate),
                      style: pw.TextStyle(color: theme.ink),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 2),
              pw.RichText(
                text: pw.TextSpan(
                  style: pw.TextStyle(fontSize: 8, color: theme.muted),
                  children: [
                    const pw.TextSpan(text: 'Valid Until: '),
                    pw.TextSpan(
                      text: validUntilStr,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: theme.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _continuationBanner(PdfTheme theme) {
    return pw.Container(
      padding: pw.EdgeInsets.only(bottom: theme.gapSm),
      margin: pw.EdgeInsets.only(bottom: theme.gapSm),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: theme.borderLight, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _t(
            'ISI STEEL — ${_l('orders.quotation.pdf.title', 'QUOTATION')}',
            fontSize: 8,
            color: theme.brandGreenDark,
            bold: true,
            maxWidth: 300,
          ),
          pw.Text('# ${data.quotationNumber}',
              style: pw.TextStyle(fontSize: 8, color: theme.muted)),
        ],
      ),
    );
  }

  // ── 2. Information Cards (Depot & Quotation) ────────────────────────
  pw.Widget _informationCards(PdfTheme theme, DateFormat dateFmt) {
    final validUntilStr = data.validUntil != null
        ? dateFmt.format(data.validUntil!)
        : dateFmt.format(data.createdDate.add(const Duration(days: 7)));

    final depotRows = [
      _InfoRow('Depot Name', data.depotName, emphasize: true),
      _InfoRow('Company Name', data.companyName ?? data.depotName),
      _InfoRow(
        'Address',
        (data.depotAddress ?? '').isNotEmpty
            ? data.depotAddress!
            : 'Phnom Penh, Cambodia',
      ),
      _InfoRow(
        'Phone',
        (data.depotPhone ?? '').isNotEmpty ? data.depotPhone! : '—',
      ),
      _InfoRow(
        'Email',
        (data.depotEmail ?? '').isNotEmpty ? data.depotEmail! : '—',
      ),
      _InfoRow('Contact Person', data.contactPerson ?? data.depotName),
    ];

    final quotationRows = [
      _InfoRow('Sales Representative', data.salesRepName, emphasize: true),
      _InfoRow('Sales Territory', data.salesTerritory ?? 'Phnom Penh'),
      _InfoRow('Quotation Date', dateFmt.format(data.createdDate)),
      _InfoRow('Valid Until', validUntilStr),
      _InfoRow(
        'Payment Terms',
        data.paymentTerms ?? '30% Advance / Balance on Delivery',
      ),
      _InfoRow(
        'Delivery Terms',
        data.deliveryTerms ?? 'Depot Site / Standard Lead Time',
      ),
    ];

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _infoSection(
            theme,
            title: 'DEPOT INFORMATION',
            rows: depotRows,
          ),
        ),
        pw.SizedBox(width: theme.gapMd),
        pw.Expanded(
          child: _infoSection(
            theme,
            title: 'QUOTATION INFORMATION',
            rows: quotationRows,
          ),
        ),
      ],
    );
  }

  pw.Widget _infoSection(
    PdfTheme theme, {
    required String title,
    required List<_InfoRow> rows,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFAFAFA),
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: theme.borderLight, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _t(
            title,
            fontSize: 7.5,
            bold: true,
            color: theme.brandGreenDark,
            letterSpacing: 0.5,
            maxWidth: 220,
          ),
          pw.SizedBox(height: 5),
          pw.Divider(color: theme.borderLight, height: 1, thickness: 0.5),
          pw.SizedBox(height: 5),
          for (final row in rows) ...[
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 82,
                    child: _t(
                      row.label ?? '',
                      fontSize: 7.5,
                      color: theme.muted,
                      maxWidth: 82,
                    ),
                  ),
                  pw.Text(': ',
                      style: pw.TextStyle(fontSize: 7.5, color: theme.muted)),
                  pw.Expanded(
                    child: _t(
                      row.value,
                      fontSize: 7.5,
                      bold: row.emphasize,
                      color: row.emphasize ? theme.brandGreenDark : theme.ink,
                      maxWidth: 145,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 3. Product Table (Enterprise Dark Green Header) ───────────────────
  pw.Widget _lineItemsTable(PdfTheme theme, NumberFormat currency) {
    const cols = <int, pw.TableColumnWidth>{
      0: pw.FixedColumnWidth(22), // # (01, 02)
      1: pw.FlexColumnWidth(3.0), // Material / Product
      2: pw.FlexColumnWidth(1.6), // SKU
      3: pw.FlexColumnWidth(2.2), // Specification
      4: pw.FlexColumnWidth(0.9), // Qty
      5: pw.FlexColumnWidth(0.8), // Unit
      6: pw.FlexColumnWidth(1.3), // Unit Price
      7: pw.FlexColumnWidth(1.4), // Discount
      8: pw.FlexColumnWidth(1.5), // Total
    };

    return pw.Table(
      columnWidths: cols,
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: theme.borderLight, width: 0.5),
        bottom: pw.BorderSide(color: theme.borderLight, width: 0.5),
      ),
      children: [
        _tableHeaderRow(theme),
        for (var i = 0; i < data.lines.length; i++)
          _tableDataRow(theme, currency, data.lines[i], i + 1, i.isOdd),
      ],
    );
  }

  pw.TableRow _tableHeaderRow(PdfTheme theme) {
    pw.Widget headerCell(
      String text, {
      pw.Alignment align = pw.Alignment.centerLeft,
    }) {
      return pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: _t(
          text,
          fontSize: 7.5,
          bold: true,
          color: theme.onBrand,
          letterSpacing: 0.3,
          maxWidth: 120,
        ),
      );
    }

    final hasSketches = data.lines.any((l) => l.drawingImageBytes != null);

    return pw.TableRow(
      decoration: pw.BoxDecoration(color: theme.brandGreenDark),
      children: [
        headerCell('#', align: pw.Alignment.center),
        headerCell(hasSketches ? 'PRODUCT / SKETCH' : 'MATERIAL / PRODUCT'),
        headerCell('SKU'),
        headerCell('SPECIFICATION'),
        headerCell('QTY', align: pw.Alignment.centerRight),
        headerCell('UNIT', align: pw.Alignment.center),
        headerCell('UNIT PRICE', align: pw.Alignment.centerRight),
        headerCell('DISCOUNT', align: pw.Alignment.centerRight),
        headerCell('TOTAL', align: pw.Alignment.centerRight),
      ],
    );
  }

  pw.TableRow _tableDataRow(
    PdfTheme theme,
    NumberFormat currency,
    QuotationPdfLine line,
    int number,
    bool zebra,
  ) {
    pw.Widget cell(
      pw.Widget child, {
      pw.Alignment align = pw.Alignment.centerLeft,
      pw.EdgeInsets padding =
          const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
    }) {
      return pw.Container(
        alignment: align,
        padding: padding,
        child: child,
      );
    }

    final numStr = number.toString().padLeft(2, '0');
    final qty = line.quantity == line.quantity.roundToDouble()
        ? line.quantity.toStringAsFixed(0)
        : line.quantity.toStringAsFixed(2);
    final unitStr = line.unit.isNotEmpty ? line.unit.toUpperCase() : 'PCS';

    return pw.TableRow(
      decoration: zebra
          ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF9FAFB))
          : const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFFFFFF)),
      children: [
        // 0. # (01, 02)
        cell(
          pw.Text(
            numStr,
            style: pw.TextStyle(fontSize: 7.5, color: theme.muted),
          ),
          align: pw.Alignment.center,
        ),

        // 1. Material / Product
        cell(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _t(
                line.name,
                fontSize: 8,
                bold: true,
                color: theme.ink,
                maxWidth: 110,
              ),
              if (line.isCustomized) ...[
                pw.SizedBox(height: 2),
                pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: pw.BoxDecoration(
                    color: theme.brandGreenLight,
                    borderRadius: pw.BorderRadius.circular(2),
                    border: pw.Border.all(color: theme.brandGreen, width: 0.5),
                  ),
                  child: _t(
                    '📐 Custom Specification',
                    fontSize: 6,
                    bold: true,
                    color: theme.brandGreenDark,
                    maxWidth: 95,
                  ),
                ),
              ],
              if (line.drawingImageBytes != null) ...[
                pw.SizedBox(height: 3),
                pw.ClipRRect(
                  horizontalRadius: 2,
                  verticalRadius: 2,
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      border:
                          pw.Border.all(color: theme.borderLight, width: 0.5),
                    ),
                    child: pw.Image(
                      pw.MemoryImage(line.drawingImageBytes!),
                      height: 36,
                      width: 55,
                      fit: pw.BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // 2. SKU
        cell(
          _t(
            line.sku.isNotEmpty ? line.sku : '—',
            fontSize: 7.5,
            bold: true,
            color: theme.ink,
            maxWidth: 58,
          ),
        ),

        // 3. Specification
        cell(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _t(
                (line.specification != null && line.specification!.isNotEmpty)
                    ? line.specification!
                    : (line.description.isNotEmpty ? line.description : '—'),
                fontSize: 7,
                color: theme.ink,
                maxWidth: 82,
              ),
              if (line.appearance != null && line.appearance!.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                _t(
                  'Finish: ${line.appearance}',
                  fontSize: 6.5,
                  color: theme.muted,
                  maxWidth: 82,
                ),
              ],
            ],
          ),
        ),

        // 4. Qty
        cell(
          pw.Text(
            qty,
            style: pw.TextStyle(
              fontSize: 8,
              color: theme.ink,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          align: pw.Alignment.centerRight,
        ),

        // 5. Unit
        cell(
          _t(
            unitStr,
            fontSize: 7,
            color: theme.muted,
            maxWidth: 30,
          ),
          align: pw.Alignment.center,
        ),

        // 6. Unit Price
        cell(
          pw.Text(
            currency.format(line.unitPrice),
            style: pw.TextStyle(fontSize: 7.5, color: theme.ink),
          ),
          align: pw.Alignment.centerRight,
        ),

        // 7. Discount
        cell(
          _skuDiscountCell(theme, currency, line),
          align: pw.Alignment.centerRight,
        ),

        // 8. Total
        cell(
          pw.Text(
            currency.format(line.lineTotal),
            style: pw.TextStyle(
              fontSize: 8,
              color: theme.ink,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          align: pw.Alignment.centerRight,
        ),
      ],
    );
  }

  pw.Widget _skuDiscountCell(
    PdfTheme theme,
    NumberFormat currency,
    QuotationPdfLine line,
  ) {
    final hasMonetary = line.discountAmount > 0;
    final hasFree = line.freeQuantity > 0;

    if (!hasMonetary && !hasFree) {
      return pw.Text('—',
          style: pw.TextStyle(fontSize: 7.5, color: theme.muted));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        if (hasMonetary)
          pw.Text(
            line.discountRule != null && line.discountRule!.isNotEmpty
                ? '${line.discountRule} / -${currency.format(line.discountAmount)}'
                : '-${currency.format(line.discountAmount)}',
            style: pw.TextStyle(
              fontSize: 7.5,
              color: theme.success,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        if (hasFree)
          _t(
            'Free ${line.freeQuantity} ${line.unit}',
            fontSize: 6.5,
            color: theme.brandGreenDark,
            bold: true,
            maxWidth: 55,
          ),
      ],
    );
  }

  // ── 4. Commercial Summary Row (Terms & Financials) ────────────────────
  pw.Widget _commercialSummaryRow(PdfTheme theme, NumberFormat currency) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left Column: Payment Terms & Delivery Details
        pw.Expanded(
          flex: 5,
          child: _paymentAndDeliveryBlock(theme),
        ),
        pw.SizedBox(width: theme.gapLg),

        // Right Column: Financial Summary Table
        pw.Expanded(
          flex: 5,
          child: _financialSummaryBlock(theme, currency),
        ),
      ],
    );
  }

  pw.Widget _paymentAndDeliveryBlock(PdfTheme theme) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFAFAFA),
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: theme.borderLight, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Payment Terms
          _t(
            'PAYMENT TERMS',
            fontSize: 7.5,
            bold: true,
            color: theme.brandGreenDark,
            letterSpacing: 0.5,
            maxWidth: 220,
          ),
          pw.SizedBox(height: 3),
          _t(
            (data.paymentTerms ?? '').isNotEmpty
                ? data.paymentTerms!
                : '30% advance payment upon confirmation.\nRemaining balance according to agreed terms.',
            fontSize: 7.5,
            color: theme.ink,
            lineSpacing: 1.5,
            maxWidth: 220,
          ),

          pw.SizedBox(height: 10),
          pw.Divider(color: theme.borderLight, height: 1, thickness: 0.5),
          pw.SizedBox(height: 10),

          // Delivery Terms
          _t(
            'DELIVERY',
            fontSize: 7.5,
            bold: true,
            color: theme.brandGreenDark,
            letterSpacing: 0.5,
            maxWidth: 220,
          ),
          pw.SizedBox(height: 3),
          _t(
            'Delivery location: ${data.deliveryLocation ?? (data.depotAddress ?? 'Depot Site')}',
            fontSize: 7.5,
            color: theme.ink,
            maxWidth: 220,
          ),
          pw.SizedBox(height: 1.5),
          _t(
            'Estimated delivery: ${data.estimatedDelivery ?? '3–5 business days'}',
            fontSize: 7.5,
            color: theme.ink,
            maxWidth: 220,
          ),
          if ((data.deliveryTerms ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 1.5),
            _t(
              data.deliveryTerms!,
              fontSize: 7,
              color: theme.muted,
              maxWidth: 220,
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _financialSummaryBlock(PdfTheme theme, NumberFormat currency) {
    pw.Widget summaryRow(
      String label,
      String value, {
      PdfColor? valueColor,
      bool bold = false,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _t(
              label,
              fontSize: 8,
              bold: bold,
              color: bold ? theme.ink : theme.muted,
              maxWidth: 140,
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 8,
                color: valueColor ?? theme.ink,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ],
        ),
      );
    }

    final deliveryLabel =
        data.deliveryFee > 0 ? currency.format(data.deliveryFee) : 'Included';

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFFFFFF),
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: theme.borderLight, width: 0.5),
      ),
      child: pw.Column(
        children: [
          // Subtotal
          summaryRow(
            'SUBTOTAL',
            currency.format(data.subtotal),
          ),

          // Total Discount
          summaryRow(
            'DISCOUNT',
            data.totalDiscount > 0
                ? '-${currency.format(data.totalDiscount)}'
                : '—',
            valueColor: data.totalDiscount > 0 ? theme.success : null,
          ),

          // Itemized breakdown if both SKU and Invoice discounts exist
          if (data.skuDiscountTotal > 0 && data.invoiceDiscountTotal > 0) ...[
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 6),
              child: summaryRow(
                '  • SKU Discounts',
                '-${currency.format(data.skuDiscountTotal)}',
                valueColor: theme.success,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 6),
              child: summaryRow(
                '  • Invoice Discount',
                '-${currency.format(data.invoiceDiscountTotal)}',
                valueColor: theme.success,
              ),
            ),
          ],

          // Tax / VAT
          summaryRow(
            data.tax <= 0 ? 'TAX (EXEMPT)' : 'VAT 10%',
            currency.format(data.tax),
          ),

          // Delivery
          summaryRow(
            'DELIVERY',
            deliveryLabel,
          ),

          pw.SizedBox(height: 6),
          pw.Divider(color: theme.borderLight, height: 1, thickness: 0.5),
          pw.SizedBox(height: 6),

          // TOTAL AMOUNT (Dominant with Light Green Tint)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: pw.BoxDecoration(
              color: theme.brandGreenLight,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(
                color: const PdfColor.fromInt(0xFFC8E6C9),
                width: 0.8,
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                _t(
                  'TOTAL AMOUNT',
                  fontSize: 9,
                  bold: true,
                  color: theme.brandGreenDark,
                  letterSpacing: 0.5,
                  maxWidth: 90,
                ),
                pw.Text(
                  currency.format(data.total),
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: theme.brandGreenDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 5. Terms & Conditions Block ───────────────────────────────────────
  pw.Widget _termsAndConditionsBlock(PdfTheme theme) {
    final customNotes = (data.notes ?? '').trim();

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFAFAFA),
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: theme.borderLight, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _t(
            'TERMS & CONDITIONS',
            fontSize: 7.5,
            bold: true,
            color: theme.brandGreenDark,
            letterSpacing: 0.5,
            maxWidth: 250,
          ),
          pw.SizedBox(height: 4),
          _t(
            '1. Quotation validity: 7 days from quotation date.\n'
            '2. Prices are subject to applicable taxes.\n'
            '3. Product availability is subject to confirmation upon order placement.\n'
            '4. Delivery schedule may vary depending on stock availability and production lead times.\n'
            '5. Any customized material is subject to approved engineering specifications.',
            fontSize: 7,
            color: theme.muted,
            lineSpacing: 1.8,
            maxWidth: 510,
          ),
          if (customNotes.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            _t(
              'Special Notes: $customNotes',
              fontSize: 7,
              bold: true,
              color: theme.ink,
              lineSpacing: 1.5,
              maxWidth: 510,
            ),
          ],
        ],
      ),
    );
  }

  // ── 6. Signature Area ─────────────────────────────────────────────────
  pw.Widget _signatureBlock(PdfTheme theme, DateFormat dateFmt) {
    pw.Widget signatureColumn({
      required String title,
      required String subtitle,
      required String name,
      required String date,
    }) {
      return pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _t(
              title,
              fontSize: 8,
              bold: true,
              color: theme.ink,
              maxWidth: 200,
            ),
            pw.SizedBox(height: 1),
            _t(
              subtitle,
              fontSize: 7,
              color: theme.muted,
              maxWidth: 200,
            ),
            pw.SizedBox(height: 8),
            _t(
              'Name: $name',
              fontSize: 7.5,
              color: theme.ink,
              maxWidth: 200,
            ),
            pw.SizedBox(height: 24),
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: theme.muted, width: 0.5),
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _t('Signature', fontSize: 7, color: theme.muted, maxWidth: 80),
                _t('Date: $date',
                    fontSize: 7, color: theme.muted, maxWidth: 100),
              ],
            ),
          ],
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          signatureColumn(
            title: 'Prepared By',
            subtitle: 'Sales Representative',
            name: data.salesRepName,
            date: dateFmt.format(data.createdDate),
          ),
          pw.SizedBox(width: 48),
          signatureColumn(
            title: 'Depot Approval',
            subtitle: 'Authorized Person',
            name: (data.contactPerson ?? data.depotName),
            date: '__________________',
          ),
        ],
      ),
    );
  }

  // ── 7. Footer ─────────────────────────────────────────────────────────
  pw.Widget _footerBrand(PdfTheme theme) => _t(
        'ISI Steel · Industrial Steel & Construction Materials',
        fontSize: 7,
        color: theme.muted,
        maxWidth: 350,
      );

  pw.Widget _pageLabel(PdfTheme theme) => _t(
        _l('orders.quotation.pdf.page', 'Page'),
        fontSize: 7,
        color: theme.muted,
        maxWidth: 80,
      );

  pw.Widget _footer(PdfTheme theme, pw.Context ctx) {
    return pw.Container(
      margin: pw.EdgeInsets.only(top: theme.gapSm),
      padding: pw.EdgeInsets.only(top: theme.gapSm),
      decoration: pw.BoxDecoration(
        border:
            pw.Border(top: pw.BorderSide(color: theme.borderLight, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _footerBrand(theme),
          pw.Row(children: [
            _pageLabel(theme),
            pw.Text(
              ' ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 7, color: theme.muted),
            ),
          ]),
        ],
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value, {this.emphasize = false});
  final String? label;
  final String value;
  final bool emphasize;
}
