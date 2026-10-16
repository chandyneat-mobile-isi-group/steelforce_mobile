import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localized_builder.dart';

/// App-wide default transition for every [MaterialPageRoute] (`Navigator.push`
/// calls and the named-route `_page()` helper alike) — `MaterialPageRoute`
/// defers its `buildTransitions` to the ambient `Theme`'s
/// `pageTransitionsTheme`, so wiring this into `ThemeData` upgrades
/// navigation everywhere with no per-screen changes.
///
/// Cross-fade + a short upward drift on the incoming page, with the outgoing
/// page easing to a slightly lower opacity for a sense of depth — smoother
/// and calmer than the platform-default slide/fade, and consistent across
/// Android/iOS/desktop.
class ModernPageTransitionsBuilder extends PageTransitionsBuilder {
  const ModernPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final incoming = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic);
    final outgoing = CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic);

    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.92).animate(outgoing),
      child: FadeTransition(
        opacity: incoming,
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero)
                  .animate(incoming),
          child: child,
        ),
      ),
    );
  }
}

/// Slide-left on forward navigation, slide-right on back — used across the
/// Routes field flow (Dispatch → Transit → Check-in → Stock) to anchor the
/// agent's spatial mental map of where they are in the route wizard.
///
/// The page is wrapped in [LocalizedBuilder] so every screen pushed this way
/// re-evaluates its `.tr` text live on a language switch, even though it sits
/// in its own Navigator overlay entry.
Route<T> slideLeftRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) => LocalizedBuilder(builder: (_) => page),
    transitionsBuilder: (_, animation, __, child) {
      final slide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(slide), child: child);
    },
  );
}
