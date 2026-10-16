import 'dart:async';
import 'package:steelforce/features/order/presentation/screens/quotes_coming_soon_screen.dart';
import 'package:steelforce/core/config/feature_flags.dart';

import 'package:flutter/material.dart';
import 'package:steelforce/features/about/presentation/screens/about_hub_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/auth/auth_guard.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/network/connectivity/connectivity_cubit.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/core/sync/sync_engine.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_anchor_registry.dart';
import 'package:steelforce/features/app_coach/presentation/widgets/app_coach_host.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_registration_queue_cubit.dart';
import 'package:steelforce/features/depots/presentation/screens/depots_screen.dart';
import 'package:steelforce/features/shell/presentation/bloc/home_cubit.dart';

import 'package:steelforce/features/my_visits/presentation/bloc/cubit/resumable_visit_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/ad_hoc_visit_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/route_sync_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/stop_dashboard_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stop_dashboard/stop_dashboard_screen.dart';
import 'package:steelforce/core/permissions/presentation/app_permissions_cubit.dart';
import 'package:steelforce/features/notification/notification_coordinator.dart';
import 'package:steelforce/shared/widgets/permission/permission_primer_dialog.dart';
import 'package:steelforce/features/notification/presentation/screen/notifications_sheet.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/continue_work_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/pending_sync_cubit.dart';
import 'package:steelforce/features/order/presentation/screens/order_screen.dart';
import 'package:steelforce/core/config/app_config.dart';
import 'package:steelforce/core/network/api/server_url.dart';
import 'package:steelforce/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:steelforce/features/profile/presentation/screens/profile_screen.dart';
import 'package:steelforce/features/shell/presentation/widgets/guest/guest_home_screen.dart';
import 'package:steelforce/features/shell/presentation/widgets/main_app_bar.dart';
import 'package:steelforce/core/utils/name_initials.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/authenticated_home_tab.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/home_hero_backdrop.dart';
import 'package:steelforce/features/shell/presentation/widgets/shell_navigation_rail.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/sync_overlay.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final ShellTabController _tabController = sl<ShellTabController>();
  final SessionManager _session = sl<SessionManager>();

  final CoachAnchorRegistry _coachAnchors = CoachAnchorRegistry();

  int _index = 0;
  final Set<int> _builtTabs = <int>{0};

  @override
  void initState() {
    super.initState();
    _index = _tabController.value;
    _builtTabs.add(_index);
    _tabController.addListener(_onTabChanged);
    sl<ResumableVisitCubit>().refresh();

    // Sends whatever was saved offline — check-ins, check-outs, ad hoc visits,
    // quotations — as soon as the server is reachable, and keeps retrying
    // with backoff while anything is left. Guests are skipped inside.
    sl<SyncEngine>().start();

    // Prime the OS permissions once, here.
    //
    // Reaching `MainShell` *is* the moment
    // `docs/feature/notification/README.md` §14 describes: it means
    // the rep is signed in and past onboarding, so "get notified the moment a
    // route needs you" is about work they can already see. Asking any earlier
    // spends iOS's single prompt on somebody with nothing to be notified about.
    //
    // The cubit decides whether to actually show anything — it checks what is
    // still unanswered and honours the 14-day re-offer cap — so this is safe to
    // call on every shell build.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => unawaited(_maybePrimePermissions()));
    // Depot sync is deliberately *not* kicked off here.
    //
    // `DepotsScreen` already does it (`sl<DepotSyncCubit>()
    // ..syncIfNeeded()`), and `DepotSyncCubit` is a factory — so this line
    // built a second, throwaway cubit and ran a second initial sync whose
    // state no widget was watching. That is the duplicate
    // `depots.sync.initial.start` visible in the logs: two full page runs
    // on every cold start, for one set of rows.
  }

  /// Shows the permission primer if anything is still unanswered.
  ///
  /// Guests are skipped: a guest has no device to register and no route to be
  /// notified about, and burning the prompt before sign-in is exactly what §14
  /// rules out.
  Future<void> _maybePrimePermissions() async {
    if (!_session.isAuthenticated) return;

    final cubit = sl<AppPermissionsCubit>();
    try {
      if (!await cubit.shouldPrompt(hasSeenFirstRoute: true)) return;
      if (!mounted) return;

      await showPermissionPrimerDialog(context: context, cubit: cubit);
    } finally {
      // Factory-registered, so this instance is ours to close. Skipping it
      // leaks the cubit on every shell build.
      await cubit.close();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    unawaited(sl<SyncEngine>().stop());
    super.dispose();
  }

  void _onTabChanged() {
    setState(() {
      _index = _tabController.value;
      _builtTabs.add(_index);
    });
    if (_tabController.value == 0) sl<ResumableVisitCubit>().refresh();
  }

  List<NavTab> get _tabs => [
        NavTab(Icons.grid_view_rounded, 'home.title'.tr),
        NavTab(Icons.people_alt_rounded, 'depots.title'.tr),
        NavTab(Icons.location_on_rounded, 'my_visits.title'.tr),
        NavTab(Icons.receipt_long_rounded, 'orders.title'.tr),
      ];

  List<String> get _titles => [
        'home.title'.tr,
        'depots.title'.tr,
        'my_visits.title'.tr,
        'orders.title'.tr,
      ];

  Future<void> _openProfile(BuildContext context) async {
    final allowed = await AuthGuard.requireAuthentication(context);
    if (!allowed || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<ProfileCubit>(),
          child: LocalizedBuilder(builder: (_) => const ProfileScreen()),
        ),
      ),
    );
  }

  void _openGuestNotifications(BuildContext context) {
    showNotificationsSheet(
      context: context,
      isGuest: !_session.isAuthenticated,
      onLogin: () => _openProfile(context),
      // A guest never reaches this callback — the sheet shows the sign-in
      // prompt instead of a list — but wiring it means the one entry point
      // behaves identically the moment a session exists, rather than silently
      // having non-tappable rows for a signed-in rep who arrived this way.
      onOpenNotification: (notification) {
        Navigator.of(context).pop();
        sl<NotificationCoordinator>().openLink(notification.deepLink);
      },
    );
  }

  Widget _buildHomeTab() {
    return StreamBuilder<Object?>(
      stream: _session.changes,
      builder: (context, snapshot) {
        final authenticated = _session.isAuthenticated;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.02),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: authenticated
              ? AuthenticatedHomeTab(
                  key: const ValueKey('authenticated_home_view'),
                  fullName: _session.currentUser?.fullName ?? '',
                )
              : GuestHomeScreen(
                  key: const ValueKey('guest_home_view'),
                  onLogin: () => _openProfile(context),
                ),
        );
      },
    );
  }

  Widget _buildTab(int i) {
    Widget wrapWithTopSpacing(Widget screen) {
      return Padding(
        padding: EdgeInsets.only(top: context.rh(80)),
        child: screen,
      );
    }

    switch (i) {
      case 0:
        return _buildHomeTab();
      case 1:
        return wrapWithTopSpacing(const DepotsScreen());
      case 2:
        return MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => sl<StopDashboardCubit>()),
            BlocProvider(create: (_) => sl<RouteSyncCubit>()),
            // Scoped to the tab like the other two: its retry queue lives in
            // the database, not in the cubit, so nothing is lost when the rep
            // switches tabs and the queue is drained again on the way back.
            BlocProvider(create: (_) => sl<AdHocVisitCubit>()),
          ],
          child: wrapWithTopSpacing(const StopDashboardScreen()),
        );
      case 3:
        return wrapWithTopSpacing(FeatureFlags.quotesAndOrders
            ? const OrderScreen()
            : const QuotesComingSoonScreen());
      default:
        return _buildHomeTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= _tabs.length) _index = 0;

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
          BlocProvider<ContinueWorkCubit>(
            create: (_) => sl<ContinueWorkCubit>(),
          ),
          BlocProvider<ResumableVisitCubit>.value(
            value: sl<ResumableVisitCubit>(),
          ),
        ],
        child: ReconnectSyncListener(
          child: PopScope(
            canPop: _index == 0,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              _tabController.goTo(0);
            },
            child: Scaffold(
              backgroundColor: context.appColors.canvas,
              // Side navigation is deliberately *desktop-only*, not
              // `hasSideNavigation` (>= 600) and not `isExpanded` (>= 1024) —
              // an iPad Pro 12.9" is exactly 1024pt in portrait, so `expanded`
              // sits right on a tablet. On a tablet the rail added a second
              // navigation model on top of the "My Work" grid that phones
              // already use, for no gain, so tablets now get exactly the phone
              // experience. See [Breakpoints.sideNavigationMin].
              body: context.showsSideNavigation
                  ? Row(
                      children: [
                        ShellNavigationRail(
                          tabs: _tabs,
                          selectedIndex: _index,
                          onSelected: _tabController.goTo,
                          size: context.windowSize,
                        ),
                        const VerticalDivider(width: 1, thickness: 1),
                        Expanded(child: _buildBody(context)),
                      ],
                    )
                  : _buildBody(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Stack(
      children: [
        // The hero photo behind the app bar and greeting. It is taller than
        // the header so its fade runs behind the target card rather than
        // through the greeting.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.of(context).size.height * 0.36,
          child: StreamBuilder<Object?>(
            stream: _session.changes,
            builder: (context, _) {
              // The guest landing is full screen and draws its own page, so
              // the photo band behind the app bar is hidden for a guest.
              final visible = _index == 0 && _session.isAuthenticated;
              return AnimatedOpacity(
                duration: const Duration(milliseconds: 350),
                opacity: visible ? 1.0 : 0.0,
                curve: Curves.easeInOut,
                child: const IgnorePointer(child: HomeHeroBackdrop()),
              );
            },
          ),
        ),
        // `Positioned.fill` is the *direct* child of the Stack, with `Theme`
        // inside it — not the other way round.
        //
        // `Positioned` is a `ParentDataWidget` that writes `StackParentData`
        // onto the render object beneath it. Nesting it under `Theme` (which
        // builds no render object) made that write land a level away from the
        // child the `Stack` actually lays out, so the parent data was dirty
        // when semantics ran — the `!semantics.parentDataDirty` assertion that
        // flooded the console every frame.
        Positioned.fill(
          child: Theme(
            data: Theme.of(context).copyWith(
              scaffoldBackgroundColor: Colors.transparent,
            ),
            // Nothing in the tab stack may claim the primary scroll
            // controller.
            //
            // `Scaffold` binds a status-bar tap to
            // `primaryScrollController.animateTo(0)`, and `animateTo` drives
            // **every attached position**, not just the visible one.
            // `IndexedStack` keeps every built tab in the tree, and the home
            // tab's `AnimatedSwitcher` holds the guest and authenticated lists
            // together for 500ms during a sign-in. A position that has not
            // finished layout has a null `minScrollExtent`, which
            // `BouncingScrollPhysics` then reads — "Null check operator used
            // on a null value".
            //
            // Unconditional and applied once. Wrapping only the *hidden* tabs
            // was worse than useless: it left the visible tab attached, and it
            // changed tree depth on every switch, remounting the tab and
            // discarding the state `IndexedStack` exists to preserve.
            //
            // The cost is that a status-bar tap no longer scrolls to top in
            // the shell. That is an iOS convenience; this was a crash.
            child: PrimaryScrollController.none(
              // No `AnimatedSwitcher` here. It wrapped this `IndexedStack` and
              // never once animated: a switcher transitions when its child's
              // *type or key* changes, and an unkeyed `IndexedStack` is the
              // same widget on every build — only its `index` moves, which the
              // switcher cannot see. It bought nothing and cost an extra
              // `Stack` layer re-parenting children on every tab change.
              child: IndexedStack(
                index: _index,
                children: List.generate(
                  _tabs.length,
                  (i) => _builtTabs.contains(i)
                      ? _buildTab(i)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
        // Inside MainShell -> _buildBody -> Stack children:
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          // Rebuilt on session changes, so a picture saved on the profile
          // screen appears here without a restart.
          child: StreamBuilder<Object?>(
            stream: _session.changes,
            builder: (context, _) {
              // No app bar over the guest landing: it is the whole screen.
              if (_index == 0 && !_session.isAuthenticated) {
                return const SizedBox.shrink();
              }
              final user = _session.currentUser;
              return MainAppBar(
                onLogoTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AboutHubScreen()),
                ),
                title: _titles[_index],
                currentTabIndex: _index,
                onBackToHomeTap: () => _tabController.goTo(0),
                onAvatarTap: () => _openProfile(context),
                onNotificationTap: _session.isAuthenticated
                    ? null
                    : () => _openGuestNotifications(context),
                avatarUrl:
                    resolveServerUrl(user?.avatarUrl, AppConfig.apiBaseUrl),
                avatarInitials: nameInitials(user?.fullName),
              );
            },
          ),
        ),
        // Wrap AppCoachHost in Positioned.fill directly inside the Stack
        const Positioned.fill(
          child: AppCoachHost(),
        ),
      ],
    );
  }
}
