import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';

/// Presents a device-only [Quotation] in the server's [QuotationDetail] shape,
/// so the detail screen can still show it when the API cannot be reached.
///
/// Fields the device copy does not carry (shipment type, currency, revision)
/// take the defaults a fresh server draft would have; totals are estimates.
extension QuotationOfflineDetail on Quotation {
  QuotationDetail toOfflineDetail() {
    return QuotationDetail(
      id: id,
      number: id,
      depotId: depotId ?? '',
      depotName: shopName,
      status: status.name,
      statusGroup: QuotationStatusGroup.drafts,
      shipmentType: 'Pickup',
      currency: 'USD',
      lines: lines.asMap().entries.map((e) {
        final item = e.value;
        return QuotationLineItem(
          id: '$id-${e.key}',
          lineNumber: e.key + 1,
          materialNumber: item.product.code,
          materialDescription: item.product.name,
          quantity: item.quantity.toDouble(),
          unit: item.product.unit,
          priceAmount: item.unitPrice,
          priceCurrency: 'USD',
          pricePricingUnit: 1,
          priceConditionUnit: item.product.unit,
          discounts: const [],
          gross: item.lineSubtotal,
          discountTotal: item.lineDiscount,
          net: item.lineTotal,
        );
      }).toList(),
      totals: QuotationTotals(
        currency: 'USD',
        gross: subtotal,
        discountTotal: discount,
        net: total,
        tax: tax,
        isEstimate: true,
      ),
      revision: 1,
      requiredApprovalLevel: 1,
      validTo: validUntil,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
