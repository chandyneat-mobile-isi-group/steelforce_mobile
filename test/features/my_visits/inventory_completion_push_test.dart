import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/config/data_source_mode.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/features/my_visits/data/local/route_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/visit_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/workflow_state_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_push_batch.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_push_result.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_sync_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/active_workflow_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/route_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_sync_repository_impl.dart';
import 'package:steelforce/features/my_visits/domain/entities/active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_outcome.dart';
import 'package:steelforce/features/my_visits/domain/entities/no_order_reason.dart';
import 'package:steelforce/features/my_visits/domain/repositories/check_out_reason_repository.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_check_out_context.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_check_out_reasons.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/check_out_reasons_cubit.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_workflow.dart';
import 'package:steelforce/features/my_visits/domain/repositories/active_workflow_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_sync_repository.dart';
import 'package:steelforce/features/my_visits/domain/usecases/add_visit_photo.dart';
import 'package:steelforce/features/my_visits/domain/usecases/check_out.dart';
import 'package:steelforce/features/my_visits/domain/usecases/complete_visit_check_out.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/usecases/push_pending_visit_data.dart';
import 'package:steelforce/features/my_visits/domain/usecases/save_active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/usecases/update_stop_status.dart';
import 'package:steelforce/features/my_visits/domain/usecases/update_workflow_step.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/open_inventory_visibility.dart';
import 'package:steelforce/features/my_visits/presentation/screens/inventory_visible/inventory_completion_screen.dart';
import 'package:steelforce/features/my_visits/presentation/screens/inventory_visible/inventory_visible_screen.dart';

import '../order/admin_sync/admin_sync_fakes.dart' show FakeQuotationRepository;
import 'inventory_visibility_test.dart' show FakeCapture, kPixelPng;

class _FakeOnlineNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

class _RecordingVisitSyncRemoteDataSource implements VisitSyncRemoteDataSource {
  final List<VisitPushBatch> pushedBatches = [];

  @override
  Future<VisitPushResult> pushVisitData(VisitPushBatch batch) async {
    pushedBatches.add(batch);
    final allIds = [
      ...batch.checkIns.map((c) => c.id),
      ...batch.checkOuts.map((c) => c.id),
      ...batch.stockUpdates.map((s) => s.id),
      ...batch.notes.map((n) => n.id),
      ...batch.photos.map((p) => p.id),
    ];
    return VisitPushResult(
      acceptedIds: allIds,
      rejectedIds: const [],
      syncedAt: DateTime.now(),
    );
  }
}

