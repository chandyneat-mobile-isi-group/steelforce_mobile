import 'package:steelforce/core/platform/storage/local_files.dart';
import 'dart:typed_data';

import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/presentation/widgets/promotion/demo_cart_promotions.dart';

/// One priced row on the quotation PDF. Deliberately a flat, Flutter-free value
/// object rather than a [CartItem]: the generator must not depend on the cart
/// domain model (or on `Product`), so mapping happens once here and the PDF
/// layer stays isolated from catalog/cart refactors.
class QuotationPdfLine {
  const QuotationPdfLine({
    required this.sku,
    required this.name,
    required this.description,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.discountPercent,
    this.discountAmount = 0.0,
    this.discountRule,
    this.discountText,
    required this.lineTotal,
    this.isCustomized = false,
    this.specs,
    this.appearance,
    this.drawingImageBytes,
    this.promotionName,
    this.freeQuantity = 0,
    this.freeQuantityRule,
    this.specification,
  });

  /// Material SKU / code (e.g. "SKU-001", "GI-PIPE-01").
  final String sku;

  final String name;
  final String description;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double discountPercent;

  /// Monetary discount calculated specifically for this SKU line.
  final double discountAmount;

  /// Discount rule description, e.g. "3%", "$1.00", "Buy 10 Get 2 Free".
  final String? discountRule;

  /// Full formatted text for the dedicated Discount column, e.g. "3% / -$0.60" or "Free 20".
  final String? discountText;

  final double lineTotal;

  // ── Customization (empty/false for a plain catalog line) ──────────────
  final bool isCustomized;

  /// Measurements summary, e.g. "L: 6000mm × Ø: 12mm".
  final String? specs;

  /// Surface finish / colour / coating.
  final String? appearance;

  /// Decoded bytes of the attached technical drawing, ready for the PDF's
  /// `MemoryImage`. Null when there is no drawing (or it couldn't be read).
  final Uint8List? drawingImageBytes;

  /// Associated promotion name if any (e.g. "Roofing Sheet Free Goods", "Buy More").
  final String? promotionName;

  /// Free quantity awarded for this line.
  final int freeQuantity;

  /// Rule for free quantity (e.g. "Buy 40 Free 1").
  final String? freeQuantityRule;

  /// Formatted engineering specification or grade & dimensions (e.g. "Grade: SD390 • Ø16mm • 12m").
  final String? specification;
}

/// The immutable input to [QuotationPdfGenerator].
///
/// This is the boundary the prompt calls out: **never pass widget state** into
/// the generator. The presentation layer assembles one of these from domain
/// entities ([CartItem], the session's rep, the depot) and hands it over;
/// the generator only ever sees plain data.
class QuotationPdfData {
  const QuotationPdfData({
    required this.quotationNumber,
    required this.depotName,
    required this.salesRepName,
    required this.createdDate,
    required this.lines,
    required this.subtotal,
    required this.discount,
    this.skuDiscountTotal = 0.0,
    this.invoiceDiscountTotal = 0.0,
    required this.tax,
    required this.total,
    this.isTaxApplicable = true,
    this.invoiceDiscounts = const [],
    this.depotPhone,
    this.depotAddress,
    this.salesRepContact,
    this.validUntil,
    this.notes,
    this.currencySymbol = r'$',
    this.companyName,
    this.depotEmail,
    this.contactPerson,
    this.salesTerritory,
    this.paymentTerms,
    this.deliveryTerms,
    this.deliveryLocation,
    this.estimatedDelivery,
    this.deliveryFee = 0.0,
  });

  final String quotationNumber;
  final String depotName;
  final String? depotPhone;
  final String? depotAddress;
  final String? depotEmail;
  final String? companyName;
  final String? contactPerson;
  final String salesRepName;
  final String? salesRepContact;
  final String? salesTerritory;
  final DateTime createdDate;
  final DateTime? validUntil;
  final String? paymentTerms;
  final String? deliveryTerms;
  final String? deliveryLocation;
  final String? estimatedDelivery;
  final double deliveryFee;
  final List<QuotationPdfLine> lines;
  final double subtotal;
  final double discount;

  /// Combined total of all individual SKU discounts.
  final double skuDiscountTotal;

  /// Total of invoice-level discounts applied to the entire quotation.
  final double invoiceDiscountTotal;

  final double tax;
  final double total;
  final bool isTaxApplicable;
  final List<String> invoiceDiscounts;
  final String? notes;
  final String currencySymbol;

