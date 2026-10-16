import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/breakpoints.dart';

/// Constrains content to a readable measure and centres it on wide windows.
///
/// On [WindowSize.compact] this is a **pass-through** — it returns [child]
/// untouched, adding no widget to the tree. That is deliberate and is what lets
/// it be applied broadly without any risk to the mobile layout: on a phone it
/// is not merely visually neutral, it is structurally absent, so it cannot
/// affect intrinsic sizing, scroll behaviour, or golden output.
///
/// On wider windows it clamps to [Breakpoints.contentMaxWidth]. Without this,
/// a form field or list row on a 2560px monitor spans the whole screen, which
/// is hard to read (the eye loses its place tracking across a long row) and
/// hard to click accurately. Clamping is most of what separates a desktop
/// layout that feels designed from one that is merely stretched.
class ResponsiveContentFrame extends StatelessWidget {
  const ResponsiveContentFrame({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.contentMaxWidth,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (context.windowSize.isCompact) return child;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
