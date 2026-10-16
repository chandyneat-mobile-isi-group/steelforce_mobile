import 'package:steelforce/features/order/domain/entities/mobile_price.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_material_number.dart';

/// The prices a rep typed in for materials SAP did not price, for one
/// quotation session.
///
/// Keyed by both row id and SAP material number: the same material stocked at
/// several warehouses is several rows, and either lookup must find the price.
/// A SAP price always wins — a manual price only fills a gap.
class ManualPriceBook {
  final Map<String, double> _prices = {};

  double? of(Product product) =>
      _prices[product.id] ?? _prices[product.materialNumber];

  /// Records [price], or forgets the product's price when it is not positive.
  void remember(Product product, double price) {
    if (price > 0) {
      _prices[product.id] = price;
      _prices[product.materialNumber] = price;
    } else {
      _prices.remove(product.id);
      _prices.remove(product.materialNumber);
    }
  }

  /// SAP's price when it has one, otherwise the rep's, otherwise null.
  double? priceFor(Product product, MobilePrice? sap) {
    if (sap != null && sap.hasAmount) return sap.price;
    final manual = of(product);
    if (manual != null && manual > 0) return manual;
    return null;
  }

  /// Whether [priceFor] would answer with the rep's own price.
  bool isManual(Product product, MobilePrice? sap) {
    if (sap != null && sap.hasAmount) return false;
    final manual = of(product);
    return manual != null && manual > 0;
  }
}
