import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/network/connectivity/connectivity_cubit.dart';
import 'package:steelforce/core/permissions/presentation/app_permissions_cubit.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/core/sync/sync_engine.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/app_coach/presentation/blocs/app_coach_bloc.dart';
import 'package:steelforce/features/authentication/domain/entities/user.dart';
import 'package:steelforce/features/authentication/domain/entities/user_role.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_registration_queue_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/resumable_visit_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/route_sync_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/today_call_plan_count_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/route_sync_state.dart';
import 'package:steelforce/features/notification/domain/entities/notification_counts.dart';
import 'package:steelforce/features/notification/presentation/bloc/notification_badge_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/continue_work_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/pending_sync_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/pending_sync_state.dart';
import 'package:steelforce/features/shell/presentation/bloc/home_cubit.dart';
import 'package:steelforce/features/shell/presentation/main_shell.dart';
import 'package:steelforce/features/shell/presentation/widgets/guest/guest_home_screen.dart';
import 'package:steelforce/features/shell/presentation/widgets/main_app_bar.dart';
import 'package:steelforce/features/shell/presentation/widgets/monthly_target_widget.dart';
import 'package:steelforce/features/shell/presentation/widgets/my_work_grid_section.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/connectivity_banner.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_visit_card.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working_card.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/pending_sync_badge.dart';

class _MockSession extends Mock implements SessionManager {}

class _MockSyncEngine extends Mock implements SyncEngine {}

class _MockPermissions extends MockCubit<AppPermissionsState>
    implements AppPermissionsCubit {}

class _MockResumable extends MockCubit<ResumableVisitState>
    implements ResumableVisitCubit {}

class _MockConnectivity extends MockCubit<ConnectivityStatus>
    implements ConnectivityCubit {}

class _MockPendingSync extends MockCubit<PendingSyncState>
    implements PendingSyncCubit {}

class _MockDepotQueue extends MockCubit<DepotRegistrationQueueState>
    implements DepotRegistrationQueueCubit {}

class _MockContinueWork extends MockCubit<ContinueWorkState>
    implements ContinueWorkCubit {}

class _MockBadge extends MockCubit<NotificationCounts>
    implements NotificationBadgeCubit {}

class _MockCallPlanCount extends MockCubit<int?>
    implements TodayCallPlanCountCubit {}

class _MockRouteSync extends MockCubit<RouteSyncState>
    implements RouteSyncCubit {}

class _MockCoach extends MockBloc<AppCoachEvent, AppCoachState>
    implements AppCoachBloc {}

