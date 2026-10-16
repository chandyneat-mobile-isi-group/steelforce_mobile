import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/my_visits/data/local/check_out_reason_store.dart';
import 'package:steelforce/features/my_visits/data/models/check_in_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/check_out_record_model.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_check_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/check_out_reason_repository_impl.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_context.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_outcome.dart';
import 'package:steelforce/features/my_visits/domain/entities/depot_stop_info.dart';
import 'package:steelforce/features/my_visits/domain/entities/no_order_reason.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';
import 'package:steelforce/features/my_visits/domain/entities/server_visit.dart';
import 'package:steelforce/features/my_visits/domain/entities/territory_type.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/domain/repositories/check_out_reason_repository.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_check_out_reasons.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/check_out_reasons_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/check_out/check_out_sheet.dart';

const _reasons = [
  NoOrderReason(
      code: 'stockStillEnough',
      nameEn: 'Shop still has enough stock',
      nameKm: 'ហាងនៅមានស្តុកគ្រប់គ្រាន់',
      requiresNote: false,
      sort: 1),
  NoOrderReason(
      code: 'boughtFromCompetitor',
      nameEn: 'Bought from a competitor',
      nameKm: 'បានទិញពីដៃគូប្រកួតប្រជែង',
      requiresNote: true,
      sort: 5),
  NoOrderReason.other,
];

class _FixedReasons implements CheckOutReasonRepository {
  @override
  Future<List<NoOrderReason>> getReasons() async => _reasons;
}

final _stop = RouteStop(
  id: 's-1',
  routeId: 'r-1',
  depot: const DepotStopInfo(
    id: 'd-1',
    name: 'Sok Hardware',
    nameKh: 'ហាងសុខ',
    code: 'C-1',
    contact: 'Sok',
    phone: '012',
    address: 'St 1',
    territory: 'PP',
    territoryType: TerritoryType.urban,
    latitude: 11.5,
    longitude: 104.9,
  ),
  sequence: 1,
  plannedArrival: null,
  plannedDeparture: null,
  status: VisitStatus.checkedIn,
);

