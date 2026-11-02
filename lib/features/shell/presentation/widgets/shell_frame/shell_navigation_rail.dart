import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/shell/presentation/widgets/shell_frame/shell_tabs.dart';

/// Side navigation for desktop-width windows only.
///
/// Deliberately *desktop-only*, not `hasSideNavigation` (>= 600) and not
/// `isExpanded` (>= 1024) — an iPad Pro 12.9" is exactly 1024pt in portrait,
/// so `expanded` sits right on a tablet. On a tablet the rail added a second
/// navigation model on top of the "My Work" grid that phones already use, for
/// no gain, so tablets get exactly the phone experience. See
/// [Breakpoints.sideNavigationMin].
class ShellNavigationRail extends StatelessWidget {
  const ShellNavigationRail({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelect,
      extended: false,
      labelType: context.windowSize.isExpanded
          ? NavigationRailLabelType.all
          : NavigationRailLabelType.selected,
      backgroundColor: context.appColors.canvas,
      destinations: [
        for (final tab in shellNavTabs())
          NavigationRailDestination(
            icon: Icon(tab.icon),
            label: Text(tab.label),
          ),
      ],
    );
  }
}
