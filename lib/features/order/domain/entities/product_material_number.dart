import 'package:steelforce/features/order/domain/entities/product.dart';

/// The SAP material number for a [Product] — the key `/materials/{material}/stock`
/// is addressed by.
///
/// [Product] carries two identifiers that both look like candidates, and they
/// are not interchangeable:
///
/// * `materialCode` — SAP's own number, `1100000042`. This is the one.
/// * `code` — the platform's catalog code, which for synced rows is often the
///   same string and for locally-created or customized rows is not.
///
/// Getting this wrong fails quietly rather than loudly: the endpoint answers
/// for a material nobody asked about, or 404s, and the badge shows "Stock
/// unknown" against a material that was perfectly sellable. Defined once here
/// so there is a single line to change if the field moves again.
extension ProductMaterialNumber on Product {
  String get materialNumber {
    final sap = materialCode.trim();
    return sap.isNotEmpty ? sap : code.trim();
  }
}