void main() {
  late AppDatabase db;
  late VisitDriftLocalDataSource visitLocal;
  late RouteDriftLocalDataSource routeLocal;
  late RouteRepository routes;
  late VisitRepository visits;
  late ActiveWorkflowRepository workflows;
  late _RecordingVisitSyncRemoteDataSource fakeRemote;
  late VisitSyncRepository visitSyncRepo;
  late Directory docs;
  late FakeCapture camera;

  const routeId = 'route-101';
  const stopId = 'stop-202';
  const depotId = 'cust-303';
  const depotName = 'ISI Depot Kampot';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  setUp(() async {
    await GetIt.instance.reset();
    // The photo is copied into the app's documents folder; point that at a
    // temp dir.
    docs = await Directory.systemTemp.createTemp('inventory_photo_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => docs.path);
    final shot = File('${docs.path}/picker_shot.png')
      ..writeAsBytesSync(kPixelPng);
    camera = FakeCapture()..next = XFile(shot.path);
    db = AppDatabase(NativeDatabase.memory());
    const logger = ConsoleAppLogger(verbose: false);
    visitLocal = VisitDriftLocalDataSource(db.visitDao, logger);
    routeLocal = RouteDriftLocalDataSource(db.routeDao, logger);
    routes = RouteRepositoryImpl(routeLocal);
    visits = VisitRepositoryImpl(visitLocal);
    workflows = ActiveWorkflowRepositoryImpl(
        WorkflowStateLocalDataSourceImpl(db.workflowStateDao));
    fakeRemote = _RecordingVisitSyncRemoteDataSource();
    visitSyncRepo = VisitSyncRepositoryImpl(
      remote: fakeRemote,
      local: visitLocal,
      network: _FakeOnlineNetworkInfo(),
    );

    // Register in DI
    GetIt.instance
      ..registerSingleton<AppDatabase>(db)
      ..registerSingleton<RouteRepository>(routes)
      ..registerSingleton<VisitRepository>(visits)
      ..registerSingleton<ActiveWorkflowRepository>(workflows)
      ..registerSingleton<VisitSyncRepository>(visitSyncRepo)
      ..registerSingleton<AddVisitPhoto>(AddVisitPhoto(visits))
      ..registerSingleton<ImageCaptureService>(camera)
      ..registerSingleton<GetActiveWorkflow>(GetActiveWorkflow(workflows))
      ..registerSingleton<SaveActiveWorkflow>(SaveActiveWorkflow(workflows))
      ..registerSingleton<UpdateWorkflowStep>(UpdateWorkflowStep(workflows))
      ..registerSingleton<CompleteVisitCheckOut>(CompleteVisitCheckOut(
        workflows,
        routes,
        CheckOut(visits),
        UpdateStopStatus(routes),
      ))
      ..registerSingleton<PushPendingVisitData>(
          PushPendingVisitData(visitSyncRepo))
      // The check-out sheet: the real context lookup, no orders taken here,
      // and the reason list the server would send.
      ..registerSingleton<GetCheckOutContext>(
          GetCheckOutContext(workflows, routes, FakeQuotationRepository()))
      ..registerFactory<CheckOutReasonsCubit>(
          () => CheckOutReasonsCubit(GetCheckOutReasons(_Reasons())));

    await _seedVisitData(
      db,
      workflows: workflows,
      routeId: routeId,
      stopId: stopId,
      depotId: depotId,
      depotName: depotName,
    );
  });

  tearDown(() async {
    await db.close();
    await GetIt.instance.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
    await docs.delete(recursive: true);
  });

  testWidgets(
      'The inventory photo is saved on the stop and Complete Visit pushes it with the check-out',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final navKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          navigatorKey: navKey,
          home: const Scaffold(body: Text('Root Route Dashboard')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Real file reads and copies only finish outside the fake clock.
    Future<void> settleIo() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    // 1. Open Inventory Visibility for the checked-in stop. The camera opens
    // by itself and returns the shot.
    openInventoryVisibilityForDepot(
      navKey.currentContext!,
      depotId: depotId,
      depotName: depotName,
      stopId: stopId,
    );
    await tester.pumpAndSettle();
    await settleIo();
    expect(camera.opens, 1);

    // 2. Submit the photo.
    await tester.tap(find.byType(ElevatedButton));
    await settleIo();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // 3. Saved locally on this stop, as a copy in the app's documents folder.
    final pendingPhotos = await tester.runAsync(visitLocal.fetchPendingPhotos);
    expect(pendingPhotos, hasLength(1));
    final photo = pendingPhotos!.single;
    expect(photo.stopId, stopId);
    expect(photo.caption, inventoryPhotoCaption);
    expect(photo.url, startsWith('${docs.path}/$visitPhotoFolder/'));
    expect(File(photo.url).existsSync(), isTrue);

    // 4. Rep is now on Inventory Completion screen
    expect(find.byType(InventoryCompletionScreen), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);

    // 5. Tap Complete Visit. The check-out sheet asks how the visit ended;
    // nothing was ordered here, so "without order" is already chosen.
    await tester.tap(find.byType(OutlinedButton));
    // The sheet opens after a real Drift read, and the reason list loads
    // while it is up — neither advances on the test clock alone.
    Future<void> waitFor(Finder target) async {
      for (var i = 0; i < 20 && target.evaluate().isEmpty; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    // The demo build checks out in one tap, with no sheet.
    if (!DataSourceMode.useMocks) {
      await waitFor(find.text('Shop still has enough stock'));
      expect(find.text('How did this visit end?'), findsOneWidget);
      await tester.ensureVisible(find.text('Shop still has enough stock'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Shop still has enough stock'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Check out'));
    }
    await waitFor(find.text('Root Route Dashboard'));

    // 6. Navigation popped back to root
    expect(find.text('Root Route Dashboard'), findsOneWidget);
    // The push runs behind the rep; let it land.
    for (var i = 0; i < 20 && fakeRemote.pushedBatches.isEmpty; i++) {
      await settleIo();
    }

    // 7. Verify push batch reached remote data source
    expect(fakeRemote.pushedBatches.length, 1);
    final batch = fakeRemote.pushedBatches.first;
    expect(batch.checkOuts.length, 1,
        reason: 'CheckOutRecord must be included in the push batch');
    expect(batch.checkOuts.first.stopId, stopId);
    expect(batch.checkOuts.first.outcome, CheckOutOutcome.withoutOrder);
    expect(batch.checkOuts.first.noOrderReason,
        DataSourceMode.useMocks ? 'other' : 'stockStillEnough');
    expect(batch.photos.map((p) => p.id), [photo.id],
        reason: 'the inventory photo travels with the stop it was taken at');

    // 8. Verify all items are now marked synced in database
    final remainingPhotos =
        await tester.runAsync(visitLocal.fetchPendingPhotos);
    final remainingCheckOuts =
        await tester.runAsync(visitLocal.fetchPendingCheckOuts);
    expect(remainingPhotos, isEmpty);
    expect(remainingCheckOuts, isEmpty);
  });
}

Future<void> _seedVisitData(
  AppDatabase db, {
  required ActiveWorkflowRepository workflows,
  required String routeId,
  required String stopId,
  required String depotId,
  required String depotName,
}) async {
  final now = DateTime.now().toUtc();
  final day = DateTime.utc(now.year, now.month, now.day);

  await db.into(db.depots).insert(DepotsCompanion.insert(
        id: depotId,
        sapDepotId: const Value('SAP-101'),
        depotCode: 'C-101',
        shopName: depotName,
        ownerName: 'Owner Sok',
        phone: '012345678',
        address: 'Main Road',
        province: 'Kampot',
        district: 'Center',
        territory: 'KAMPOT-1',
        latitude: 10.6,
        longitude: 104.18,
        creditLimit: 5000,
        status: 'active',
        assignedRepId: 'rep-1',
        assignedRepName: 'Rep One',
        updatedAt: now,
        territoryType: const Value('urban'),
      ));

  await db.into(db.routes).insert(RoutesCompanion.insert(
        id: routeId,
        name: 'Route Kampot',
        repId: 'rep-1',
        repName: 'Rep One',
        territory: 'KAMPOT-1',
        visitDate: day,
        plannedStart: day.add(const Duration(hours: 8)),
        plannedEnd: day.add(const Duration(hours: 17)),
        status: 'inProgress',
      ));

  await db.into(db.routeStops).insert(RouteStopsCompanion.insert(
        id: stopId,
        routeId: routeId,
        depotId: depotId,
        sequence: 1,
        plannedArrival: Value(day.add(const Duration(hours: 9))),
        plannedDeparture: Value(day.add(const Duration(hours: 10))),
        status: 'checkedIn',
        actualArrival: Value(now.subtract(const Duration(minutes: 15))),
      ));

  await workflows.saveActiveWorkflow(ActiveWorkflow(
    routeId: routeId,
    currentStopId: stopId,
    dayStarted: true,
    updatedAt: now,
    depotId: depotId,
    shopName: depotName,
    checkInAt: now.subtract(const Duration(minutes: 15)),
    currentWorkflow: VisitWorkflow.stockCount,
    currentScreen: InventoryVisibilityScreen.routeName,
    navigationArguments: {
      'stopId': stopId,
      'depotId': depotId,
      'depotName': depotName,
    },
  ));
}

class _Reasons implements CheckOutReasonRepository {
  @override
  Future<List<NoOrderReason>> getReasons() async => const [
        NoOrderReason(
          code: 'stockStillEnough',
          nameEn: 'Shop still has enough stock',
          nameKm: 'ហាងនៅមានស្តុកគ្រប់គ្រាន់',
          requiresNote: false,
          sort: 1,
        ),
        NoOrderReason.other,
      ];
}
