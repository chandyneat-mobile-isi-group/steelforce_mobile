import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';
import 'package:steelforce/features/depots/presentation/widgets/depot_card.dart';
import 'package:steelforce/features/depots/presentation/widgets/depot_status_badge.dart';

/// The card renders a depot's trading status.
///
/// It is not decoration: `suspended`, `closed` and `creditHold` all mean *do
/// not start writing an order*, and a rep needs to know that from the list —
/// before tapping through and building a quotation they cannot submit.
///
/// The status is read off the entity's stable `status` code rather than the
/// API's pre-translated `statusDisplay`, so a row rendered from the offline
/// cache reads in the current language even when it was synced under another.
Depot _depot({
  required DepotStatus status,
  String shopName = 'Phnom Penh Steel Outlet',
  String? khName,
}) =>
    Depot(
      id: 'c1',
      depotCode: 'ISI-PP0099',
      shopName: shopName,
      khName: khName,
      ownerName: 'Sok Dara',
      phone: '012345678',
      address: 'St. 271',
      province: 'Phnom Penh',
      district: 'Mean Chey',
      territory: 'PP-NORTH',
      latitude: 11.55,
      longitude: 104.91,
      creditLimit: 5000,
      status: status,
      assignedRepId: 'rep-1',
      assignedRepName: 'Rep One',
      updatedAt: DateTime.utc(2026, 9, 1),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  Future<void> pump(
    WidgetTester tester,
    Depot depot, {
    double textScale = 1.0,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light(AppTypography.latinFontFamily),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              // Scrollable, because that is how the card is actually mounted
              // (a `SliverList` in `depots_screen.dart`). In a bare Scaffold
              // body a tall card reports a vertical overflow that the app never
              // has, which would make this suite fail on a layout that is fine.
              body: ListView(
                children: [
                  DepotCard(
                    depot: depot,
                    isFavorite: false,
                    onTap: () {},
                    onFavoriteToggle: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the badge carrying the depot\'s own status',
      (tester) async {
    await pump(tester, _depot(status: DepotStatus.suspended));

    final badge =
        tester.widget<DepotStatusBadge>(find.byType(DepotStatusBadge));
    expect(badge.status, DepotStatus.suspended);
    expect(find.text('Suspended'), findsOneWidget);
  });

  testWidgets('every status renders its own label, never a default',
      (tester) async {
    // A card that showed "Active" for everything would be worse than showing
    // nothing — it would actively tell a rep a closed account is tradeable.
    const expected = {
      DepotStatus.draft: 'Draft',
      DepotStatus.pendingApproval: 'Pending approval',
      DepotStatus.active: 'Active',
      DepotStatus.suspended: 'Suspended',
      DepotStatus.closed: 'Closed',
      DepotStatus.dormant: 'Dormant',
      DepotStatus.creditHold: 'Credit Hold',
    };

    for (final entry in expected.entries) {
      await pump(tester, _depot(status: entry.key));
      expect(find.text(entry.value), findsOneWidget,
          reason: '${entry.key.name} rendered the wrong label');
    }
  });

  testWidgets('the badge does not crowd out the shop name', (tester) async {
    // The name is Expanded and the badge is not, so a long name must ellipsize
    // rather than push the badge off the card.
    await pump(
      tester,
      _depot(
        status: DepotStatus.creditHold,
        shopName: 'Phnom Penh Steel Outlet and Construction Supply Company',
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(DepotStatusBadge), findsOneWidget);
    expect(find.text('Credit Hold'), findsOneWidget);
  });

  testWidgets('survives 200% text scale without overflowing', (tester) async {
    // FS-A11Y-2. A badge added to a Row is the classic way a card starts
    // overflowing at large scales.
    await pump(tester, _depot(status: DepotStatus.pendingApproval),
        textScale: 2.0);

    expect(tester.takeException(), isNull);
  });

  group('in Khmer', () {
    setUp(() => LocalizationService.instance.load('km'));
    tearDown(() => LocalizationService.instance.load('en'));

    testWidgets('the status label follows the active language', (tester) async {
      await pump(tester, _depot(status: DepotStatus.active));

      expect(find.text('សកម្ម'), findsOneWidget); // Active
      expect(find.text('Active'), findsNothing);
    });

    testWidgets('no status leaks its translation key', (tester) async {
      for (final status in DepotStatus.values) {
        await pump(tester, _depot(status: status));

        final leaked = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .whereType<String>()
            .where((s) => s.startsWith('depots.'))
            .toList();
        expect(leaked, isEmpty,
            reason: '${status.name} fell through to its key');
      }
    });
  });
}
