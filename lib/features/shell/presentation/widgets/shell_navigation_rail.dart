import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/breakpoints.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

class NavTab {
  final IconData icon;
  final String label;

  NavTab(this.icon, this.label);
}

/// The desktop-only side navigation over the shell's four tabs.
class ShellNavigationRail extends StatelessWidget {
  const ShellNavigationRail({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    required this.size,
  });

  final List<NavTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final WindowSize size;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      extended: false,
      labelType: size.isExpanded
          ? NavigationRailLabelType.all
          : NavigationRailLabelType.selected,
      backgroundColor: context.appColors.canvas,
      destinations: [
        for (final tab in tabs)
          NavigationRailDestination(
            icon: Icon(tab.icon),
            label: Text(tab.label),
          ),
      ],
    );
  }
}