  /// Total discount = SKU Discount Total + Invoice Discount.
  double get totalDiscount => (skuDiscountTotal + invoiceDiscountTotal) > 0
      ? (skuDiscountTotal + invoiceDiscountTotal)
      : discount;

  /// Builds the PDF payload from live cart data. This is the single place cart
  /// entities cross into the PDF layer, so any product-shape change touches
  /// exactly one mapping.
  factory QuotationPdfData.fromCart({
    required String quotationNumber,
    required String depotName,
    required String salesRepName,
    required DateTime createdDate,
    required List<CartItem> items,
    required double subtotal,
    required double discount,
    double? skuDiscountTotal,
    double? invoiceDiscountTotal,
    required double tax,
    required double total,
    bool isTaxApplicable = true,
    List<String> invoiceDiscounts = const [],
    String? depotPhone,
    String? depotAddress,
    String? depotEmail,
    String? companyName,
    String? contactPerson,
    String? salesRepContact,
    String? salesTerritory,
    DateTime? validUntil,
    String? paymentTerms,
    String? deliveryTerms,
    String? deliveryLocation,
    String? estimatedDelivery,
    double deliveryFee = 0.0,
    String? notes,
    String currencySymbol = r'$',
  }) {
    final lines = items.map((item) {
      final product = item.product;
      final sku = product.sku.isNotEmpty
          ? product.sku
          : (product.materialCode.isNotEmpty
              ? product.materialCode
              : product.code);
      final description = '${product.size} ${product.grade}'.trim();

      String? specs;
      String? appearance;
      Uint8List? drawingBytes;
      if (item.isCustomized) {
        final m = item.measurements;
        if (m != null && !m.isEmpty) {
          final customParts = <String>[];
          if (m.widthMm != null && m.widthMm! > 0) {
            final wStr = m.widthMm == m.widthMm!.roundToDouble()
                ? m.widthMm!.toStringAsFixed(0)
                : m.widthMm!.toString();
            customParts.add('Width: $wStr mm');
          }
          if (m.lengthMm != null && m.lengthMm! > 0) {
            final lStr = m.lengthMm == m.lengthMm!.roundToDouble()
                ? m.lengthMm!.toStringAsFixed(0)
                : m.lengthMm!.toString();
            customParts.add('Length: $lStr mm');
          }
          if (m.thicknessMm != null && m.thicknessMm! > 0) {
            final tStr = m.thicknessMm == m.thicknessMm!.roundToDouble()
                ? m.thicknessMm!.toStringAsFixed(0)
                : m.thicknessMm!.toString();
            customParts.add('Thickness: $tStr mm');
          }
          if (m.heightMm != null && m.heightMm! > 0) {
            final hStr = m.heightMm == m.heightMm!.roundToDouble()
                ? m.heightMm!.toStringAsFixed(0)
                : m.heightMm!.toString();
            customParts.add('Height: $hStr mm');
          }
          if (m.diameterMm != null && m.diameterMm! > 0) {
            final dStr = m.diameterMm == m.diameterMm!.roundToDouble()
                ? m.diameterMm!.toStringAsFixed(0)
                : m.diameterMm!.toString();
            customParts.add('Ø: $dStr mm');
          }
          specs = customParts.isNotEmpty
              ? customParts.join(' • ')
              : m.toSummaryString();
        }
        final finish = item.appearance?.trim();
        if (finish != null && finish.isNotEmpty) appearance = finish;
        drawingBytes = _readDrawing(item.drawingImagePath);
      }

      // Build rich engineering specification
      String? specStr;
      if (item.isCustomized) {
        if (specs != null && specs.isNotEmpty) {
          specStr = specs;
        } else if (product.specification.isNotEmpty) {
          specStr = product.specification;
        }
      } else {
        final specParts = <String>[];
        if (product.grade.isNotEmpty) specParts.add('Grade: ${product.grade}');
        if (product.diameter > 0) {
          final diaStr = product.diameter == product.diameter.roundToDouble()
              ? product.diameter.toStringAsFixed(0)
              : product.diameter.toString();
          specParts.add('Ø${diaStr}mm');
        }
        if (product.thickness > 0) {
          final thkStr = product.thickness == product.thickness.roundToDouble()
              ? product.thickness.toStringAsFixed(0)
              : product.thickness.toString();
          specParts.add('${thkStr}mm');
        } else if (product.size.isNotEmpty &&
            !specParts.any((p) => p.contains(product.size))) {
          specParts.add(product.size);
        }
        if (product.length > 0) {
          final lenStr = product.length == product.length.roundToDouble()
              ? product.length.toStringAsFixed(0)
              : product.length.toString();
          specParts.add('${lenStr}m');
        }
        if (product.specification.isNotEmpty &&
            !specParts.contains(product.specification)) {
          specParts.add(product.specification);
        }
        if (specParts.isEmpty && description.isNotEmpty) {
          specParts.add(description);
        }
        if (specParts.isNotEmpty) specStr = specParts.join(' • ');
      }

      final freeUnits = DemoCartPromotions.freeQuantityFor(item);
      final freeRule = DemoCartPromotions.freeRuleFor(item);
      final promoName = DemoCartPromotions.promotionNameFor(item) ??
          (item.discountPercent > 0 ? 'Promotion' : null);

      final hasPercent = item.discountPercent > 0;
      final discountAmount = item.lineDiscount;
      String? discountRule;
      String? discountText;

      if (hasPercent) {
        final percentFormatted =
            item.discountPercent.truncateToDouble() == item.discountPercent
                ? '${item.discountPercent.toStringAsFixed(0)}%'
                : '${item.discountPercent.toStringAsFixed(1)}%';
        discountRule = percentFormatted;
        final promoPrefix = (promoName != null &&
                promoName.isNotEmpty &&
                promoName != 'Promotion')
            ? '$promoName — '
            : '';
        discountText =
            '$promoPrefix$percentFormatted / -\$${discountAmount.toStringAsFixed(2)}';
      } else if (freeUnits > 0) {
        final rule = freeRule ?? 'Free $freeUnits';
        discountRule = rule;
        final promoPrefix = (promoName != null &&
                promoName.isNotEmpty &&
                promoName != 'Promotion')
            ? '$promoName — '
            : '';
        discountText = '$promoPrefix$rule';
      } else {
        discountText = '—';
      }

      return QuotationPdfLine(
        sku: sku,
        name: product.name.isNotEmpty ? product.name : 'Structural Item',
        description: description,
        unit: item.unit,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        discountPercent: item.discountPercent,
        discountAmount: discountAmount,
        discountRule: discountRule,
        discountText: discountText,
        lineTotal: item.lineTotal,
        isCustomized: item.isCustomized,
        specs: specs,
        appearance: appearance,
        drawingImageBytes: drawingBytes,
        promotionName: promoName,
        freeQuantity: freeUnits,
        freeQuantityRule: freeRule,
        specification: specStr,
      );
    }).toList(growable: false);

    // Compute SKU discounts from line items if not explicitly provided
    final computedSkuDiscount = lines.fold<double>(
      0.0,
      (sum, line) => sum + line.discountAmount,
    );
    final resolvedSkuDiscount = skuDiscountTotal ?? computedSkuDiscount;

    // Resolve Invoice Discount: explicit or remainder of discount - SKU discounts
    final computedInvoiceDiscount = (discount - resolvedSkuDiscount).clamp(
      0.0,
      double.infinity,
    );
    final resolvedInvoiceDiscount =
        invoiceDiscountTotal ?? computedInvoiceDiscount;

    return QuotationPdfData(
      quotationNumber: quotationNumber,
      depotName: depotName,
      depotPhone: depotPhone,
      depotAddress: depotAddress,
      depotEmail: depotEmail,
      companyName: companyName ?? depotName,
      contactPerson: contactPerson ?? depotName,
      salesRepName: salesRepName,
      salesRepContact: salesRepContact,
      salesTerritory: salesTerritory ?? 'Phnom Penh',
      createdDate: createdDate,
      validUntil: validUntil,
      paymentTerms: paymentTerms ??
          '30% advance payment upon confirmation. Remaining balance according to agreed terms.',
      deliveryTerms: deliveryTerms ?? 'Depot Site / Standard Lead Time',
      deliveryLocation: deliveryLocation ?? (depotAddress ?? 'Depot Site'),
      estimatedDelivery: estimatedDelivery ?? '3–5 business days',
      deliveryFee: deliveryFee,
      lines: lines,
      subtotal: subtotal,
      discount: discount,
      skuDiscountTotal: resolvedSkuDiscount,
      invoiceDiscountTotal: resolvedInvoiceDiscount,
      tax: tax,
      total: total,
      isTaxApplicable: isTaxApplicable,
      invoiceDiscounts: invoiceDiscounts,
      notes: notes,
      currencySymbol: currencySymbol,
    );
  }

  /// Reads the drawing file into bytes for the PDF, or null when the path is
  /// empty/missing/unreadable — a missing drawing must never fail the export.
  static Uint8List? _readDrawing(String? path) {
    if (path == null || path.isEmpty) return null;
    try {
      return readLocalFileSync(path);
    } catch (_) {
      return null;
    }
  }
}
