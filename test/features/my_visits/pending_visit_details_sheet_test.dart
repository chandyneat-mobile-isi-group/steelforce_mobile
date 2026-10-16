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
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/my_visits/domain/entities/pending_visit_sync.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_stop_discard.dart';
import 'package:steelforce/features/my_visits/domain/usecases/discard_pending_visit_stop.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_pending_visit_sync.dart';
import 'package:steelforce/features/my_visits/domain/usecases/routes_params.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/pending_visit_sync_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/sync/pending_visits_section.dart';

class _MockGet extends Mock implements GetPendingVisitSync {}

class _MockDiscard extends Mock implements DiscardPendingVisitStop {}

final _checkedIn = PendingVisitStop(
  stopId: 's-1',
  shopName: 'Sok Hardware',
  shopNameKh: 'ហាងលក់គ្រឿងដែកសុខ',
  checkInAt: DateTime.utc(2026, 10, 5, 2),
  checkOutAt: DateTime.utc(2026, 10, 5, 3),
  orderLines: 2,
  photos: 1,
);

/// The case the rep reported: check-in and check-out already sent, only
/// stock counts, notes and photos left — which used to vanish into a bare
/// "other records" count with nothing to act on.
const _capturesOnly = PendingVisitStop(
  stopId: 's-2',
  shopName: 'Dara Steel',
  shopNameKh: 'ដារ៉ាដែក',
  stockUpdates: 2,
  notes: 1,
  photos: 1,
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting();
    await LocalizationService.instance.load('en');
    registerFallbackValue(const NoParams());
    registerFallbackValue(const StopIdParams('x'));
  });

  late _MockGet get;
  late _MockDiscard discard;
  late int syncs;

  setUp(() {
    get = _MockGet();
    discard = _MockDiscard();
    syncs = 0;
    when(() => get(any())).thenAnswer((_) async =>
        Success(PendingVisitSync(stops: [_checkedIn, _capturesOnly])));
  });

  Future<PendingVisitSyncCubit> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    double textScale = 1.0,
    Size size = const Size(390, 1400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final cubit = PendingVisitSyncCubit(
      getPendingVisitSync: get,
      discardPendingVisitStop: discard,
      syncNow: () async {
        syncs++;
        return true;
      },
    );
    addTearDown(cubit.close);
    await cubit.load();
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
                child: const PendingVisitsSection(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  group('in English', () {
    testWidgets(
        'a stop with only captures waiting is its own card with Sync and '
        'Discard', (tester) async {
      await pump(tester);

      expect(find.text('Dara Steel'), findsOneWidget);
      expect(
          find.text(
              '4 more record(s) waiting: orders, stock counts, notes, photos'),
          findsOneWidget);
      expect(find.text('Sync'), findsNWidgets(2));
      expect(find.text('Discard'), findsNWidgets(2));
      expect(find.textContaining('belong to no visit'), findsNothing);
    });

    testWidgets('tapping a card opens its details', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Sok Hardware'));
      await tester.pumpAndSettle();

      expect(find.text('Visit waiting to send'), findsOneWidget);
      expect(find.text('Check-in'), findsOneWidget);
      expect(find.text('Check-out'), findsOneWidget);
      expect(find.text('The check-out is sent after the check-in.'),
          findsNWidgets(2),
          reason: 'on the card underneath and in the sheet');
      expect(find.text('Order lines'), findsOneWidget);
      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('Stock counts'), findsNothing, reason: 'none waiting');
    });

    testWidgets(
        'a captures-only stop says its check-in and check-out are not '
        'waiting', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Dara Steel'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing waiting'), findsNWidgets(2));
      expect(find.text('Stock counts'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
    });

    testWidgets('Sync in the details sends everything waiting', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Sok Hardware'));
      await tester.pumpAndSettle();

      final sheetSync = find.text('Sync').last;
      await tester.tap(sheetSync);
      await tester.pumpAndSettle();

      expect(syncs, 1);
    });

    testWidgets(
        'Discard asks first, says it cannot be undone, then discards and '
        'closes the details once the stop is gone', (tester) async {
      await pump(tester);
      when(() => discard(const StopIdParams('s-1'))).thenAnswer((_) async =>
          const Success(VisitStopDiscard(
              stopId: 's-1',
              discardedRecords: 5,
              reset: VisitStopReset.notVisited)));

      await tester.tap(find.text('Sok Hardware'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard').last);
      await tester.pumpAndSettle();

      expect(find.text('Discard this visit?'), findsOneWidget);
      expect(find.textContaining('This cannot be undone'), findsOneWidget);
      expect(find.textContaining('you will have to do the visit again'),
          findsOneWidget);

      // Cancel first: nothing happens.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      verifyNever(() => discard(any()));

      when(() => get(any())).thenAnswer(
          (_) async => const Success(PendingVisitSync(stops: [_capturesOnly])));
      await tester.tap(find.text('Discard').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();

      verify(() => discard(const StopIdParams('s-1'))).called(1);
      expect(find.text('Visit waiting to send'), findsNothing,
          reason: 'the sheet closes once the stop has nothing waiting');
      expect(find.text('Sok Hardware'), findsNothing);
      expect(find.text('Dara Steel'), findsOneWidget);
    });

    testWidgets('a captures-only discard warns the records will be lost',
        (tester) async {
      await pump(tester);

      // The second card's Discard.
      await tester.tap(find.text('Discard').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('The 4 record(s) from Dara Steel'),
          findsOneWidget);
      expect(find.textContaining('already been sent'), findsOneWidget);
    });
  });

  group('in Khmer, large text, narrow phone', () {
    setUp(() => LocalizationService.instance.load('km'));
    tearDown(() => LocalizationService.instance.load('en'));

    testWidgets('cards and details render without overflow or raw keys',
        (tester) async {
      await pump(
        tester,
        locale: const Locale('km'),
        textScale: 1.6,
        size: const Size(320, 1800),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('ហាងលក់គ្រឿងដែកសុខ'), findsOneWidget,
          reason: 'the Khmer shop name in Khmer');
      expect(find.text('ធ្វើសមកាលកម្ម'), findsNWidgets(2));
      expect(find.text('បោះចោល'), findsNWidgets(2));

      await tester.tap(find.text('ដារ៉ាដែក'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('ទស្សនកិច្ចកំពុងរង់ចាំផ្ញើ'), findsOneWidget);
      expect(find.text('ការរាប់ស្តុក'), findsOneWidget);
      final rendered = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>();
      expect(rendered.where((s) => s.startsWith('sync_center.')), isEmpty,
          reason: 'a key fell through untranslated');

      await tester.tap(find.text('បោះចោល').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('បោះចោលទស្សនកិច្ចនេះ?'), findsOneWidget);
    });
  });
}
