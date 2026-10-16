import 'dart:convert';

import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/local/product_local_data_source.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/fulfillment.dart';
import 'package:steelforce/features/order/domain/entities/price_tier.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_pricing.dart';
import 'package:steelforce/features/order/domain/entities/product_status.dart';
import 'package:steelforce/features/order/domain/services/product_customization_spec.dart';

/// The one encoder/decoder for the `lines_json` blob shared by `quotations` and
/// `sales_orders`.
///
/// It exists because the two repositories had grown their own copies and they
/// had already drifted: the quotation encoder wrote a `customization` key and
/// the sales-order encoder did not, so converting a customized quotation into a
/// sales order silently dropped the measurements and the drawing. One codec
/// makes that class of bug unrepresentable rather than merely fixed.
///
/// ## The blob is a snapshot, not a foreign key
///
/// It used to hold `{productId, quantity, unit, discountPercent}` and rebuild
/// everything else by re-reading the catalog. Two things followed, both wrong:
///
/// 1. **Price moved.** `prices` is SAP master data replaced wholesale on sync,
///    so a saved quotation re-priced itself under the rep's feet while the
///    stored `total` stayed put.
/// 2. **Lines vanished.** The decoder did `if (product == null) continue`, so a
///    soft-deleted or re-keyed material erased its line from a document that
///    had already been shown to a depot — leaving totals that no set of
///    visible lines added up to.
///
/// So every line now carries its own SKU identity and money. The catalog is
/// still consulted, because a live row has the current image, dimensions and
/// stock the UI wants; but it is an enrichment, never the source of the
/// line's identity, and its absence downgrades the line rather than deleting
/// it (see [_tombstone]).
class OrderLineCodec {
  const OrderLineCodec(this._products);

  final ProductLocalDataSource _products;

  String encode(List<CartItem> items) => jsonEncode([
        for (final item in items) _encodeLine(item),
      ]);

  DataMap _encodeLine(CartItem item) => {
        // `productId` keeps its original key and leading position: rows written
        // by every previous build use it, and it is what the decoder still
        // joins on.
        'productId': item.skuId,

        // The SKU identity, written out rather than derived. A reader — the PDF
        // generator, a future SAP mapper, a support engineer looking at the
        // blob — must be able to see which material at which location was sold
        // without needing the catalog that produced it.
        'sku': item.skuCode,
        'materialCode': item.materialCode,
        'productCode': item.productCode,
        'warehouseCode': item.stockLocationCode,
        'productName': item.product.name,
        'productNameKh': item.product.nameKh,

        'quantity': item.quantity,
        'unit': item.unit,
        'discountPercent': item.discountPercent,

        // Money as agreed, not as currently listed.
        'unitPrice': item.unitPrice,
        'priceTier': item.priceTier.name,
        'currency': item.product.pricing.currency,

        'fulfillment': ShipmentSelection.encode(item.fulfillment),

        // Customization travels as a nested JSON string (null for plain lines)
        // so quotations, sales orders and the PDF keep the exact customized
        // spec. Present on *both* document types now.
        'customization': ProductCustomizationSpec.encode(item),
      };

  Future<List<CartItem>> decode(
    String json, {
    String? depotId,
    String? leadId,
  }) async {
    final raw = (jsonDecode(json) as List).cast<DataMap>();
    final items = <CartItem>[];

    for (var i = 0; i < raw.length; i++) {
      final line = raw[i];
      final skuId = line['productId'] as String;

      // Enrichment, not resolution: a missing row costs the line its live
      // catalog detail, never its existence.
      final live = await _products.getById(skuId);
      final product = live ?? _tombstone(skuId, line);

      final base = CartItem(
        id: '$skuId-$i',
        product: product,
        quantity: (line['quantity'] as num).toDouble(),
        unit: line['unit'] as String,
        discountPercent: (line['discountPercent'] as num).toDouble(),
        leadId: leadId,
        depotId: depotId,
        priceTier: _tier(line['priceTier'] as String?),
        // Absent on blobs written before the snapshot existed, which correctly
        // falls back to live catalog pricing — the only behaviour those
        // documents ever had.
        unitPriceOverride: (line['unitPrice'] as num?)?.toDouble(),
        fulfillment: ShipmentSelection.decode(line['fulfillment'] as String?),
      );

      items.add(ProductCustomizationSpec.applyEncoded(
          base, line['customization'] as String?));
    }
    return items;
  }

  static PriceTier _tier(String? name) {
    if (name == null) return PriceTier.standard;
    for (final tier in PriceTier.values) {
      if (tier.name == name) return tier;
    }
    return PriceTier.standard;
  }

  /// A [Product] reconstructed from the line's own snapshot, for a SKU the
  /// catalog can no longer resolve.
  ///
  /// Marked [ProductStatus.discontinued] with zero stock, so every existing
  /// availability check treats it as unsellable and it cannot be re-added to a
  /// cart — while the document that already contains it still renders the
  /// material, the location and the price the depot was quoted.
  ///
  /// Blobs written before the snapshot columns existed have no name or code to
  /// recover; those fields come back empty and the SKU id stands in, which is
  /// still strictly more than the old decoder's silent `continue`.
  static Product _tombstone(String skuId, DataMap line) {
    final name = (line['productName'] as String?) ?? skuId;
    final unitPrice = (line['unitPrice'] as num?)?.toDouble() ?? 0;

    return Product(
      id: skuId,
      familyId: '',
      familyName: '',
      code: (line['productCode'] as String?) ?? '',
      sku: (line['sku'] as String?) ?? skuId,
      materialCode: (line['materialCode'] as String?) ?? '',
      barcode: '',
      name: name,
      nameKh: (line['productNameKh'] as String?) ?? '',
      description: '',
      categoryId: '',
      subCategory: '',
      brand: '',
      grade: '',
      material: '',
      size: '',
      diameter: 0,
      thickness: 0,
      length: 0,
      width: 0,
      height: 0,
      weight: 0,
      unit: (line['unit'] as String?) ?? '',
      warehouseCode: (line['warehouseCode'] as String?) ?? '',
      territory: '',
      businessUnit: '',
      imageUrl: '',
      isMto: false,
      status: ProductStatus.discontinued,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      pricing: ProductPricing(
        costPrice: 0,
        standardPrice: unitPrice,
        wholesalePrice: unitPrice,
        dealerPrice: unitPrice,
        vipPrice: unitPrice,
        creditPrice: unitPrice,
        cashPrice: unitPrice,
        currency: (line['currency'] as String?) ?? 'USD',
      ),
      stockQuantity: 0,
      reservedQuantity: 0,
      minStock: 0,
      maxStock: 0,
    );
  }
}
