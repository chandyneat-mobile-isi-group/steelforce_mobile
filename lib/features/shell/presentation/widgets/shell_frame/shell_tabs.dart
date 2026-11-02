import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';

/// One destination in the shell's navigation: its icon and its label, which
/// is also the app bar title while that tab is showing.
class NavTab {
  const NavTab(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// The shell's tabs, in [ShellTab] order: Home, Depots, My Visits, Orders.
///
/// A function, not a constant: the labels are read in the current language
/// on every build.
List<NavTab> shellNavTabs() => [
      NavTab(Icons.grid_view_rounded, 'home.title'.tr),
      NavTab(Icons.people_alt_rounded, 'depots.title'.tr),
      NavTab(Icons.location_on_rounded, 'my_visits.title'.tr),
      NavTab(Icons.receipt_long_rounded, 'orders.title'.tr),
    ];

/// How many tabs the shell has; matches [shellNavTabs].
const int shellTabCount = 4;
