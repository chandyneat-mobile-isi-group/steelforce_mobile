import 'package:flutter/material.dart';

/// Thin wrapper over [Hero] with a polished default flight animation.
///
/// The in-flight widget cross-fades between source and destination and rides a
/// subtle Material elevation, which reads far smoother than the default hard
/// swap for card -> detail transitions. Both ends of the flight must share the
/// same [tag].
class AppHero extends StatelessWidget {
  const AppHero({
    super.key,
    required this.tag,
    required this.child,
    this.flightRadius = 20,
  });

  final Object tag;
  final Widget child;
  final double flightRadius;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      flightShuttleBuilder: (
        flightContext,
        animation,
        direction,
        fromHeroContext,
        toHeroContext,
      ) {
        final fromHero = fromHeroContext.widget as Hero;
        final toHero = toHeroContext.widget as Hero;
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final progress = direction == HeroFlightDirection.push
                ? animation.value
                : 1 - animation.value;
            return Material(
              type: MaterialType.transparency,
              elevation: Curves.easeInOut.transform(progress) * 8,
              borderRadius: BorderRadius.circular(flightRadius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(opacity: 1 - animation.value, child: fromHero.child),
                  Opacity(opacity: animation.value, child: toHero.child),
                ],
              ),
            );
          },
        );
      },
      child: child,
    );
  }
}
