import 'package:flutter/material.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/shell/presentation/navigation/shell_tab_controller.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/home_hero_backdrop.dart';
import 'package:steelforce/features/shell/presentation/widgets/shell_frame/shell_app_bar_layer.dart';
import 'package:steelforce/features/shell/presentation/widgets/shell_frame/shell_tab_content.dart';
import 'package:steelforce/features/shell/presentation/widgets/shell_frame/shell_tabs.dart';
import 'package:steelforce/shared/widgets/brand_wallpaper_background.dart';

/// The shell's layers, bottom to top: brand wallpaper, the Home hero photo,
/// the tabs, and the floating app bar.
class ShellBody extends StatelessWidget {
  const ShellBody({
    super.key,
    required this.index,
    required this.builtTabs,
    required this.practiceGeneration,
    required this.onLogin,
  });

  /// The tab showing, as a [ShellTab] index.
  final int index;

  /// Tabs opened at least once. The others stay unbuilt until first visited.
  final Set<int> builtTabs;

  /// Bumped when a practice lesson starts or ends; rebuilds the work tabs
  /// against whichever data is now current.
  final int practiceGeneration;

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>();
    return Stack(
      children: [
        // The brand wallpaper under everything, the hero photo included. The
        // tabs' scaffolds are transparent (below), so it shows wherever a
        // tab does not paint its own background — the home tab today.
        const Positioned.fill(child: BrandWallpaperBackground()),
        // The hero photo behind the app bar and greeting. It is taller than
        // the header so its fade runs behind the target card rather than
        // through the greeting.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.of(context).size.height * 0.36,
          child: StreamBuilder<Object?>(
            stream: session.changes,
            builder: (context, _) => AnimatedOpacity(
              duration: const Duration(milliseconds: 350),
              // The guest landing is full screen and draws its own page, so
              // the photo band behind the app bar is hidden for a guest.
              opacity:
                  index == ShellTab.home && session.isAuthenticated ? 1 : 0,
              curve: Curves.easeInOut,
              child: const IgnorePointer(child: HomeHeroBackdrop()),
            ),
          ),
        ),
        // `Positioned.fill` must be the *direct* child of the Stack, with
        // `Theme` inside it. Nested under `Theme` (no render object), the
        // `StackParentData` write landed a level away from the laid-out
        // child — the `!semantics.parentDataDirty` assertion every frame.
        Positioned.fill(
          child: Theme(
            data: Theme.of(context).copyWith(
              scaffoldBackgroundColor: Colors.transparent,
            ),
            // Nothing in the tab stack may claim the primary scroll
            // controller. A status-bar tap animates *every* attached
            // position; `IndexedStack` keeps all built tabs attached, and a
            // position mid-layout has a null `minScrollExtent` that
            // `BouncingScrollPhysics` reads — "Null check operator used on a
            // null value". Applied once and unconditionally: wrapping only
            // hidden tabs changed tree depth on every switch and remounted
            // them. The cost: a status-bar tap no longer scrolls to top.
            child: PrimaryScrollController.none(
              // No `AnimatedSwitcher` here: only the index moves, which a
              // switcher cannot see, so it never animated.
              child: IndexedStack(
                index: index,
                children: List.generate(
                  shellTabCount,
                  (i) => builtTabs.contains(i)
                      // Home reads no practice data; the work tabs do.
                      ? KeyedSubtree(
                          key: ValueKey(
                              'tab-$i-${i == 0 ? 0 : practiceGeneration}'),
                          child: ShellTabContent(index: i, onLogin: onLogin),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ShellAppBarLayer(index: index),
        ),
      ],
    );
  }
}
