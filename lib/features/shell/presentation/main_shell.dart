import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/pending_plan_visits_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/pending_visit_sync_cubit.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/network/connectivity/connectivity_cubit.dart';
import 'package:steelforce/core/permissions/presentation/app_permissions_cubit.dart';
import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/core/sync/offline_data_prefetcher.dart';
import 'package:steelforce/core/sync/sync_engine.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_anchor_registry.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_registration_queue_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/resumable_visit_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/continue_work_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/pending_sync_cubit.dart';
import 'package:steelforce/features/shell/presentation/navigation/shell_tab_controller.dart';
import 'package:steelforce/features/shell/presentation/widgets/shell_frame/shell_actions.dart';
import 'package:steelforce/features/shell/presentation/widgets/shell_frame/shell_body.dart';
import 'package:steelforce/features/shell/presentation/widgets/shell_frame/shell_navigation_rail.dart';
import 'package:steelforce/features/shell/presentation/widgets/shell_frame/shell_tabs.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/work_mode_auto_prompt.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/sync_overlay.dart';
import 'package:steelforce/shared/widgets/permission/permission_primer_dialog.dart';

/// The signed-in app frame: the tabs (Home, Depots, My Visits, Orders), the
/// shell-wide cubits, the sync engine's lifetime, and the permission primer.
///
/// What each part looks like lives in its own file: the Home tab under
/// `widgets/home/`, the frame (body layers, app bar, rail, tab screens) under
/// `widgets/shell_frame/`.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final ShellTabController _tabController = sl<ShellTabController>();
  final SessionManager _session = sl<SessionManager>();

  /// The shell's own anchors, also published to the app-wide registry above
  /// the Navigator, where the coach overlay reads them.
  late final CoachAnchorRegistry _coachAnchors =
      CoachAnchorRegistry(parent: CoachAnchorScope.maybeOf(context));

  /// A practice lesson swaps the data behind Depots, My Visits and Orders.
  /// Those tabs hold their blocs for as long as they live, so they are
  /// rebuilt — against whichever data is now current — whenever practice
  /// starts or ends.
  final PracticeSession _practice = sl<PracticeSession>();

  int _index = 0;
  final Set<int> _builtTabs = <int>{0};

  @override
  void initState() {
    super.initState();
    _index = _tabController.value;
    _builtTabs.add(_index);
    _tabController.addListener(_onTabChanged);
    _practice.addListener(_onPracticeChanged);
    sl<ResumableVisitCubit>().refresh();

    // Sends whatever was saved offline — check-ins, check-outs, ad hoc visits,
    // quotations — as soon as the server is reachable, and keeps retrying
    // with backoff while anything is left. Guests are skipped inside.
    sl<SyncEngine>().start();

    // And the pull side: depots, routes, catalog, today's and this month's
    // plans, profile — so a rep who only ever opens Home still has what they
    // need when the signal drops. Again on every reconnect.
    sl<OfflineDataPrefetcher>().start();

    // Reaching the shell *is* the moment `docs/feature/notification/README.md`
    // §14 describes: signed in and past onboarding, so a notification prompt
    // is about work the rep can already see. The cubit checks what is still
    // unanswered and the 14-day re-offer cap, so this is safe on every build.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => unawaited(_maybePrimePermissions()));
    // Depot sync is deliberately *not* kicked off here: `DepotsScreen` does
    // it, and a second call here ran a duplicate full initial sync on every
    // cold start (the doubled `depots.sync.initial.start` in the logs).
  }

  /// Shows the permission primer if anything is still unanswered. Guests are
  /// skipped: they have no device to register and no route to be told about.
  Future<void> _maybePrimePermissions() async {
    if (!_session.isAuthenticated) return;

    final cubit = sl<AppPermissionsCubit>();
    try {
      if (!await cubit.shouldPrompt(hasSeenFirstRoute: true)) return;
      if (!mounted) return;
      await showPermissionPrimerDialog(context: context, cubit: cubit);
    } finally {
      // Factory-registered, so this instance is ours to close.
      await cubit.close();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _practice.removeListener(_onPracticeChanged);
    unawaited(sl<SyncEngine>().stop());
    unawaited(sl<OfflineDataPrefetcher>().stop());
    super.dispose();
  }

  void _onPracticeChanged() {
    if (mounted) setState(() {});
  }

  void _onTabChanged() {
    setState(() {
      _index = _tabController.value;
      _builtTabs.add(_index);
    });
    if (_tabController.value == ShellTab.home) {
      sl<ResumableVisitCubit>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= shellTabCount) _index = ShellTab.home;

    final body = ShellBody(
      index: _index,
      builtTabs: _builtTabs,
      practiceGeneration: _practice.generation,
      onLogin: () => openShellProfile(context),
    );

    return CoachAnchorScope(
      registry: _coachAnchors,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ConnectivityCubit>(
            create: (_) => sl<ConnectivityCubit>(),
          ),
          BlocProvider<PendingSyncCubit>(
            create: (_) => sl<PendingSyncCubit>(),
          ),
          BlocProvider<DepotRegistrationQueueCubit>(
            create: (_) => sl<DepotRegistrationQueueCubit>(),
          ),
          // Shell-wide so the Pending Sync badge counts visits too; the Sync
          // Center reuses them.
          BlocProvider<PendingVisitSyncCubit>(
            create: (_) => sl<PendingVisitSyncCubit>()..load(),
          ),
          BlocProvider<PendingPlanVisitsCubit>(
            create: (_) => sl<PendingPlanVisitsCubit>(),
          ),
          BlocProvider<ContinueWorkCubit>(
            create: (_) => sl<ContinueWorkCubit>(),
          ),
          BlocProvider<ResumableVisitCubit>.value(
            value: sl<ResumableVisitCubit>(),
          ),
        ],
        child: WorkModeAutoPrompt(
          // Lost internet: offers Offline Mode; back: offers Online.
          child: ReconnectSyncListener(
            child: PopScope(
              // Back from a work tab goes Home; back from Home leaves the app.
              canPop: _index == ShellTab.home,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) _tabController.goTo(ShellTab.home);
              },
              child: Scaffold(
                backgroundColor: context.appColors.canvas,
                body: context.showsSideNavigation
                    ? Row(
                        children: [
                          ShellNavigationRail(
                            selectedIndex: _index,
                            onSelect: _tabController.goTo,
                          ),
                          const VerticalDivider(width: 1, thickness: 1),
                          Expanded(child: body),
                        ],
                      )
                    : body,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
