import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/session/unsent_work.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/profile/presentation/widgets/unsent_work_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Loaded outside the widget test's fake clock: reading the asset there
  // never completes.
  setUp(() => LocalizationService.instance.load('en'));

  const waiting = [
    UnsentWorkCount(UnsentWorkKind.depotRegistrations, 1, needsAction: 1),
    UnsentWorkCount(UnsentWorkKind.checkIns, 2),
    UnsentWorkCount(UnsentWorkKind.quotations, 3),
    UnsentWorkCount(UnsentWorkKind.checkOuts, 2),
  ];

  /// Opens the dialog and returns a reader for what it resolved to.
  Future<bool? Function()> pumpDialog(WidgetTester tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(AppTypography.latinFontFamily),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result =
              await showUnsentWorkDialog(context: context, initial: waiting),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => result;
  }

  testWidgets('previews what is waiting, by kind, in send order',
      (tester) async {
    await pumpDialog(tester);

    expect(find.textContaining('8 item(s)'), findsOneWidget);
    final labels = [
      'Depot registrations',
      'Visit check-ins',
      'Orders & quotations',
      'Visit check-outs',
    ];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
    final ys = [for (final l in labels) tester.getTopLeft(find.text(l)).dy];
    expect(ys, [...ys]..sort());
    expect(find.text('1 need your action in the Sync Center'), findsOneWidget);
  });

  testWidgets('Open Sync Center closes the dialog and asks for the sheet',
      (tester) async {
    final result = await pumpDialog(tester);
    await tester.tap(find.text('Open Sync Center'));
    await tester.pumpAndSettle();

    expect(result(), isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Close stops the sign-out', (tester) async {
    final result = await pumpDialog(tester);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(result(), isFalse);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Khmer at 200% text: every row shows, nothing overflows',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => LocalizationService.instance.load('km'));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(AppTypography.khmerFontFamily),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              showUnsentWorkDialog(context: context, initial: waiting),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('ការចុះឈ្មោះដេប៉ូ'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('ការចេញពីទស្សនកិច្ច'), 100,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('ការចេញពីទស្សនកិច្ច'), findsOneWidget);
  });
}
