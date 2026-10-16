import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stop_information/promotions_screen.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/promotion_section.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/promotions_mock_data.dart';
import 'package:steelforce/shared/widgets/promotions/promo_card.dart';
import 'package:steelforce/shared/widgets/promotions/promo_filter_bar.dart';
import 'package:steelforce/shared/widgets/promotions/promo_view.dart';

/// Both promotion surfaces take an injected clock and an injected data set, so
/// everything here is pinned rather than relative to the day the suite runs.
/// The screens these replace hardcoded '31 Aug 2026' in their fixtures — the
/// kind of date that turns a green suite red on a Tuesday morning with no code
/// change behind it.
final _now = DateTime(2026, 3, 10, 9);

PromoView _promo({
  required String id,
  required PromoKind kind,
  required int endsInDays,
  PromoStatus status = PromoStatus.active,
  String? code,
}) =>
    PromoView(
      id: id,
      code: code,
      title: 'Promo $id',
      kind: kind,
      value: const PromoPercent(2),
      status: status,
      endsOn: _now.add(Duration(days: endsInDays)),
      category: 'All Structural Steel',
    );

/// Pumps [child] on a surface of a stated size.
///
/// The size is set explicitly every time rather than left to `flutter_test`'s
/// 800x600 default, because that default is not a device: it is wide enough to
/// select the two-column tablet layout and short enough that a list which fits
/// every real phone still overflows it.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: ScreenUtilInit(
        designSize: size,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light('ABCGinto'),
          home: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Every user-visible string on these screens is a `.tr` lookup, and
