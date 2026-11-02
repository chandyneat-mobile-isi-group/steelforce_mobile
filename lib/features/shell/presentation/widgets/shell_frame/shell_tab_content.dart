import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/config/app_config.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/depots/presentation/screens/depots_screen.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/visit_plan_calendar_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/visit_plans_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/screens/visit_plans/visit_plans_screen.dart';
import 'package:steelforce/features/order/presentation/screens/order_screen.dart';
import 'package:steelforce/features/shell/presentation/navigation/shell_tab_controller.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/home_tab.dart';
import 'package:steelforce/shared/widgets/coming_soon.dart';

/// The screen behind one shell tab ([ShellTab] index), with the room it
/// leaves for the floating app bar.
class ShellTabContent extends StatelessWidget {
  const ShellTabContent({
    super.key,
    required this.index,
    required this.onLogin,
  });

  final int index;

  /// Opens sign-in from the guest Home landing.
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final tabs = sl<ShellTabController>();
    // Work tabs start below the floating app bar; Home places its own header.
    Widget belowAppBar(Widget screen) => Padding(
          padding: EdgeInsets.only(top: context.rh(80)),
          child: screen,
        );

    switch (index) {
      case ShellTab.depots:
        return belowAppBar(const DepotsScreen());
      case ShellTab.myVisits:
        // Today's list (`/plans/today`) and the calendar (`/plans`). Scoped to
        // the tab; the shell's IndexedStack keeps them alive across tab
        // switches, so they load once and reload on pull-to-refresh.
        return MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => sl<VisitPlansCubit>()),
            BlocProvider(create: (_) => sl<VisitPlanCalendarCubit>()),
          ],
          child: belowAppBar(const VisitPlansScreen()),
        );
      case ShellTab.orders:
        if (!AppConfig.ordersComingSoon) {
          return belowAppBar(const OrderScreen());
        }
        // A tab, not a route: "Got it" and system back both go Home, the
        // way the real Orders tab's back does — popping would leave the app.
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) tabs.goTo(ShellTab.home);
          },
          child: belowAppBar(
            SafeArea(
              top: false,
              child: ComingSoonView(onAction: () => tabs.goTo(ShellTab.home)),
            ),
          ),
        );
      default:
        return HomeTab(onLogin: onLogin);
    }
  }
}
