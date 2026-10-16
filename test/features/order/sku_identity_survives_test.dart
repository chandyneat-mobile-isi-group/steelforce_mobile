import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart'
    hide CartItem, Category, Product;
import 'package:steelforce/features/order/data/local/cart_drift_local_data_source.dart';
import 'package:steelforce/features/order/data/local/order_line_codec.dart';
import 'package:steelforce/features/order/data/local/product_drift_local_data_source.dart';
import 'package:steelforce/features/order/data/local/quotation_local_data_source.dart';
import 'package:steelforce/features/order/data/local/sales_order_local_data_source.dart';
import 'package:steelforce/features/order/data/mock/isi_demo_catalog.dart';
import 'package:steelforce/features/order/data/models/product_model.dart';
import 'package:steelforce/features/order/data/repositories/cart_repository_impl.dart';
import 'package:steelforce/features/order/data/repositories/quotation_repository_impl.dart';
import 'package:steelforce/features/order/data/repositories/sales_order_repository_impl.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/fulfillment.dart';
import 'package:steelforce/features/order/domain/entities/order_line_validation.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_status.dart';
import 'package:steelforce/features/order/domain/usecases/validate_order_line.dart';

/// The chain the whole feature exists to protect:
///
///   SKU → cart → quotation → sales order
///
/// Every test here asks the same question at a different link: is this still
/// the exact material, at the exact location, at the exact price the rep
/// agreed? A generic "productId" survived all of this before; the identity
/// around it did not.
void main() {
  late AppDatabase db;
  late ProductDriftLocalDataSource catalog;
  late CartRepositoryImpl cart;
  late QuotationRepositoryImpl quotations;
  late SalesOrderRepositoryImpl salesOrders;

  /// Two rows of the *same material* at two different warehouses — the case
  /// that motivated all of this. They share a name, a code and a material
  /// code, and differ only in `id`/`sku`/`warehouse_code` and their stock.
  late Product factorySku;
  late Product branchSku;

  /// The demo catalog's pricing block with one flat standard price and no
  /// promotion, so a test asserting on `effectivePrice` is asserting on the
  /// number it set rather than on whatever promo the fixture happened to carry.
  Map<String, dynamic> flatPrice(Map<String, dynamic> base, double price) => {
        ...Map<String, dynamic>.from(base['pricing'] as Map),
        'standardPrice': price,
        'promotionPrice': null,
        'promotionType': null,
        'promotionLabel': null,
      };

  Future<void> seed() async {
    final base = IsiDemoCatalog.products().first;
    Map<String, dynamic> variant(String warehouse, double qty, double price) =>
        {
          ...base,
          'id': 'GI-030-$warehouse',
          'sku': 'GI-030-$warehouse',
          'code': 'GI-030',
          'materialCode': 'MAT-000042',
          'barcode': 'BC-GI-030-$warehouse',
          'name': 'GI Steel Sheet 0.30mm',
          'warehouseCode': warehouse,
          'stockQuantity': qty,
          'reservedQuantity': 0.0,
          'isMto': false,
          'status': 'active',
          'pricing': flatPrice(base, price),
        };

    await catalog.upsertProducts([
      ProductModel.fromJson(variant('WH-FAC', 1250, 8.50)),
      ProductModel.fromJson(variant('WH-BRN', 45, 9.10)),
    ]);
    factorySku = (await catalog.getById('GI-030-WH-FAC'))!;
    branchSku = (await catalog.getById('GI-030-WH-BRN'))!;
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    catalog = ProductDriftLocalDataSource(db.catalogDao);
    cart = CartRepositoryImpl(
      cartLocal: CartDriftLocalDataSource(db.cartDao),
      productLocal: catalog,
    );
    quotations = QuotationRepositoryImpl(
      local: QuotationLocalDataSourceImpl(db.quotationDao),
      productLocal: catalog,
    );
    salesOrders = SalesOrderRepositoryImpl(
      local: SalesOrderLocalDataSourceImpl(db.salesOrderDao),
      productLocal: catalog,
    );
    await seed();
  });

  tearDown(() => db.close());

  CartItem lineFor(
    Product sku, {
    double quantity = 3,
    double discountPercent = 0,
    double? unitPrice,
    ShipmentSelection? fulfillment,
  }) =>
      CartItem(
        id: 'line-${sku.id}',
        product: sku,
        quantity: quantity,
        unit: sku.unit,
        discountPercent: discountPercent,
        unitPriceOverride: unitPrice,
        fulfillment: fulfillment,
      );

  group('a product row is a SKU', () {
    test('same material at two warehouses is two distinct SKUs', () {
      expect(factorySku.materialCode, branchSku.materialCode);
      expect(factorySku.code, branchSku.code);
      expect(factorySku.name, branchSku.name);

      // ...and yet they are not the same sellable thing.
      expect(factorySku.id, isNot(branchSku.id));
      expect(factorySku.warehouseCode, isNot(branchSku.warehouseCode));
    });

    test('each SKU carries its own location stock, never a global figure',
        () async {
      expect(factorySku.availableQuantity, 1250);
      expect(branchSku.availableQuantity, 45);
    });

    test('each SKU carries its own price', () {
      expect(factorySku.effectivePrice, 8.50);
      expect(branchSku.effectivePrice, 9.10);
    });
  });

  group('cart', () {
    test('two SKUs of one material stay two separate lines', () async {
      await cart.addItem(lineFor(factorySku));
      await cart.addItem(lineFor(branchSku));

      final items = (await cart.fetchCart())
          .when(success: (i) => i, failure: (f) => throw StateError(f.message));

      expect(items, hasLength(2));
      expect(
        items.map((i) => i.stockLocationCode).toSet(),
        {'WH-FAC', 'WH-BRN'},
      );
    });

    test('the agreed price survives a catalog price change', () async {
      await cart.addItem(lineFor(factorySku, unitPrice: 8.50));

      // SAP pushes a price delta into the same SKU.
      await catalog.upsertProducts([
        ProductModel.fromJson({
          ...IsiDemoCatalog.products().first,
          'id': 'GI-030-WH-FAC',
          'sku': 'GI-030-WH-FAC',
          'code': 'GI-030',
          'materialCode': 'MAT-000042',
          'barcode': 'BC-GI-030-WH-FAC',
          'warehouseCode': 'WH-FAC',
          'stockQuantity': 1250.0,
          'reservedQuantity': 0.0,
          'pricing': flatPrice(IsiDemoCatalog.products().first, 99.99),
        }),
      ]);

      final items = (await cart.fetchCart())
          .when(success: (i) => i, failure: (f) => throw StateError(f.message));

      expect(items.single.unitPrice, 8.50,
          reason: 'a quoted line must not re-price itself under the rep');
    });

    test('fulfillment terms round-trip through the database', () async {
      const shipment = ShipmentSelection(
        method: ShipmentMethod.delivery,
        deliveryAddressOption: DeliveryAddressOption.newAddress,
        newAddress: 'St 271, Toul Kork',
        newPhone: '012345678',
      );
      await cart.addItem(lineFor(factorySku, fulfillment: shipment));

      final items = (await cart.fetchCart())
          .when(success: (i) => i, failure: (f) => throw StateError(f.message));

      expect(items.single.fulfillment, shipment);
    });
  });

  group('quotation', () {
    test('SKU identity, price, discount and location all survive a save',
        () async {
      const shipment = ShipmentSelection(
        method: ShipmentMethod.pickup,
        pickupLocation: PickupLocation.branch,
      );
      final saved = (await quotations.saveQuotation(
        items: [
          lineFor(branchSku,
              quantity: 4,
              discountPercent: 7.5,
              unitPrice: 9.10,
              fulfillment: shipment),
        ],
        depotId: 'cust-1',
      ))
          .when(success: (q) => q, failure: (f) => throw StateError(f.message));

      final reloaded = (await quotations.getQuotationById(saved.id)).when(
          success: (q) => q!, failure: (f) => throw StateError(f.message));

      final line = reloaded.lines.single;
      expect(line.skuId, 'GI-030-WH-BRN');
      expect(line.skuCode, 'GI-030-WH-BRN');
      expect(line.materialCode, 'MAT-000042');
      expect(line.stockLocationCode, 'WH-BRN');
      expect(line.quantity, 4);
      expect(line.discountPercent, 7.5);
      expect(line.unitPrice, 9.10);
      expect(line.fulfillment, shipment);
    });

    test('a line whose SKU leaves the catalog is preserved, not dropped',
        () async {
      final saved = (await quotations.saveQuotation(
        items: [lineFor(factorySku, quantity: 2, unitPrice: 8.50)],
      ))
          .when(success: (q) => q, failure: (f) => throw StateError(f.message));

      // The material is retired in SAP and soft-deleted locally.
      await catalog.markDeleted(['GI-030-WH-FAC']);

      final reloaded = (await quotations.getQuotationById(saved.id)).when(
          success: (q) => q!, failure: (f) => throw StateError(f.message));

      expect(reloaded.lines, hasLength(1),
          reason: 'a document already shown to a depot cannot lose a line');

      final line = reloaded.lines.single;
      expect(line.skuId, 'GI-030-WH-FAC');
      expect(line.materialCode, 'MAT-000042');
      expect(line.stockLocationCode, 'WH-FAC');
      expect(line.unitPrice, 8.50);
      expect(line.product.name, 'GI Steel Sheet 0.30mm');

      // ...but it can never be sold again.
      expect(line.product.status, ProductStatus.discontinued);
      expect(line.product.isAvailable, isFalse);
    });

    test('the stored total still matches the lines after a catalog change',
        () async {
      final saved = (await quotations.saveQuotation(
        items: [lineFor(factorySku, quantity: 2, unitPrice: 8.50)],
      ))
          .when(success: (q) => q, failure: (f) => throw StateError(f.message));

      await catalog.markDeleted(['GI-030-WH-FAC']);

      final reloaded = (await quotations.getQuotationById(saved.id)).when(
          success: (q) => q!, failure: (f) => throw StateError(f.message));

      final lineSum =
          reloaded.lines.fold<double>(0, (sum, l) => sum + l.lineSubtotal);
      expect(lineSum, closeTo(saved.subtotal, 0.001));
    });
  });

  group('quotation → sales order', () {
    test('SKU identity and money survive the conversion', () async {
      const shipment = ShipmentSelection(
        method: ShipmentMethod.pickup,
        pickupLocation: PickupLocation.factory,
      );
      final lines = [
        lineFor(factorySku,
            quantity: 6,
            discountPercent: 5,
            unitPrice: 8.50,
            fulfillment: shipment),
      ];
      final quotation = (await quotations.saveQuotation(items: lines))
          .when(success: (q) => q, failure: (f) => throw StateError(f.message));

      final order = (await salesOrders.createFromQuotation(quotation,
              items: lines))
          .when(success: (o) => o, failure: (f) => throw StateError(f.message));

      final reloaded = (await salesOrders.getSalesOrderById(order.id)).when(
          success: (o) => o!, failure: (f) => throw StateError(f.message));

      final line = reloaded.lines.single;
      expect(line.skuId, 'GI-030-WH-FAC');
      expect(line.materialCode, 'MAT-000042');
      expect(line.stockLocationCode, 'WH-FAC');
      expect(line.quantity, 6);
      expect(line.discountPercent, 5);
      expect(line.unitPrice, 8.50);
      expect(line.fulfillment, shipment,
          reason: 'the plant still has to know where this ships from');
    });

    test('a customized line keeps its customization through conversion',
        () async {
      final lines = [
        CartItem(
          id: 'custom-1',
          product: factorySku,
          quantity: 2,
          unit: factorySku.unit,
          discountPercent: 0,
          unitPriceOverride: 8.50,
          isCustomized: true,
          appearance: 'Matte blue',
          customizationDescription: 'Cut to 2.4 m',
        ),
      ];
      final quotation = (await quotations.saveQuotation(items: lines))
          .when(success: (q) => q, failure: (f) => throw StateError(f.message));

      final order = (await salesOrders.createFromQuotation(quotation,
              items: lines))
          .when(success: (o) => o, failure: (f) => throw StateError(f.message));

      final reloaded = (await salesOrders.getSalesOrderById(order.id)).when(
          success: (o) => o!, failure: (f) => throw StateError(f.message));

      final line = reloaded.lines.single;
      expect(line.isCustomized, isTrue,
          reason: 'the sales-order encoder used to omit customization');
      expect(line.appearance, 'Matte blue');
      expect(line.customizationDescription, 'Cut to 2.4 m');
    });
  });

  group('quantity validation', () {
    test('more than the warehouse holds is still allowed', () {
      // Material selection is independent of stock. This used to be refused,
      // and for a material from the selection API — which supplies no on-hand
      // figure at all, so `availableQuantity` is 0 — it refused every line.
      final verdict = validateAgainstSku(sku: branchSku, quantity: 100);
      expect(verdict.isValid, isTrue);
      // Still *reported*, for anything that wants to show it. Just not a gate.
      expect(verdict.availableQuantity, 45);
    });

    test('the same quantity is fine at the warehouse that has it', () {
      expect(
          validateAgainstSku(sku: factorySku, quantity: 100).isValid, isTrue);
    });

    test('lines already in the cart do not restrict a new one', () {
      expect(
        validateAgainstSku(sku: branchSku, quantity: 30, alreadyInCart: 30)
            .isValid,
        isTrue,
        reason: 'availability is settled later in the workflow, not here',
      );
    });

    test('zero and negative quantities are rejected as their own case', () {
      expect(validateAgainstSku(sku: factorySku, quantity: 0).issue,
          OrderLineIssue.nonPositiveQuantity);
      expect(validateAgainstSku(sku: factorySku, quantity: -5).issue,
          OrderLineIssue.nonPositiveQuantity);
    });

    test('stock is always reported as stale, never as a SAP reservation', () {
      expect(validateAgainstSku(sku: factorySku, quantity: 1).isStockStale,
          isTrue);
    });
  });

  group('legacy blobs', () {
    test('a pre-snapshot line still resolves and prices from the catalog',
        () async {
      // Exactly what the old encoder wrote: no sku, no price, no location.
      const legacy = '[{"productId":"GI-030-WH-FAC","quantity":2,'
          '"unit":"M","discountPercent":0}]';

      final lines = await OrderLineCodec(catalog).decode(legacy);

      expect(lines, hasLength(1));
      expect(lines.single.skuId, 'GI-030-WH-FAC');
      expect(lines.single.unitPrice, 8.50,
          reason: 'no snapshot falls back to the live catalog price, '
              'which is what those documents always did');
    });
  });
}