/// `translate()` returns the key itself on a miss — so a typo ships as literal
/// "promotions.status.active" rather than failing anywhere. This turns that
/// into a test failure.
void _expectNoRawKeys(WidgetTester tester) {
  final leaked = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .where((s) => s.contains('promotions.'))
      .toList();
  expect(leaked, isEmpty, reason: 'untranslated keys rendered: $leaked');
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Mirrors `AppBootstrapService`: without it `DateFormat.yMMMd('en')` has no
    // symbols. `PromoCountdown` falls back rather than throwing, but a test
    // leaning on that fallback would not exercise the formatting the app ships.
    await initializeDateFormatting();
    await LocalizationService.instance.load('en');
  });

  final promos = [
    _promo(
      id: 'expired',
      kind: PromoKind.onInvoice,
      endsInDays: -5,
      status: PromoStatus.expired,
    ),
    _promo(id: 'far', kind: PromoKind.onInvoice, endsInDays: 90),
    _promo(id: 'soon', kind: PromoKind.paymentTerm, endsInDays: 3),
  ];

  group('PromotionsScreen', () {
    testWidgets('lists every promotion and translates every label',
        (tester) async {
      await _pump(
        tester,
        PromotionsScreen(promotions: promos, now: _now, outletName: 'Depot A'),
      );

      expect(find.byType(PromoCard), findsNWidgets(3));
      expect(find.text('Depot A'), findsOneWidget);
      _expectNoRawKeys(tester);
    });

    testWidgets('sinks expired promotions below the quotable ones',
        (tester) async {
      await _pump(tester, PromotionsScreen(promotions: promos, now: _now));

      // Ordering is the guard against a rep quoting a lapsed rate, so it is
      // asserted on geometry rather than on the sort function.
      final expiredY = tester.getTopLeft(find.text('Promo expired')).dy;
      final soonY = tester.getTopLeft(find.text('Promo soon')).dy;
      final farY = tester.getTopLeft(find.text('Promo far')).dy;

      expect(soonY, lessThan(farY), reason: 'soonest expiry leads');
      expect(farY, lessThan(expiredY), reason: 'expired sinks to the bottom');
    });

    testWidgets('states the countdown, not only the end date', (tester) async {
      await _pump(tester, PromotionsScreen(promotions: promos, now: _now));

      expect(find.textContaining('Ends in 3 days'), findsOneWidget);
      expect(find.textContaining('Ended'), findsWidgets);
    });

    testWidgets('a category filter narrows the list', (tester) async {
      await _pump(tester, PromotionsScreen(promotions: promos, now: _now));

      // Scoped to the filter bar: the same label names the mechanism on the
      // card itself, so a bare text finder matches two widgets. And scrolled
      // into view first — the bar scrolls horizontally, and a tap aimed at a
      // chip sitting past the right edge lands on whatever is actually there.
      final chip = find.descendant(
        of: find.byType(PromoFilterBar<PromoKind>),
        matching: find.text('COD / Pickup'),
      );
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(find.byType(PromoCard), findsOneWidget);
      expect(find.text('Promo soon'), findsOneWidget);
    });

    testWidgets('a filter with nothing behind it cannot be entered',
        (tester) async {
      // The old bar offered "OFF-INVOICE (0)" as a live chip, so tapping it
      // took the rep to an empty screen they had to back out of. The count is
      // still shown — the zero is the answer — but it is not a doorway.
      await _pump(
        tester,
        PromotionsScreen(
          promotions: [
            _promo(id: 'a', kind: PromoKind.onInvoice, endsInDays: 5),
          ],
          now: _now,
        ),
      );

      final deadChip = find.ancestor(
        of: find.text('Volume tier'),
        matching: find.byType(Semantics),
      );

      // Asserted on the semantics rather than by tapping and seeing nothing
      // happen: a tap that simply missed would pass that way too, and this is
      // also what a screen reader announces.
      // `Tristate.isFalse`, not `Tristate.none`: the chip must announce that
      // it *has* an enabled state and that the state is off, which is what
      // makes a screen reader say "dimmed" rather than reading it as an
      // ordinary button.
      final flags = tester.getSemantics(deadChip.first).flagsCollection;
      expect(flags.isEnabled, Tristate.isFalse);
    });

    testWidgets('the empty state explains what to do next', (tester) async {
      await _pump(tester, PromotionsScreen(promotions: const [], now: _now));

      expect(find.byType(PromoCard), findsNothing);
      expect(find.text('No promotions for this outlet'), findsOneWidget);
      _expectNoRawKeys(tester);
    });

    for (final size in const [
      Size(390, 844), // phone
      Size(600, 960), // the compact/medium boundary
      Size(834, 1112), // tablet portrait
      Size(1032, 1376), // the 13" width that has broken this app twice
    ]) {
      testWidgets('lays out without overflow at ${size.width.toInt()}pt',
          (tester) async {
        await _pump(
          tester,
          PromotionsScreen(promotions: promos, now: _now),
          size: size,
        );

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('survives 200% text scale', (tester) async {
      // The card this replaces pinned its value block to `width: 90` and laid
      // three metadata columns out in fixed `Expanded`s; both clip well before
      // this (FS-A11Y-2).
      await _pump(
        tester,
        PromotionsScreen(promotions: promos, now: _now),
        textScale: 2.0,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('PromotionSectionWidget', () {
    testWidgets('shows one preview per group and folds away', (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: PromotionSectionWidget(
              groups: mockQuotationPromoGroups,
              now: _now,
            ),
          ),
        ),
      );

      // One card per group, not the whole catalogue: that is the change that
      // gives the quotation form back roughly 700pt of scroll.
      expect(
        find.byType(PromoCard),
        findsNWidgets(mockQuotationPromoGroups.length),
      );
      _expectNoRawKeys(tester);

      await tester.tap(find.text('Promotions'));
      await tester.pumpAndSettle();

      expect(find.byType(PromoCard), findsNothing);
    });

    testWidgets('the collapsed header still reports what is expiring',
        (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: PromotionSectionWidget(
            groups: [
              PromoGroup(
                titleKey: 'promotions.group.depot_discount',
                promos: [
                  _promo(id: 'a', kind: PromoKind.onInvoice, endsInDays: 2),
                  _promo(id: 'b', kind: PromoKind.onInvoice, endsInDays: 60),
                ],
              ),
            ],
            now: _now,
            initiallyExpanded: false,
          ),
        ),
      );

      // Folding the block must not hide the deadline — otherwise the fold costs
      // the rep the one fact the section exists to deliver.
      expect(find.textContaining('1 ending this week'), findsOneWidget);
    });
  });
}
