import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/promotion_section.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/promotions_mock_data.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/shipment_widget_section.dart';
import 'package:steelforce/shared/widgets/promotions/promo_blocked_note.dart';
import 'package:steelforce/shared/widgets/promotions/promo_card.dart';
import 'package:steelforce/shared/widgets/promotions/promo_view.dart';

/// The COD / Pickup discount is earned by collecting from the depot. Choosing
/// Delivery takes it off the table, and the Cash-on-Delivery toggle — despite
/// the promotion's name and the BRD calling the mechanism an "Immediate-Payment
/// Discount" — does not bring it back.
///
/// That last part is the one a future reader is most likely to "fix", so it is
/// asserted explicitly rather than left implied by its absence.
final _now = DateTime(2026, 3, 10, 9);

final _pickupOnly = PromoView(
  id: 'cod',
  title: 'COD / Pickup Discount — All Categories',
  kind: PromoKind.paymentTerm,
  value: const PromoPercent(1),
  status: PromoStatus.active,
  endsOn: _now.add(const Duration(days: 20)),
  requires: const {PromoRequirement.pickup},
);

final _unconditional = PromoView(
  id: 'rebar',
  title: 'On-Invoice Discount — Rebar',
  kind: PromoKind.onInvoice,
  value: const PromoPercent(2),
  status: PromoStatus.active,
  endsOn: _now.add(const Duration(days: 20)),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting();
    await LocalizationService.instance.load('en');
  });

  group('OrderTerms eligibility', () {
    test('pickup earns it, delivery does not', () {
      expect(
        _pickupOnly.isAvailableFor(_now, const OrderTerms(isPickup: true)),
        isTrue,
      );
      expect(
        _pickupOnly.isAvailableFor(_now, const OrderTerms(isPickup: false)),
        isFalse,
      );
    });

    test('an unconditional promotion is unaffected by the shipment method', () {
      for (final pickup in [true, false]) {
        expect(
          _unconditional.isAvailableFor(_now, OrderTerms(isPickup: pickup)),
          isTrue,
        );
      }
    });

    test('no order context blocks nothing', () {
      // The outlet promotions list shows what a depot is entitled to, not what
      // one quotation currently earns, so it passes no terms.
      expect(_pickupOnly.isAvailableFor(_now, null), isTrue);
      expect(_pickupOnly.unmetRequirement(null), isNull);
    });

    test('the reason names the requirement, not just a failure', () {
      expect(
        _pickupOnly.unmetRequirement(const OrderTerms(isPickup: false)),
        PromoRequirement.pickup,
      );
    });

    test('an expired promotion is unavailable even on pickup', () {
      final expired = PromoView(
        id: 'x',
        title: 'x',
        kind: PromoKind.paymentTerm,
        value: const PromoPercent(1),
        status: PromoStatus.active,
        endsOn: _now.subtract(const Duration(days: 1)),
        requires: const {PromoRequirement.pickup},
      );
      expect(
        expired.isAvailableFor(_now, const OrderTerms(isPickup: true)),
        isFalse,
      );
    });
  });

  group('PromotionSectionWidget reacts to the shipment method', () {
    Future<void> pump(WidgetTester tester, {required bool isPickup}) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light('ABCGinto'),
            home: Scaffold(
              body: SingleChildScrollView(
                child: PromotionSectionWidget(
                  groups: [
                    PromoGroup(
                      titleKey: 'promotions.group.cod_pickup',
                      promos: [_pickupOnly],
                    ),
                    PromoGroup(
                      titleKey: 'promotions.group.depot_discount',
                      promos: [_unconditional],
                    ),
                  ],
                  now: _now,
                  terms: OrderTerms(isPickup: isPickup),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('on pickup the discount is offered with no caveat',
        (tester) async {
      await pump(tester, isPickup: true);

      expect(find.byType(PromoCard), findsNWidgets(2));
      expect(find.byType(PromoBlockedNote), findsNothing);
      expect(find.textContaining('2 available'), findsOneWidget);
    });

    testWidgets('on delivery it is shown blocked, with the reason',
        (tester) async {
      await pump(tester, isPickup: false);

      // Still on screen — see PromoBlockedNote's own doc for why it is not
      // simply removed — but carrying the reason and the way back.
      expect(find.byType(PromoCard), findsNWidgets(2));
      expect(find.byType(PromoBlockedNote), findsOneWidget);
      expect(find.text('Only on Pick up'), findsOneWidget);
      expect(
        find.text('Set Method of shipment to Pick up to use this discount.'),
        findsOneWidget,
      );
    });

    testWidgets('the header count drops to what the order can actually use',
        (tester) async {
      await pump(tester, isPickup: false);

      // The number a rep repeats to a depot. Counting a blocked promotion
      // here would be worse than showing no count at all.
      expect(find.textContaining('1 available'), findsOneWidget);
      expect(find.textContaining('2 available'), findsNothing);
    });

    testWidgets('a blocked card cannot be tapped through to the detail screen',
        (tester) async {
      await pump(tester, isPickup: false);

      final blocked = find.ancestor(
        of: find.byType(PromoBlockedNote),
        matching: find.byType(PromoCard),
      );
      final flags = tester.getSemantics(blocked).flagsCollection;
      expect(flags.isEnabled, Tristate.isFalse);
    });
  });

  testWidgets('switching the shipment control re-evaluates the section',
      (tester) async {
    // The end-to-end path: the real `ShipmentSelectionWidget` drives the same
    // state the section reads, which is what makes this reactive rather than a
    // value read once at construction.
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light('ABCGinto'),
          home: const _ShipmentDrivenHarness(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(PromoBlockedNote), findsNothing);

    await tester.tap(find.text('Delivery'));
    await tester.pumpAndSettle();
    expect(find.byType(PromoBlockedNote), findsOneWidget);

    // And back: the discount returns rather than being lost for the rest of
    // the quotation.
    await tester.tap(find.text('Pick up'));
    await tester.pumpAndSettle();
    expect(find.byType(PromoBlockedNote), findsNothing);
  });

  testWidgets('the COD toggle does not unlock a pickup-only discount',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light('ABCGinto'),
          home: const _ShipmentDrivenHarness(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delivery'));
    await tester.pumpAndSettle();

    // "Yes" under Cash on Delivery. ISI's rule is that delivery loses the
    // discount whatever the payment terms — the promotion's own name is the
    // trap here, and this assertion is what stops someone "fixing" it.
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();

    expect(find.byType(PromoBlockedNote), findsOneWidget);
  });
}

/// The quotation builder's shipment/promotions wiring, reduced to the two
/// widgets and the one piece of state that connect them.
class _ShipmentDrivenHarness extends StatefulWidget {
  const _ShipmentDrivenHarness();

  @override
  State<_ShipmentDrivenHarness> createState() => _ShipmentDrivenHarnessState();
}

class _ShipmentDrivenHarnessState extends State<_ShipmentDrivenHarness> {
  ShipmentMethod _method = ShipmentMethod.pickup;
  PickupLocation? _pickupLocation = PickupLocation.factory;
  DeliveryAddressOption? _deliveryOption;
  bool _isCod = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            ShipmentSelectionWidget(
              method: _method,
              pickupLocation: _pickupLocation,
              deliveryOption: _deliveryOption,
              isCod: _isCod,
              onMethodChanged: (method) => setState(() {
                _method = method;
                if (method == ShipmentMethod.pickup) {
                  _pickupLocation ??= PickupLocation.factory;
                  _deliveryOption = null;
                } else {
                  _deliveryOption ??= DeliveryAddressOption.defaultAddress;
                  _pickupLocation = null;
                }
              }),
              onPickupLocationChanged: (l) =>
                  setState(() => _pickupLocation = l),
              onDeliveryOptionChanged: (o) =>
                  setState(() => _deliveryOption = o),
              onCodChanged: (v) => setState(() => _isCod = v),
            ),
            PromotionSectionWidget(
              groups: [
                PromoGroup(
                  titleKey: 'promotions.group.cod_pickup',
                  promos: [_pickupOnly],
                ),
              ],
              now: _now,
              terms: OrderTerms(isPickup: _method == ShipmentMethod.pickup),
            ),
          ],
        ),
      ),
    );
  }
}
