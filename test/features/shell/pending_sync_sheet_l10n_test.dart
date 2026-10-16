import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/order/domain/entities/quotation_sync_status.dart';
import 'package:steelforce/features/order/presentation/l10n/quotation_sync_error_l10n.dart';
import 'package:steelforce/features/order/presentation/l10n/quotation_sync_status_l10n.dart';

/// The sync sheet rendered every queue row's status through a `label` that
/// returned English literals from the domain enum — and called it as
/// `label(context)`, which did not compile, so the sheet could not build at
/// all. `orders.sync_status.*` was already translated in both language files
/// with no caller; these tests hold that wiring in place.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  /// `.tr` reads the service directly, so a bare pump is enough — but the
  /// widget tree still needs ScreenUtil for the responsive helpers.
  Future<void> pumpLabels(WidgetTester tester) => tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light(AppTypography.latinFontFamily),
            home: Scaffold(
              body: Column(
                children: [
                  for (final s in QuotationSyncStatus.values)
                    Text(s.localizedLabel),
                ],
              ),
            ),
          ),
        ),
      );

  testWidgets('every status resolves to English copy', (tester) async {
    await pumpLabels(tester);

    expect(find.text('Pending sync'), findsOneWidget);
    expect(find.text('Sent to Admin'), findsOneWidget);
    expect(find.text('Sync failed'), findsOneWidget);
    expect(find.text('Needs review'), findsOneWidget);
    expect(find.text('Returned by Admin'), findsOneWidget);
    // The app never talks to SAP; no chip may claim it did.
    expect(find.textContaining('SAP'), findsNothing);
  });

  testWidgets('no status leaks its translation key', (tester) async {
    await pumpLabels(tester);

    // An unresolved key renders as the raw dotted path. One real label per
    // state.
    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();

    expect(rendered, hasLength(QuotationSyncStatus.values.length));
    expect(
      rendered.where((s) => s.startsWith('orders.')),
      isEmpty,
      reason: 'a status fell through to its key',
    );
  });

  group('in Khmer', () {
    setUp(() => LocalizationService.instance.load('km'));
    tearDown(() => LocalizationService.instance.load('en'));

    testWidgets('every status resolves to Khmer copy', (tester) async {
      await pumpLabels(tester);

      // The regression this file exists for: these chips used to render
      // English regardless of language, because the labels were literals on
      // the domain enum.
      expect(find.text('រង់ចាំសមកាលកម្ម'), findsOneWidget); // Pending sync
      expect(find.text('បានផ្ញើទៅ Admin'), findsOneWidget); // Sent to Admin
      expect(find.text('Admin បានបញ្ជូនត្រឡប់'), findsOneWidget); // Returned
      expect(find.text('សមកាលកម្មបរាជ័យ'), findsOneWidget); // Sync failed

      expect(find.text('Pending sync'), findsNothing);
      expect(find.text('Sync failed'), findsNothing);
    });

    testWidgets('no status leaks its translation key in Khmer', (tester) async {
      await pumpLabels(tester);

      final rendered = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();

      expect(rendered.where((s) => s.startsWith('orders.')), isEmpty);
    });
  });

  group('the Admin document line', () {
    test('substitutes number and status', () async {
      await LocalizationService.instance.load('en');

      final line = 'sync.admin_document'.trParams({
        'id': 'Q-2026-7',
        'status': localizedRemoteStatus('PendingApproval'),
      });

      // FS-LOC-3: assert the parameters actually substitute. Shipping copy in
      // this app has rendered `{minutes}` literally before.
      expect(line, 'Admin #Q-2026-7 · Admin Review');
      expect(line, isNot(contains('{')));
    });

    test('substitutes in Khmer too', () async {
      await LocalizationService.instance.load('km');
      addTearDown(() => LocalizationService.instance.load('en'));

      final line = 'sync.admin_document'.trParams({
        'id': 'Q-2026-7',
        'status': localizedRemoteStatus('Returned'),
      });

      expect(line, contains('Q-2026-7'));
      expect(line, contains('បានបញ្ជូនត្រឡប់'));
      expect(line, isNot(contains('{')));
    });

    test('an unknown later-phase status shows its code, not a key', () async {
      await LocalizationService.instance.load('en');
      expect(localizedRemoteStatus('Ordered'), 'Ordered');
    });
  });

  group('sync errors localize from the error code', () {
    test('a known code reads as rep-facing copy in both languages', () async {
      await LocalizationService.instance.load('en');
      expect(localizedSyncError('Quotation.PriceChanged'),
          contains('Prices changed'));
      await LocalizationService.instance.load('km');
      addTearDown(() => LocalizationService.instance.load('en'));
      expect(localizedSyncError('Quotation.PriceChanged'),
          isNot(startsWith('sync.')));
    });

    test('an unknown or missing code falls back to the generic message',
        () async {
      await LocalizationService.instance.load('en');
      final generic = 'sync.errors.generic'.tr;
      expect(localizedSyncError('Quotation.SomethingNew'), generic);
      expect(localizedSyncError(null), generic);
      expect(generic, isNot(startsWith('sync.')));
    });
  });
}
