import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stop_information/promotions_screen.dart';
import 'package:steelforce/shared/widgets/promotions/promo_card.dart';
import 'package:steelforce/shared/widgets/promotions/promo_view.dart';

/// The two axes the old promotion cards silently failed on.
///
/// They were built from raw literals — `Colors.white` card backgrounds,
/// `Colors.grey.shade200` borders, `Colors.blue.shade100` badges — so in dark
/// mode they drew light-mode chrome under dark-mode text. And every string was
/// hardcoded English, so Khmer never stretched the layout at all. Neither
/// failure shows up in a light/English test run, which is why they survived.
///
/// Khmer lives in its own file rather than a group: `LocalizationService` is a
/// process-wide singleton, so loading `km` inside the main suite would leak
/// into whatever ran after it.
final _now = DateTime(2026, 3, 10, 9);

final _promos = [
  PromoView(
    id: 'a',
    code: 'ISI-ONINV-5',
    title: 'On-Invoice Discount — Roofing & Wave Tiles',
    summary: 'Instant reduction on all roofing and wave tile orders.',
    kind: PromoKind.onInvoice,
    value: const PromoPercent(5),
    status: PromoStatus.active,
    endsOn: _now.add(const Duration(days: 3)),
    minSpend: '\$2,000',
    category: 'All Structural Steel',
    depots: 'PP, ST, KPS Depots',
  ),
  PromoView(
    id: 'b',
    title: 'Q3 Volume Tier Bonus',
    kind: PromoKind.volumeTier,
    value: const PromoTerms('Special Rate'),
    status: PromoStatus.expired,
    endsOn: _now.subtract(const Duration(days: 20)),
    category: 'Rebar & Mesh',
  ),
];

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: theme,
        home: PromotionsScreen(promotions: _promos, now: _now),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting();
  });

  // Locales are switched in `setUpAll`, never inside a `testWidgets` body.
  // `LocalizationService.load` reads the bundle, and a `testWidgets` body runs
  // in fake async where that future never completes — awaiting it there hangs
  // the whole test file rather than failing it.
  group('dark theme', () {
    setUpAll(() => LocalizationService.instance.load('en'));

    testWidgets('renders without raw light-mode chrome', (tester) async {
      await _pump(tester, AppTheme.dark('ABCGinto'));

      expect(tester.takeException(), isNull);
      expect(find.byType(PromoCard), findsNWidgets(2));

      // A literal that slipped through — the old cards' `color: Colors.white`
      // — shows up here as a white card behind white-ish text, which no
      // assertion on widget counts would notice.
      final decorated = tester
          .widgetList<Container>(find.descendant(
            of: find.byType(PromoCard).first,
            matching: find.byType(Container),
          ))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .toList();
      expect(
        decorated.any((d) => d.color == Colors.white),
        isFalse,
        reason: 'a hardcoded white surface survived into the dark theme',
      );
    });
  });

  group('Khmer', () {
    // Khmer runs roughly a third longer than the English and does not break on
    // spaces (FS-LOC-4), so it is the locale that finds every fixed-width box.
    setUpAll(() => LocalizationService.instance.load('km'));
    tearDownAll(() => LocalizationService.instance.load('en'));

    testWidgets('lays out without overflow and translates every label',
        (tester) async {
      await _pump(tester, AppTheme.light('ABCGinto'));

      expect(tester.takeException(), isNull);
      expect(find.byType(PromoCard), findsNWidgets(2));

      final leaked = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
          .where((s) => s.contains('promotions.'))
          .toList();
      expect(leaked, isEmpty, reason: 'missing Khmer translations: $leaked');
    });
  });
}
