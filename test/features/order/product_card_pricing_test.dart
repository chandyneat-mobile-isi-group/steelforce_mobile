import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/order/domain/entities/mobile_price.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_pricing.dart';
import 'package:steelforce/features/order/domain/entities/product_status.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/product_result_card.dart';

/// The depot-specific price on the selection card.
///
/// The card previously showed no price at all, deliberately: the only figure
/// available to it was `Product.pricing`, a catalogue number that is not what
/// this depot pays and that rendered `$0.00` against perfectly orderable
/// materials. That rule has not been relaxed — these tests pin both halves of
/// it. The catalogue figure still never appears; what appears is the amount
/// the pricing endpoint quoted for this depot, matched to the card by SAP
/// material number, with its states kept apart.

/// A catalogue price that must never reach the screen. `standardPrice` is
/// 11.59, so any `11.59` in the rendered output is this leaking.
const _catalogue = ProductPricing(
  costPrice: 8,
  standardPrice: 11.59,
  wholesalePrice: 11,
  dealerPrice: 10.5,
  vipPrice: 10,
  creditPrice: 12,
  cashPrice: 11,
  currency: 'USD',
);

Product _product() => Product(
      id: 'p1',
      familyId: 'f1',
      familyName: 'Roofing',
      code: 'C1',
      sku: 'SKU1',
      materialCode: '1100000000',
      barcode: '',
      name: 'GI Steel Sheet',
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
      warehouseCode: 'WH1',
      territory: 'T1',
      businessUnit: 'BU1',
      imageUrl: '',
      isMto: false,
      status: ProductStatus.active,
      updatedAt: DateTime(2026, 1, 1),
      pricing: _catalogue,
      stockQuantity: 0,
      reservedQuantity: 0,
      minStock: 0,
      maxStock: 1000,
      stockKnown: true,
    );

MobilePrice _priced({
  double? amount = 1250.5,
  String currency = 'USD',
  PricingState state = PricingState.loaded,
  PricingErrorKind errorKind = PricingErrorKind.none,
  bool isStale = false,
}) =>
    MobilePrice(
      material: '1100000000',
      state: state,
      price: amount,
      currency: currency,
      errorKind: errorKind,
      isStale: isStale,
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  late int retries;

  Future<void> pump(WidgetTester tester, MobilePrice? price) async {
    retries = 0;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light(AppTypography.latinFontFamily),
          home: Scaffold(
            body: ProductResultCard(
              product: _product(),
              isFavorite: false,
              quantity: 0,
              onQuantityChanged: (_) {},
              onToggleFavorite: () {},
              price: price,
              onPriceRetry: () => retries++,
            ),
          ),
        ),
      ),
    );
    // `pumpAndSettle` would time out on the loading spinner, which never stops.
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('the backend price is what is shown', () {
    testWidgets('the quoted amount, with its currency and unit',
        (tester) async {
      await pump(tester, _priced());

      expect(find.text(r'$1,250.50'), findsOneWidget);
      expect(find.text('/ KG'), findsOneWidget);
    });

    testWidgets('a non-USD price is not stamped with a dollar sign',
        (tester) async {
      // The currency travels on every item precisely so this cannot happen:
      // rendering 5,000,000 KHR as `$5,000,000.00` is a figure off by a factor
      // of about four thousand, and it looks entirely plausible.
      await pump(tester, _priced(amount: 5000000, currency: 'KHR'));

      expect(find.text('5,000,000.00 KHR'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
    });

    testWidgets('a live price is marked live', (tester) async {
      await pump(tester, _priced());
      expect(find.text('Live'), findsOneWidget);
    });
  });

  group('the catalogue price never leaks', () {
    testWidgets('no figure at all when there is no pricing context',
        (tester) async {
      // The resting state on a screen with no depot. `Product.pricing` is
      // populated here and must still produce nothing.
      await pump(tester, null);

      expect(find.textContaining(r'$'), findsNothing);
      expect(find.textContaining('11.59'), findsNothing);
    });

    testWidgets('the catalogue figure is not substituted for a failed price',
        (tester) async {
      await pump(
          tester,
          _priced(
            amount: null,
            state: PricingState.error,
            errorKind: PricingErrorKind.backendUnavailable,
          ));

      expect(find.textContaining('11.59'), findsNothing);
    });

    testWidgets('a quoted zero is treated as no price, not as free',
        (tester) async {
      // `$0.00` on a quotation is a promise a depot can hold the rep to.
      await pump(tester, _priced(amount: 0));

      expect(find.textContaining(r'$0'), findsNothing);
      expect(find.textContaining('0.00'), findsNothing);
    });
  });

  group('the states stay apart', () {
    testWidgets('loading says so and shows no amount', (tester) async {
      await pump(tester, const MobilePrice.loading('1100000000'));

      expect(find.text('Loading current price…'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
    });

    testWidgets('a settled "no price" offers no retry', (tester) async {
      // The backend answered. Retrying asks the same question again.
      await pump(
          tester,
          _priced(
            amount: null,
            state: PricingState.unavailable,
            errorKind: PricingErrorKind.noPrice,
          ));

      expect(find.text('No price for this depot'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a walk-in is told to pick a depot, not shown an error',
        (tester) async {
      await pump(
          tester,
          _priced(
            amount: null,
            state: PricingState.unavailable,
            errorKind: PricingErrorKind.depotNotFound,
          ));

      expect(find.text('Select a depot to see pricing'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('being offline says so rather than "unavailable"',
        (tester) async {
      // "You are offline" sends a rep to find signal. One generic error
      // message sends them nowhere.
      await pump(
          tester,
          _priced(
            amount: null,
            state: PricingState.error,
            errorKind: PricingErrorKind.networkUnavailable,
          ));

      expect(find.text('Offline — price not available'), findsOneWidget);
    });

    testWidgets('a failed request offers a retry that fires', (tester) async {
      await pump(
          tester,
          _priced(
            amount: null,
            state: PricingState.error,
            errorKind: PricingErrorKind.backendUnavailable,
          ));

      expect(find.text('Pricing service unavailable'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retries, 1);
    });

    testWidgets('a held price that is no longer live loses the live mark',
        (tester) async {
      // The figure stays — a rep mid-conversation should not watch it vanish —
      // but it stops claiming to be current.
      await pump(
          tester,
          _priced(
            state: PricingState.reconnecting,
            isStale: true,
          ));

      expect(find.text(r'$1,250.50'), findsOneWidget);
      expect(find.text('Live'), findsNothing);
      expect(find.text('Not live'), findsOneWidget);
    });
  });

  group('selection is still never gated', () {
    testWidgets('a material with no price still adds to the cart',
        (tester) async {
      int? changed;
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light(AppTypography.latinFontFamily),
            home: Scaffold(
              body: ProductResultCard(
                product: _product(),
                isFavorite: false,
                quantity: 0,
                onQuantityChanged: (v) => changed = v,
                onToggleFavorite: () {},
                price: _priced(
                  amount: null,
                  state: PricingState.error,
                  errorKind: PricingErrorKind.backendUnavailable,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(changed, 1,
          reason: 'pricing informs the quotation; it must not block it');
    });
  });
}
