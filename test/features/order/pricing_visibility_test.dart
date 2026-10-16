import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/pricing_status.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_pricing.dart';
import 'package:steelforce/features/order/domain/entities/product_status.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/pricing_text.dart';

const _priced = ProductPricing(
  costPrice: 8,
  standardPrice: 11.59,
  wholesalePrice: 11,
  dealerPrice: 10.5,
  vipPrice: 10,
  creditPrice: 12,
  cashPrice: 11,
  currency: 'USD',
);

Product _product({ProductPricing pricing = _priced}) => Product(
      id: 'p1',
      familyId: 'f1',
      familyName: 'Roofing',
      code: 'C1',
      sku: 'SKU1',
      materialCode: 'MAT-1',
      barcode: '',
      name: 'Colour Coated Coil',
      description: '',
      categoryId: 'cat1',
      subCategory: '',
      brand: 'ISI',
      grade: '',
      material: '',
      size: '',
      diameter: 0,
      thickness: 0,
      length: 0,
      width: 0,
      height: 0,
      weight: 0,
      unit: 'KG',
      warehouseCode: '',
      territory: '',
      businessUnit: '',
      imageUrl: '',
      isMto: false,
      status: ProductStatus.active,
      updatedAt: DateTime(2026, 1, 1),
      pricing: pricing,
      stockQuantity: 0,
      reservedQuantity: 0,
      minStock: 0,
      maxStock: 0,
      stockKnown: false,
    );

CartItem _line({
  ProductPricing pricing = _priced,
  double? override,
  double quantity = 10,
}) =>
    CartItem(
      id: 'l1',
      product: _product(pricing: pricing),
      quantity: quantity,
      unit: 'KG',
      discountPercent: 0,
      unitPriceOverride: override,
    );

void main() {
  group('a line knows whether it has a price', () {
    test('a real catalogue price is available', () {
      expect(_line().pricingStatus, PricingStatus.available);
      expect(_line().isPricePending, isFalse);
      expect(_line().unitPriceOrNull, 11.59);
    });

    test('no catalogue price is waiting for HQ', () {
      final line = _line(pricing: const ProductPricing.unpriced());
      expect(line.pricingStatus, PricingStatus.waitingForHq);
      expect(line.unitPriceOrNull, isNull);
      expect(line.lineTotalOrNull, isNull);
    });

    test('a snapshotted zero is not a price', () {
      // The bug this guards: `unitPrice: product.effectivePrice` froze `0.0`
      // for an unpriced material, a non-null override was read as
      // authoritative, and the quotation printed `$0.00`.
      final line = _line(pricing: const ProductPricing.unpriced(), override: 0);
      expect(line.pricingStatus, PricingStatus.waitingForHq);
      expect(line.unitPriceOrNull, isNull);
    });

    test('a real snapshot survives the catalogue losing its price', () {
      final line =
          _line(pricing: const ProductPricing.unpriced(), override: 25.50);
      expect(line.pricingStatus, PricingStatus.available);
      expect(line.unitPriceOrNull, 25.50);
      expect(line.lineTotalOrNull, 255.0);
    });
  });

  group('a document is pending if any line is', () {
    test('all priced', () {
      expect([_line(), _line()].hasPendingPricing, isFalse);
      expect([_line()].pricedSubtotal, 115.9);
    });

    test('one unpriced makes the whole document pending', () {
      // A subtotal that silently drops the pending line is a smaller, wronger
      // number than none at all — and it is the one the depot sees.
      final lines = [_line(), _line(pricing: const ProductPricing.unpriced())];
      expect(lines.hasPendingPricing, isTrue);
      expect(lines.pricedSubtotal, isNull);
    });
  });

  group('an absent amount renders as nothing', () {
    test('null is hidden', () {
      expect(PricingText.isHidden(null), isTrue);
      expect(PricingText.amountOrNull(null), isNull);
      expect(PricingText.amount(null), '');
    });

    test('zero is hidden', () {
      // `$0.00` on a quotation is a quoted price of zero, not a blank.
      expect(PricingText.isHidden(0), isTrue);
      expect(PricingText.amount(0), '');
      expect(PricingText.amount(0.0), isNot(contains('0.00')));
    });

    test('a negative is hidden', () {
      expect(PricingText.isHidden(-1), isTrue);
    });

    test('a real amount is shown', () {
      expect(PricingText.amount(25.5), r'$25.50');
      expect(PricingText.amount(1200, decimals: 0), r'$1200');
    });

    test('never emits a placeholder word', () {
      for (final rendered in [
        PricingText.amount(null),
        PricingText.amount(0),
      ]) {
        expect(rendered, isNot(contains('N/A')));
        expect(rendered, isNot(contains('Unknown')));
        expect(rendered, isNot(contains(r'$')));
      }
    });
  });

  group('document roll-up', () {
    test('is hidden while any line is pending', () {
      final lines = [_line(pricing: const ProductPricing.unpriced())];
      expect(PricingText.totalOrNull(lines, 0), isNull);
    });

    test('is shown once every line is priced', () {
      expect(PricingText.totalOrNull([_line()], 115.9), r'$115.90');
    });
  });
}