VisitOrderOption _order(String id, {String? serverId}) => VisitOrderOption(
      ref: VisitOrderRef(clientId: id, quotationId: serverId),
      createdAt: DateTime(2026, 10, 5, 9, 30),
      itemCount: 3,
      total: 120,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // As app_bootstrap_service does at launch.
  setUpAll(initializeDateFormatting);
  setUp(() => LocalizationService.instance.load('en'));

  /// Opens the sheet and returns a getter for what it resolved to.
  Future<CheckOutChoice? Function()> open(
    WidgetTester tester, {
    List<VisitOrderOption> orders = const [],
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    CheckOutChoice? result;
    var closed = false;
    final cubit = CheckOutReasonsCubit(GetCheckOutReasons(_FixedReasons()))
      ..load();
    addTearDown(cubit.close);

    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light(AppTypography.latinFontFamily),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showCheckOutSheet(context,
                    visit: CheckOutContext(stop: _stop, orders: orders),
                    reasons: cubit);
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => closed ? result : null;
  }

  Finder confirm() => find.widgetWithText(FilledButton, 'Check out');
  bool enabled(WidgetTester tester) =>
      tester.widget<FilledButton>(confirm()).onPressed != null;

  testWidgets('orders taken here: "with order", all of them pre-selected',
      (tester) async {
    final result = await open(tester,
        orders: [_order('qt-1', serverId: 'srv-1'), _order('qt-2')]);

    expect(find.text('2 order(s) taken at this shop'), findsOneWidget);
    expect(enabled(tester), isTrue);
    await tester.tap(confirm());
    await tester.pumpAndSettle();

    final choice = result()!;
    expect(choice.outcome, CheckOutOutcome.withOrder);
    expect(choice.orders.map((o) => o.clientId), ['qt-1', 'qt-2']);
    expect(choice.orders.first.quotationId, 'srv-1');
  });

  testWidgets('unticking every order leaves nothing to check out with',
      (tester) async {
    await open(tester, orders: [_order('qt-1')]);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(enabled(tester), isFalse);
  });

  testWidgets('no orders: "with order" is unavailable, a reason is needed',
      (tester) async {
    final result = await open(tester);

    expect(find.text('No order saved at this shop since check-in'),
        findsOneWidget);
    expect(enabled(tester), isFalse, reason: 'no reason picked yet');

    await tester.tap(find.text('Shop still has enough stock'));
    await tester.pump();
    expect(enabled(tester), isTrue);
    await tester.tap(confirm());
    await tester.pumpAndSettle();

    final choice = result()!;
    expect(choice.outcome, CheckOutOutcome.withoutOrder);
    expect(choice.noOrderReason, 'stockStillEnough');
    expect(choice.noOrderNote, isNull);
  });

  testWidgets('a reason that needs a note waits for one', (tester) async {
    final result = await open(tester);

    await tester.tap(find.text('Bought from a competitor'));
    await tester.pump();
    expect(enabled(tester), isFalse);
    expect(find.text('This reason needs a short note.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  ABC Steel  ');
    await tester.pump();
    expect(enabled(tester), isTrue);
    await tester.tap(confirm());
    await tester.pumpAndSettle();

    expect(result()!.noOrderNote, 'ABC Steel');
  });

  testWidgets('closing the sheet checks nothing out', (tester) async {
    final result = await open(tester);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(result(), isNull);
  });

  testWidgets('Khmer at 200% on a small phone: usable, nothing overflows',
      (tester) async {
    await tester.runAsync(() => LocalizationService.instance.load('km'));
    final result = await open(tester,
        orders: [_order('qt-1')], size: const Size(360, 640), textScale: 2);

    expect(tester.takeException(), isNull);
    // At this size the options scroll; the Check out button stays pinned.
    await tester
        .ensureVisible(find.text('ចេញពីទស្សនកិច្ច ដោយគ្មានការបញ្ជាទិញ'));
    await tester.tap(find.text('ចេញពីទស្សនកិច្ច ដោយគ្មានការបញ្ជាទិញ'));
    await tester.pumpAndSettle();
    // Reason names follow the app Locale, which this harness leaves on
    // English; the first chip is `stockStillEnough` either way.
    await tester.ensureVisible(find.byType(ChoiceChip).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ChoiceChip).first);
    await tester.pump();
    await tester.tap(confirm().evaluate().isEmpty
        ? find.widgetWithText(FilledButton, 'ចេញពីទស្សនកិច្ច')
        : confirm());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(result()!.noOrderReason, 'stockStillEnough');
  });

  group('the reason list', () {
    late Box<dynamic> box;
    setUp(() async {
      Hive.init('./.dart_tool/test_hive');
      box = await Hive.openBox<dynamic>(
          'reasons_${DateTime.now().microsecondsSinceEpoch}');
    });
    tearDown(() => box.deleteFromDisk());

    CheckOutReasonRepositoryImpl repo(_ReasonRemote remote, bool online) =>
        CheckOutReasonRepositoryImpl(
            remote: remote,
            store: CheckOutReasonStore(box),
            network: _Network(online));

    test('online: the server list, cached for later', () async {
      final remote = _ReasonRemote(_reasons.take(2).toList());
      final reasons = await repo(remote, true).getReasons();
      expect(reasons.map((r) => r.code),
          ['stockStillEnough', 'boughtFromCompetitor', 'other']);

      final offline = await repo(_ReasonRemote(null), false).getReasons();
      expect(offline.map((r) => r.code), reasons.map((r) => r.code),
          reason: 'offline check-out uses the cached list');
    });

    test('never fetched and offline: "other" is still offered', () async {
      final reasons = await repo(_ReasonRemote(null), false).getReasons();
      expect(reasons.single.code, 'other');
      expect(reasons.single.requiresNote, isTrue);
    });

    test('a failing server falls back to the cache', () async {
      await repo(_ReasonRemote(_reasons), true).getReasons();
      final reasons = await repo(
              _ReasonRemote(null,
                  error: const ApiException(
                      ApiError(code: 'General.Unexpected', statusCode: 500))),
              true)
          .getReasons();
      expect(reasons, hasLength(3));
    });
  });
}

class _Network implements NetworkInfo {
  _Network(this.online);
  final bool online;
  @override
  Future<bool> get isConnected async => online;
}

class _ReasonRemote implements VisitCheckRemoteDataSource {
  _ReasonRemote(this.reasons, {this.error});
  final List<NoOrderReason>? reasons;
  final Exception? error;

  @override
  Future<List<NoOrderReason>> fetchCheckOutReasons() async {
    if (error != null) throw error!;
    return reasons ?? const [];
  }

  @override
  Future<ServerVisit> checkIn(CheckInRecordModel record) =>
      throw UnimplementedError();
  @override
  Future<ServerVisit> checkOut(CheckOutRecordModel record) =>
      throw UnimplementedError();
}