/// Pins what the shell renders before it is split into widgets.
void main() {
  late _MockSession session;
  late _MockSyncEngine syncEngine;
  late _MockPermissions permissions;
  late _MockResumable resumable;
  late StreamController<User?> sessionChanges;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  setUp(() async {
    session = _MockSession();
    syncEngine = _MockSyncEngine();
    permissions = _MockPermissions();
    resumable = _MockResumable();
    sessionChanges = StreamController<User?>.broadcast();
    final connectivity = _MockConnectivity();
    final pendingSync = _MockPendingSync();
    final depotQueue = _MockDepotQueue();
    final continueWork = _MockContinueWork();
    final badge = _MockBadge();
    final callPlan = _MockCallPlanCount();
    final routeSync = _MockRouteSync();
    final coach = _MockCoach();

    when(() => session.changes).thenAnswer((_) => sessionChanges.stream);
    when(() => syncEngine.stop()).thenAnswer((_) async {});
    when(() => permissions.shouldPrompt(
            hasSeenFirstRoute: any(named: 'hasSeenFirstRoute')))
        .thenAnswer((_) async => false);
    when(() => resumable.state).thenReturn(const ResumableVisitState());
    when(() => resumable.refresh()).thenAnswer((_) async {});
    when(() => connectivity.state).thenReturn(ConnectivityStatus.online);
    when(() => pendingSync.state).thenReturn(const PendingSyncState());
    when(() => depotQueue.state)
        .thenReturn(const DepotRegistrationQueueState());
    when(() => continueWork.state).thenReturn(const ContinueWorkState());
    when(() => badge.state).thenReturn(NotificationCounts.empty);
    when(() => callPlan.state).thenReturn(null);
    when(() => callPlan.refresh()).thenAnswer((_) async {});
    when(() => routeSync.state).thenReturn(const RouteSyncIdle());
    when(() => routeSync.syncIfNeeded()).thenAnswer((_) async {});
    when(() => coach.state).thenReturn(const AppCoachState.initial());

    final sl = GetIt.instance;
    await sl.reset();
    sl
      ..registerLazySingleton<ShellTabController>(ShellTabController.new)
      ..registerSingleton<SessionManager>(session)
      ..registerSingleton<SyncEngine>(syncEngine)
      ..registerFactory<AppPermissionsCubit>(() => permissions)
      ..registerSingleton<ResumableVisitCubit>(resumable)
      ..registerFactory<ConnectivityCubit>(() => connectivity)
      ..registerFactory<PendingSyncCubit>(() => pendingSync)
      ..registerFactory<DepotRegistrationQueueCubit>(() => depotQueue)
      ..registerFactory<ContinueWorkCubit>(() => continueWork)
      ..registerSingleton<NotificationBadgeCubit>(badge)
      ..registerFactory<TodayCallPlanCountCubit>(() => callPlan)
      ..registerFactory<RouteSyncCubit>(() => routeSync)
      ..registerSingleton<AppCoachBloc>(coach);
  });

  tearDown(() async {
    await sessionChanges.close();
    await GetIt.instance.reset();
  });

  void signedIn(String fullName) {
    when(() => session.isAuthenticated).thenReturn(true);
    when(() => session.currentUser).thenReturn(User(
      id: 'u1',
      email: 'rep@example.com',
      fullName: fullName,
      roles: const {UserRole.salesRep},
    ));
  }

  void guest() {
    when(() => session.isAuthenticated).thenReturn(false);
    when(() => session.currentUser).thenReturn(null);
  }

  Future<void> pump(WidgetTester tester,
      {Size size = const Size(390, 844)}) async {
    // Structure, not pixels: the test font is wider than the shipped one.
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed')) {
        return;
      }
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light(AppTypography.latinFontFamily),
        home: const MainShell(),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  String expectedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'common.good_morning'.tr;
    if (hour < 17) return 'common.good_afternoon'.tr;
    return 'common.good_evening'.tr;
  }

  testWidgets('a signed-in rep gets the full home tab', (tester) async {
    signedIn('Dara Chan Sok');
    await pump(tester);

    expect(find.text(expectedGreeting()), findsOneWidget);
    expect(find.text('Dara Chan Sok'), findsOneWidget);
    expect(find.byType(PendingSyncBadge), findsOneWidget);
    expect(find.byType(MonthlyTargetCard), findsOneWidget);
    expect(find.byType(ConnectivityBanner), findsOneWidget);
    expect(find.byType(ContinueVisitCard), findsOneWidget);
    expect(find.byType(ContinueWorkingCard), findsOneWidget);
    expect(find.byType(MyWorkGridSection), findsOneWidget);
    expect(find.byKey(const ValueKey('authenticated_home_scroll_root')),
        findsOneWidget);
    expect(find.byType(GuestHomeScreen), findsNothing);

    final appBar = tester.widget<MainAppBar>(find.byType(MainAppBar));
    expect(appBar.title, 'home.title'.tr);
    expect(appBar.currentTabIndex, 0);
    expect(appBar.avatarInitials, 'DS');
    expect(appBar.onNotificationTap, isNull);

    final hero = find.byWidgetPredicate((w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName ==
            'assets/images/isi_main_app_bar_bg.png');
    expect(hero, findsOneWidget);
    final heroOpacity = tester.widget<AnimatedOpacity>(
        find.ancestor(of: hero, matching: find.byType(AnimatedOpacity)));
    expect(heroOpacity.opacity, 1.0);
  });

  testWidgets('one name gives a one-letter avatar', (tester) async {
    signedIn('Dara');
    await pump(tester);
    expect(
        tester.widget<MainAppBar>(find.byType(MainAppBar)).avatarInitials, 'D');
  });

  testWidgets('a blank name gives no initials', (tester) async {
    signedIn('   ');
    await pump(tester);
    expect(tester.widget<MainAppBar>(find.byType(MainAppBar)).avatarInitials,
        isNull);
  });

  testWidgets('a guest sees the landing with no app bar and no hero',
      (tester) async {
    guest();
    await pump(tester);

    expect(find.byType(GuestHomeScreen), findsOneWidget);
    expect(find.byType(MainAppBar), findsNothing);
    expect(find.byType(MyWorkGridSection), findsNothing);
    final heroOpacity = tester.widget<AnimatedOpacity>(find
        .ancestor(
            of: find
                .byWidgetPredicate((w) => w is Image && w.image is AssetImage),
            matching: find.byType(AnimatedOpacity))
        .first);
    expect(heroOpacity.opacity, 0.0);
  });

  testWidgets('starts sync, refreshes the visit card and asks permissions once',
      (tester) async {
    signedIn('Dara');
    await pump(tester);

    verify(() => syncEngine.start()).called(1);
    verify(() => resumable.refresh()).called(greaterThanOrEqualTo(1));
    verify(() => permissions.shouldPrompt(hasSeenFirstRoute: true)).called(1);
    verify(() => permissions.close()).called(1);
  });

  testWidgets('a guest is never asked for permissions', (tester) async {
    guest();
    await pump(tester);
    verifyNever(() => permissions.shouldPrompt(
        hasSeenFirstRoute: any(named: 'hasSeenFirstRoute')));
  });

  testWidgets('phones and tablets have no navigation rail', (tester) async {
    signedIn('Dara');
    await pump(tester, size: const Size(1024, 1366));
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('desktop width shows the four-tab rail', (tester) async {
    signedIn('Dara');
    await pump(tester, size: const Size(1600, 1000));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.destinations, hasLength(4));
    expect(rail.selectedIndex, 0);
    expect(find.text('depots.title'.tr), findsWidgets);
  });
}
