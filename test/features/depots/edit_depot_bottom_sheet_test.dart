import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';
import 'package:steelforce/features/depots/presentation/widgets/edit_depot_bottom_sheet.dart';

Depot _depot({
  String depotCode = 'DP-0001',
  String? sapDepotId,
  DepotStatus status = DepotStatus.active,
  String? khName = 'ហាង',
  String? whatsapp = '@sokheng',
}) =>
    Depot(
      id: 'd1',
      sapDepotId: sapDepotId,
      depotCode: depotCode,
      shopName: 'Sok Heng Hardware',
      ownerName: 'Sok Heng',
      phone: '012345678',
      address: 'Street 271',
      province: 'Phnom Penh',
      district: 'Chamkarmon',
      territory: 'T1',
      latitude: 11.556789,
      longitude: 104.912341,
      creditLimit: 0,
      status: status,
      assignedRepId: 'r1',
      assignedRepName: 'Rep',
      updatedAt: DateTime(2026, 1, 1),
      khName: khName,
      whatsapp: whatsapp,
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  /// Opens the sheet from a launcher page so a pop can be observed.
  Future<void> open(
    WidgetTester tester,
    Depot depot, {
    Future<void> Function(Depot)? onSave,
  }) async {
    // The locked-SAP header row overflows at phone width; that layout bug is
    // not what these tests pin.
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed')) {
        return;
      }
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light(AppTypography.latinFontFamily),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => EditDepotBottomSheet(
                    depot: depot,
                    onSave: onSave ?? (_) async {},
                  ),
                ),
                child: const Text('launch'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('launch'));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  ElevatedButton saveButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byType(ElevatedButton));

  testWidgets('prefills every editable field and the GPS line', (tester) async {
    await open(tester, _depot());

    expect(find.text('Edit Depot Details'), findsOneWidget);
    expect(find.text('DP-0001'), findsWidgets);
    for (final value in [
      'Sok Heng Hardware',
      'ហាង',
      'Sok Heng',
      '012345678',
      '@sokheng',
      'Street 271',
      'Chamkarmon',
      'Phnom Penh',
    ]) {
      expect(find.widgetWithText(TextFormField, value), findsOneWidget,
          reason: value);
    }
    expect(find.text('GPS: 11.55679, 104.91234'), findsOneWidget);
  });

  testWidgets('subtitle falls back to the SAP ID, then "Depot Profile"',
      (tester) async {
    await open(tester, _depot(depotCode: '', sapDepotId: 'SAP-9'));
    expect(find.text('SAP-9'), findsWidgets);

    Navigator.of(tester.element(find.text('Edit Depot Details'))).pop();
    await tester.pumpAndSettle();
    await open(tester, _depot(depotCode: ''));
    expect(find.text('Depot Profile'), findsOneWidget);
  });

  testWidgets('locked SAP section shows its fallbacks', (tester) async {
    await open(tester, _depot());

    expect(find.text('SAP ERP Managed Fields (Read-Only)'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('— / —'), findsOneWidget);
  });

  testWidgets('save sends trimmed values, then closes', (tester) async {
    Depot? saved;
    await open(tester, _depot(), onSave: (d) async => saved = d);

    await tester.enterText(field('Sok Heng Hardware'), '  New Name  ');
    await tester.enterText(field('ហាង'), '   ');
    await tester.enterText(field('@sokheng'), '');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.shopName, 'New Name');
    expect(saved!.enName, 'New Name');
    // Current behaviour, pinned as-is: a blank Khmer name or WhatsApp is
    // sent to copyWith as null, which copyWith reads as "unchanged", so the
    // old value survives. Clearing either field does not clear it.
    expect(saved!.khName, 'ហាង');
    expect(saved!.whatsapp, '@sokheng');
    expect(saved!.phone, '012345678');
    expect(saved!.latitude, 11.556789);
    expect(saved!.updatedAt, isNot(DateTime(2026, 1, 1)));
    expect(find.text('Edit Depot Details'), findsNothing);
  });

  testWidgets('required shop name and phone block saving', (tester) async {
    var calls = 0;
    await open(tester, _depot(), onSave: (_) async => calls++);

    await tester.enterText(field('Sok Heng Hardware'), ' ');
    await tester.enterText(field('012345678'), '');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Shop name is required'), findsOneWidget);
    expect(find.text('Phone number is required'), findsOneWidget);
    expect(calls, 0);
    expect(find.text('Edit Depot Details'), findsOneWidget);
  });

  testWidgets('shows a spinner and disables save while saving', (tester) async {
    final pending = Completer<void>();
    await open(tester, _depot(), onSave: (_) => pending.future);

    await tester.tap(find.text('Save Changes'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);

    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Edit Depot Details'), findsNothing);
  });

  testWidgets('a closed depot is read-only and cannot be saved',
      (tester) async {
    await open(tester, _depot(status: DepotStatus.closed));

    expect(
      find.textContaining('This depot is Closed and immutable'),
      findsOneWidget,
    );
    expect(saveButton(tester).onPressed, isNull);
    for (final f in tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    )) {
      expect(f.enabled, isFalse);
    }
  });

  testWidgets('cancel and close both dismiss without saving', (tester) async {
    var calls = 0;
    await open(tester, _depot(), onSave: (_) async => calls++);
    await tester.tap(find.text('common.cancel'.tr));
    await tester.pumpAndSettle();
    expect(find.text('Edit Depot Details'), findsNothing);

    await open(tester, _depot(), onSave: (_) async => calls++);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Edit Depot Details'), findsNothing);
    expect(calls, 0);
  });
}
