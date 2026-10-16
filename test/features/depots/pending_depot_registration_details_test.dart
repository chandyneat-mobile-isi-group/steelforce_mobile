import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/depots/domain/entities/pending_depot_registration.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_registration_outbox.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_registration_queue_cubit.dart';
import 'package:steelforce/features/depots/presentation/widgets/sync/pending_depot_registrations_section.dart';

class _MockOutbox extends Mock implements DepotRegistrationOutbox {}

final _queued = PendingDepotRegistration(
  id: 'q-1',
  depotName: 'Toul Kork Yard',
  depotNameKh: 'ឃ្លាំងទួលគោក',
  status: DepotRegistrationQueueStatus.queued,
  createdAt: DateTime.utc(2026, 10, 5, 8),
  photosOutstanding: 2,
  phone: '012345678',
  address: '12 St 271',
  latitude: 11.5564,
  longitude: 104.9282,
  attempts: 1,
  lastAttemptAt: DateTime.utc(2026, 10, 5, 9),
);

final _needsReview = PendingDepotRegistration(
  id: 'r-1',
  depotName: 'Sen Sok Steel',
  status: DepotRegistrationQueueStatus.needsReview,
  createdAt: DateTime.utc(2026, 10, 5, 7),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting();
    await LocalizationService.instance.load('en');
  });

  late _MockOutbox outbox;
  late StreamController<List<PendingDepotRegistration>> rows;
  late Completer<bool> drain;
  late int drains;

  setUp(() {
    outbox = _MockOutbox();
    drains = 0;
    when(outbox.expedite).thenAnswer((_) async {});
    when(() => outbox.discard(any()))
        .thenAnswer((_) async => const Success(null));
  });

  Future<DepotRegistrationQueueCubit> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    double textScale = 1.0,
    Size size = const Size(390, 1400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // Created here, inside the test's fake-async zone, not in setUp: a
    // completer or controller made in the real zone schedules its callbacks
    // on a microtask queue `pump` never drains.
    rows = StreamController<List<PendingDepotRegistration>>.broadcast();
    addTearDown(rows.close);
    drain = Completer<bool>();
    when(outbox.watchAll).thenAnswer((_) => rows.stream);
    final cubit = DepotRegistrationQueueCubit(
      outbox: outbox,
      syncNow: () {
        drains++;
        return drain.future;
      },
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('km')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(locale.languageCode == 'km'
              ? AppTypography.khmerFontFamily
              : AppTypography.latinFontFamily),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: BlocProvider.value(
                value: cubit,
                child: const PendingDepotRegistrationsSection(),
              ),
            ),
          ),
        ),
      ),
    );
    rows.add([_needsReview, _queued]);
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets(
      'a waiting row offers Sync; a row needing the rep offers Retry instead',
      (tester) async {
    await pump(tester);

    expect(find.text('Sync'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Discard'), findsNWidgets(2));
  });

  testWidgets('Sync shows progress while the drain runs', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Sync'));
    await tester.pump();

    expect(drains, 1);
    expect(find.text('Syncing…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    drain.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Sync'), findsOneWidget);
  });

  testWidgets('tapping a row opens what it holds', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Toul Kork Yard'));
    await tester.pumpAndSettle();

    expect(find.text('Depot registration waiting to send'), findsOneWidget);
    expect(find.text('ឃ្លាំងទួលគោក'), findsOneWidget);
    expect(find.text('012345678'), findsOneWidget);
    expect(find.text('12 St 271'), findsOneWidget);
    expect(find.text('11.55640, 104.92820'), findsOneWidget);
    expect(find.text('Photos still to upload'), findsOneWidget);
    expect(find.text('Attempts'), findsOneWidget);
    // The card's own actions are in the sheet too.
    expect(find.text('Sync'), findsNWidgets(2));
  });

  testWidgets('discard from the details asks first, then closes the sheet',
      (tester) async {
    await pump(tester);
    await tester.tap(find.text('Toul Kork Yard'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Discard').last);
    await tester.pumpAndSettle();
    expect(find.text('Discard registration?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();
    verify(() => outbox.discard('q-1')).called(1);

    rows.add([_needsReview]);
    await tester.pumpAndSettle();

    expect(find.text('Depot registration waiting to send'), findsNothing);
  });

  group('in Khmer, large text, narrow phone', () {
    setUp(() => LocalizationService.instance.load('km'));
    tearDown(() => LocalizationService.instance.load('en'));

    testWidgets('cards and details render without overflow', (tester) async {
      await pump(
        tester,
        locale: const Locale('km'),
        textScale: 1.6,
        size: const Size(320, 2000),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('ធ្វើសមកាលកម្ម'), findsOneWidget);

      await tester.tap(find.text('Toul Kork Yard'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('ការចុះឈ្មោះដេប៉ូកំពុងរង់ចាំផ្ញើ'), findsOneWidget);
      final rendered = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>();
      expect(rendered.where((s) => s.startsWith('sync_center.')), isEmpty);
    });
  });
}
